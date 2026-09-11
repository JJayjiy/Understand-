#!/usr/bin/env python3
"""
finetune_lora.py — LoRA fine-tune Whisper on the TORGO manifests.

Freezes Whisper and trains small adapter matrices instead (<1% of parameters),
so this fits on a free Colab T4. Same idea as full fine-tuning, ~100x cheaper.

    pip install transformers datasets peft accelerate soundfile librosa torch

    # 1. sanity check the whole pipeline in ~2 minutes
    python finetune_lora.py --train data/torgo/train.jsonl --smoke-test

    # 2. general dysarthric model
    python finetune_lora.py --train data/torgo/train.jsonl --model openai/whisper-small \
        --out models/torgo_general --epochs 3

    # 3. per-speaker adaptation — this is the moat
    python finetune_lora.py --train data/torgo/train.jsonl --speaker M04 \
        --out models/m04 --epochs 8

Saves to --out:
    adapter/         the LoRA weights (a few MB)
    merged/          adapter folded into the base model — point eval/app at this
    train_log.json   losses + config, so runs are reproducible

Then measure it:
    python eval_whisper.py --manifest data/torgo/test.jsonl \
        --backend transformers --model models/m04/merged --tag m04-lora
"""

import argparse
import json
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------- data


def load_manifest(path, speaker=None, group=None, severity=None, min_words=0):
    rows = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        if speaker and r.get("speaker") != speaker:
            continue
        if group and r.get("group") != group:
            continue
        if severity and r.get("severity") != severity:
            continue
        if r.get("n_words", 1) < min_words:
            continue
        rows.append(r)
    return rows


def load_audio(path, target_sr=16000):
    """Read a wav as mono float32 at 16 kHz. TORGO is already 16 kHz mono."""
    import soundfile as sf

    audio, sr = sf.read(path, dtype="float32")
    if audio.ndim > 1:                    # stereo -> mono
        audio = audio.mean(axis=1)
    if sr != target_sr:
        import librosa
        audio = librosa.resample(audio, orig_sr=sr, target_sr=target_sr)
    return audio


def encode_example(row, processor, max_label_len=448):
    """One manifest row -> the tensors Whisper trains on."""
    audio = load_audio(row["audio_path"])
    feats = processor.feature_extractor(audio, sampling_rate=16000).input_features[0]
    labels = processor.tokenizer(row["text"]).input_ids[:max_label_len]
    return {"input_features": feats, "labels": labels}


def build_dataset(rows, processor, max_label_len=448):
    """Torch Dataset wrapper around encode_example."""
    import torch

    class TorgoDataset(torch.utils.data.Dataset):
        def __len__(self):
            return len(rows)

        def __getitem__(self, i):
            return encode_example(rows[i], processor, max_label_len)

    return TorgoDataset()


class Collator:
    """Pad mel features and labels; mask pad tokens so they don't count as loss."""

    def __init__(self, processor):
        self.processor = processor

    def __call__(self, features):
        import torch

        batch = self.processor.feature_extractor.pad(
            [{"input_features": f["input_features"]} for f in features],
            return_tensors="pt",
        )
        labels_batch = self.processor.tokenizer.pad(
            [{"input_ids": f["labels"]} for f in features], return_tensors="pt"
        )
        labels = labels_batch["input_ids"].masked_fill(
            labels_batch.attention_mask.ne(1), -100
        )
        # Whisper adds BOS during training; strip it if the tokenizer already did.
        if (labels[:, 0] == self.processor.tokenizer.bos_token_id).all().cpu().item():
            labels = labels[:, 1:]
        batch["labels"] = labels
        return batch


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--train", required=True, help="train.jsonl from torgo_prep.py")
    ap.add_argument("--model", default="openai/whisper-small",
                    help="openai/whisper-{tiny,base,small,medium,large-v3}")
    ap.add_argument("--out", default="models/lora_run")
    ap.add_argument("--speaker", default=None, help="train on ONE speaker (per-speaker adaptation)")
    ap.add_argument("--group", default=None, choices=["dysarthric", "control"])
    ap.add_argument("--severity", default=None, choices=["severe", "moderate", "mild"])
    ap.add_argument("--min-words", type=int, default=0, help="2 = sentences only")
    ap.add_argument("--epochs", type=float, default=3)
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--grad-accum", type=int, default=2)
    ap.add_argument("--lr", type=float, default=1e-3, help="LoRA likes a higher LR than full FT")
    ap.add_argument("--lora-r", type=int, default=32)
    ap.add_argument("--lora-alpha", type=int, default=64)
    ap.add_argument("--lora-dropout", type=float, default=0.05)
    ap.add_argument("--int8", action="store_true", help="8-bit base model (CUDA only, saves VRAM)")
    ap.add_argument("--smoke-test", action="store_true",
                    help="20 clips, 1 epoch — verifies the pipeline runs end to end")
    ap.add_argument("--no-merge", action="store_true", help="skip saving the merged model")
    ap.add_argument("--device", default="auto", choices=["auto", "cpu", "mps", "cuda"],
                    help="auto picks the fastest available. Use cpu on Apple Silicon for long "
                         "runs — mps is faster at first but leaks memory and collapses after ~1 epoch.")
    ap.add_argument("--seed", type=int, default=13)
    args = ap.parse_args()

    try:
        import torch
        from transformers import (WhisperProcessor, WhisperForConditionalGeneration,
                                  Seq2SeqTrainer, Seq2SeqTrainingArguments)
        from peft import LoraConfig, get_peft_model
    except ImportError as e:
        sys.exit(f"Missing dependency: {e}\n"
                 "  pip install transformers datasets peft accelerate soundfile librosa torch")

    rows = load_manifest(args.train, args.speaker, args.group, args.severity, args.min_words)
    if args.smoke_test:
        rows = rows[:20]
        args.epochs = 1
    if not rows:
        sys.exit("No training rows matched those filters.")

    if args.device != "auto":
        device = args.device
    elif torch.cuda.is_available():
        device = "cuda"
    elif getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        device = "mps"
    else:
        device = "cpu"
    # Honour the choice: HF Trainer would otherwise grab MPS on its own.
    if device == "cpu":
        import os as _os
        _os.environ["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"
        _os.environ["CUDA_VISIBLE_DEVICES"] = ""

    mins = sum(r.get("duration_sec", 0) for r in rows) / 60
    speakers = sorted({r.get("speaker", "?") for r in rows})
    print("=" * 70)
    print("  LoRA fine-tune")
    print("=" * 70)
    print(f"  base model : {args.model}")
    print(f"  device     : {device}")
    print(f"  train rows : {len(rows)}  ({mins:.1f} min)")
    print(f"  speakers   : {', '.join(speakers)}")
    if args.smoke_test:
        print("  MODE       : SMOKE TEST (20 clips, 1 epoch) — results are meaningless, "
              "we're only checking it runs")
    print()

    processor = WhisperProcessor.from_pretrained(args.model, language="english", task="transcribe")

    load_kw = {}
    if args.int8:
        if device != "cuda":
            print("  [warn] --int8 needs CUDA; ignoring.")
        else:
            load_kw["load_in_8bit"] = True
    model = WhisperForConditionalGeneration.from_pretrained(args.model, **load_kw)

    # Let the model learn freely instead of being pinned to decoding defaults.
    model.config.forced_decoder_ids = None
    model.config.suppress_tokens = []
    model.config.use_cache = False

    if args.int8 and device == "cuda":
        from peft import prepare_model_for_kbit_training
        model = prepare_model_for_kbit_training(model)

    lora = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=["q_proj", "v_proj"],   # attention projections: the standard choice
        lora_dropout=args.lora_dropout,
        bias="none",
    )
    model = get_peft_model(model, lora)

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"  trainable  : {trainable:,} / {total:,}  ({100 * trainable / total:.3f}%)")
    print()

    ds = build_dataset(rows, processor)
    collator = Collator(processor)

    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)

    # TrainingArguments changes between transformers versions (v5 dropped several
    # older kwargs). Build the full set we'd like, then keep only what this
    # installed version actually accepts.
    wanted = {
        "output_dir": str(out / "checkpoints"),
        "per_device_train_batch_size": args.batch_size,
        "gradient_accumulation_steps": args.grad_accum,
        "learning_rate": args.lr,
        "num_train_epochs": args.epochs,
        "warmup_ratio": 0.1,
        "logging_steps": 10,
        "save_strategy": "epoch",
        "save_total_limit": 20,   # never prune: an interrupted run's checkpoint is the whole result
        "use_cpu": (device == "cpu"),
        "fp16": (device == "cuda"),
        "report_to": [],
        "remove_unused_columns": False,   # required: our dataset returns custom keys
        "label_names": ["labels"],        # required for PEFT-wrapped seq2seq
        "seed": args.seed,
    }
    import inspect
    accepted = set(inspect.signature(Seq2SeqTrainingArguments.__init__).parameters)
    targs_kwargs = {k: v for k, v in wanted.items() if k in accepted}
    dropped = sorted(set(wanted) - set(targs_kwargs))

    # If warmup_ratio isn't supported but warmup_steps is, convert it.
    if "warmup_ratio" in dropped and "warmup_steps" in accepted:
        steps_per_epoch = max(1, len(rows) // max(1, args.batch_size * args.grad_accum))
        targs_kwargs["warmup_steps"] = max(1, int(0.1 * steps_per_epoch * args.epochs))
        dropped.remove("warmup_ratio")

    if dropped:
        print(f"  [note] your transformers version doesn't accept: {', '.join(dropped)} — skipping them")

    targs = Seq2SeqTrainingArguments(**targs_kwargs)

    # Trainer's own checkpoints don't reliably include adapter_config.json, which makes
    # them awkward to load later. Save a clean, self-contained adapter after every epoch
    # so an interrupted run still leaves something you can merge and evaluate.
    from transformers import TrainerCallback

    class SaveAdapterEachEpoch(TrainerCallback):
        def on_epoch_end(self, targs_, state, control, **kw):
            n = int(round(state.epoch or 0))
            path = out / f"adapter_epoch{n}"
            model.save_pretrained(path)
            processor.save_pretrained(path)
            print(f"\n  [saved] {path}  (mergeable — usable even if you stop here)")

    trainer = Seq2SeqTrainer(
        model=model,
        args=targs,
        train_dataset=ds,
        data_collator=collator,
        callbacks=[SaveAdapterEachEpoch()],
    )

    # NOTE: no --resume option. HF Trainer's resume does not reliably restore PEFT adapter
    # weights — it reloads the optimizer state but not the adapter, so training silently
    # restarts from random weights with a decayed learning rate. If a run is interrupted,
    # merge the last adapter_epochN folder instead of trying to continue.
    t0 = time.time()
    result = trainer.train()
    elapsed = time.time() - t0

    # ---- save ----
    model.save_pretrained(out / "adapter")
    processor.save_pretrained(out / "adapter")
    print(f"\n  adapter saved -> {out / 'adapter'}")

    if not args.no_merge:
        print("  merging adapter into base model...")
        merged = model.merge_and_unload()
        merged.config.use_cache = True
        merged.save_pretrained(out / "merged")
        processor.save_pretrained(out / "merged")
        print(f"  merged model saved -> {out / 'merged'}")

    log = {
        "base_model": args.model,
        "train_manifest": str(args.train),
        "filters": {"speaker": args.speaker, "group": args.group,
                    "severity": args.severity, "min_words": args.min_words},
        "n_rows": len(rows),
        "minutes": round(mins, 2),
        "speakers": speakers,
        "epochs": args.epochs,
        "lr": args.lr,
        "lora_r": args.lora_r,
        "lora_alpha": args.lora_alpha,
        "trainable_params": trainable,
        "total_params": total,
        "train_runtime_sec": round(elapsed, 1),
        "final_loss": float(result.training_loss),
        "smoke_test": args.smoke_test,
    }
    (out / "train_log.json").write_text(json.dumps(log, indent=2))

    print("\n" + "=" * 70)
    print(f"  done in {elapsed / 60:.1f} min   final loss {result.training_loss:.4f}")
    print("=" * 70)
    print("\n  Now measure it against your baseline — same test set, same command shape:\n")
    if args.speaker:
        man = f"data/torgo/test_{args.speaker}.jsonl"
        print(f"    python scripts/eval_whisper.py --manifest {man} \\")
        print(f"        --model small --tag {args.speaker}-stock\n")
        print(f"    python scripts/eval_whisper.py --manifest {man} \\")
        print(f"        --backend transformers --model {out / 'merged'} --tag {args.speaker}-lora\n")
    else:
        print(f"    python scripts/eval_whisper.py --manifest data/torgo/test.jsonl \\")
        print(f"        --backend transformers --model {out / 'merged'} --tag {out.name}\n")
    if args.smoke_test:
        print("  (This was a smoke test. Re-run without --smoke-test for a real model.)\n")


if __name__ == "__main__":
    main()
