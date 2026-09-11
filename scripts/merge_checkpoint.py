#!/usr/bin/env python3
"""
merge_checkpoint.py — turn a mid-training checkpoint into a usable model.

If a training run was interrupted (or you decided it had trained enough), the
checkpoints on disk already contain a perfectly good LoRA adapter. This loads
one, merges it into the base model, and writes a folder you can evaluate and
run in the app — no further training required.

    python scripts/merge_checkpoint.py \\
        --checkpoint models/m04/checkpoints/checkpoint-63 \\
        --base openai/whisper-small \\
        --out models/m04/merged

Then:
    python scripts/eval_whisper.py --manifest data/torgo/test_M04.jsonl \\
        --backend transformers --model models/m04/merged --tag m04-lora
"""

import argparse
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--checkpoint", required=True, help="a checkpoint-N folder from training")
    ap.add_argument("--base", default="openai/whisper-small",
                    help="the base model the adapter was trained on — must match")
    ap.add_argument("--out", required=True, help="where to write the merged model")
    args = ap.parse_args()

    ckpt = Path(args.checkpoint).expanduser()
    if not ckpt.exists():
        sys.exit(f"checkpoint not found: {ckpt}")

    try:
        from transformers import WhisperProcessor, WhisperForConditionalGeneration
        from peft import PeftModel
    except ImportError as e:
        sys.exit(f"Missing dependency: {e}\n  pip install transformers peft torch")

    print(f"  base model : {args.base}")
    print(f"  checkpoint : {ckpt}")

    base = WhisperForConditionalGeneration.from_pretrained(args.base)
    base.config.forced_decoder_ids = None
    base.config.suppress_tokens = []

    print("  loading adapter...")
    model = PeftModel.from_pretrained(base, str(ckpt))

    print("  merging adapter into base weights...")
    merged = model.merge_and_unload()
    merged.config.use_cache = True

    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    merged.save_pretrained(out)

    # The processor isn't in the checkpoint; take it from the base model.
    WhisperProcessor.from_pretrained(args.base, language="english",
                                     task="transcribe").save_pretrained(out)

    print(f"\n  merged model saved -> {out}")
    print("\n  Measure it:\n")
    print(f"    python scripts/eval_whisper.py --manifest data/torgo/test_M04.jsonl \\")
    print(f"        --backend transformers --model {out} --tag m04-lora\n")


if __name__ == "__main__":
    main()
