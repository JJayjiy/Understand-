#!/usr/bin/env python3
"""
eval_whisper.py — measure Whisper's word error rate on a TORGO manifest.

This produces your BASELINE: the "before" number you spend the rest of the
project beating. Run it once on stock Whisper, then again after fine-tuning
with the exact same command, and the two summary tables are your result.

    pip install faster-whisper jiwer

    # baseline on the held-out test set
    python eval_whisper.py --manifest data/torgo/test.jsonl --model small

    # quick smoke test first (30 clips, ~1 min)
    python eval_whisper.py --manifest data/torgo/test.jsonl --model tiny --limit 30

Outputs (in --out, default: eval_results/):
    per_utterance.csv   every clip: truth, hypothesis, WER, correct?
    summary.csv         breakdowns by group / severity / speaker / length
    (and the same tables printed to your terminal)

Two numbers matter, and you must report them SEPARATELY:
  * sentence WER      — on multi-word utterances. The real metric.
  * word accuracy     — exact-match on single-word utterances.
Blending them is misleading: on a one-word clip a single error is 100% WER,
and TORGO is ~75% single words, so a blended average is mostly noise.
"""

import argparse
import csv
import json
import re
import string
import sys
import time
from collections import defaultdict
from pathlib import Path

try:
    from jiwer import wer as jiwer_wer
except ImportError:
    sys.exit("Missing jiwer.  pip install jiwer")

# ---------------------------------------------------------------- normalization
# Both sides get the SAME treatment, or the comparison is meaningless.
# Whisper writes "Beta." and TORGO writes "beta" — without this you'd score that wrong.

_PUNCT = str.maketrans("", "", string.punctuation)
_NUM = {
    "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
    "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten",
    "11": "eleven", "12": "twelve", "13": "thirteen", "14": "fourteen",
    "15": "fifteen", "16": "sixteen", "17": "seventeen", "18": "eighteen",
    "19": "nineteen", "20": "twenty",
}


def normalize(text: str) -> str:
    """lowercase, strip punctuation, digits -> words, collapse whitespace."""
    t = text.lower().strip()
    t = t.replace("’", "'").replace("—", " ").replace("-", " ")
    t = t.translate(_PUNCT)
    t = " ".join(_NUM.get(w, w) for w in t.split())
    return " ".join(t.split())


def safe_wer(ref: str, hyp: str) -> float:
    """WER with empty-reference guard. Empty hypothesis on non-empty ref = 1.0."""
    if not ref:
        return 0.0 if not hyp else 1.0
    if not hyp:
        return 1.0
    try:
        return float(jiwer_wer(ref, hyp))
    except Exception:
        return 1.0


# ---------------------------------------------------------------- reporting
def pct(x):
    return f"{x * 100:5.1f}%"


def aggregate(rows, key):
    """Group rows and compute the two headline metrics per group."""
    buckets = defaultdict(list)
    for r in rows:
        buckets[r[key]].append(r)

    out = []
    for name, rs in buckets.items():
        multi = [r for r in rs if r["n_words"] > 1]
        single = [r for r in rs if r["n_words"] == 1]
        out.append({
            "bucket": name,
            "n": len(rs),
            "sentence_wer": (sum(r["wer"] for r in multi) / len(multi)) if multi else None,
            "n_sentences": len(multi),
            "word_accuracy": (sum(r["exact"] for r in single) / len(single)) if single else None,
            "n_single": len(single),
            "overall_wer": sum(r["wer"] for r in rs) / len(rs),
        })
    return sorted(out, key=lambda d: str(d["bucket"]))


def print_table(title, rows):
    print(f"\n  {title}")
    print("  " + "-" * 74)
    print(f"  {'':14s} {'n':>6s}  {'sentence WER':>13s} {'(n)':>6s}  {'word acc':>9s} {'(n)':>6s}")
    print("  " + "-" * 74)
    for r in rows:
        sw = pct(r["sentence_wer"]) if r["sentence_wer"] is not None else "    —"
        wa = pct(r["word_accuracy"]) if r["word_accuracy"] is not None else "    —"
        print(f"  {str(r['bucket']):14s} {r['n']:6d}  {sw:>13s} {r['n_sentences']:6d}  {wa:>9s} {r['n_single']:6d}")


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", required=True, help="a .jsonl from torgo_prep.py (use test.jsonl)")
    ap.add_argument("--model", default="small",
                    help="tiny|base|small|medium|large-v3, or a path to a converted local model")
    ap.add_argument("--out", default="eval_results", help="output directory")
    ap.add_argument("--limit", type=int, default=None,
                    help="evaluate a random N clips instead of all (smoke test). "
                         "Randomized, not the first N — the manifest is ordered by speaker.")
    ap.add_argument("--seed", type=int, default=13, help="seed for --limit sampling")
    ap.add_argument("--speaker", default=None, help="evaluate one speaker only, e.g. M04")
    ap.add_argument("--group", default=None, choices=["dysarthric", "control"])
    ap.add_argument("--severity", default=None, choices=["severe", "moderate", "mild", "none"])
    ap.add_argument("--beam-size", type=int, default=5)
    ap.add_argument("--device", default="cpu", choices=["cpu", "cuda", "auto"])
    ap.add_argument("--compute-type", default="int8", help="int8 (CPU) or float16 (GPU)")
    ap.add_argument("--tag", default=None, help="label for this run, e.g. 'stock' or 'lora-v1'")
    ap.add_argument("--backend", default="faster-whisper", choices=["faster-whisper", "transformers"],
                    help="faster-whisper for stock models (fast); transformers to evaluate a "
                         "fine-tuned model folder produced by finetune_lora.py (models/<run>/merged)")
    args = ap.parse_args()

    transcribe_fn = None
    if args.backend == "transformers":
        try:
            import torch
            from transformers import WhisperProcessor, WhisperForConditionalGeneration
        except ImportError:
            sys.exit("Missing transformers/torch.  pip install transformers torch soundfile")
        import soundfile as sf

        proc = WhisperProcessor.from_pretrained(args.model, language="english", task="transcribe")
        hf_model = WhisperForConditionalGeneration.from_pretrained(args.model)
        dev = "cuda" if torch.cuda.is_available() else "cpu"
        hf_model.to(dev).eval()
        forced = proc.get_decoder_prompt_ids(language="english", task="transcribe")

        def transcribe_fn(path):
            audio, sr = sf.read(path, dtype="float32")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)
            if sr != 16000:
                import librosa
                audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)
            feats = proc.feature_extractor(audio, sampling_rate=16000,
                                           return_tensors="pt").input_features.to(dev)
            with torch.no_grad():
                ids = hf_model.generate(feats, forced_decoder_ids=forced, max_new_tokens=200)
            return proc.batch_decode(ids, skip_special_tokens=True)[0].strip()
    else:
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            sys.exit("Missing faster-whisper.  pip install faster-whisper")

    manifest = Path(args.manifest).expanduser()
    if not manifest.exists():
        sys.exit(f"manifest not found: {manifest}")

    records = [json.loads(l) for l in open(manifest, encoding="utf-8") if l.strip()]

    if args.speaker:
        records = [r for r in records if r.get("speaker") == args.speaker]
    if args.group:
        records = [r for r in records if r.get("group") == args.group]
    if args.severity:
        records = [r for r in records if r.get("severity") == args.severity]
    if not records:
        sys.exit("No test utterances matched those filters.")

    if args.limit and args.limit < len(records):
        # Sample randomly: the manifest is grouped by speaker, so the first N
        # would all be one person and the numbers would be meaningless.
        import random
        random.Random(args.seed).shuffle(records)
        records = records[: args.limit]
    if not records:
        sys.exit("manifest is empty")

    tag = args.tag or Path(str(args.model)).name
    print(f"\n  model    : {args.model}   (backend: {args.backend})")
    print(f"  manifest : {manifest}  ({len(records)} utterances)")

    if transcribe_fn is None:
        print(f"  loading model (first run downloads it)...")
        model = WhisperModel(args.model, device=args.device, compute_type=args.compute_type)

        def transcribe_fn(path):
            segments, _ = model.transcribe(
                path,
                beam_size=args.beam_size,
                language="en",                     # never let it guess — atypical speech
                                                   # often gets misdetected as another language
                condition_on_previous_text=False,  # stops hallucination carry-over
            )
            return " ".join(s.text for s in segments).strip()

    rows = []
    t0 = time.time()
    for i, rec in enumerate(records, 1):
        audio = rec["audio_path"]
        try:
            hyp_raw = transcribe_fn(audio)
        except Exception as e:
            print(f"    [warn] {rec['utt_id']}: {e}")
            hyp_raw = ""

        ref = normalize(rec["text"])
        hyp = normalize(hyp_raw)
        w = safe_wer(ref, hyp)

        rows.append({
            "utt_id": rec["utt_id"],
            "speaker": rec["speaker"],
            "group": rec.get("group", "?"),
            "severity": rec.get("severity", "?"),
            "n_words": rec["n_words"],
            "length": "single" if rec["n_words"] == 1 else "sentence",
            "duration_sec": rec.get("duration_sec", 0),
            "reference": ref,
            "hypothesis": hyp,
            "hypothesis_raw": hyp_raw,
            "wer": w,
            "exact": 1 if ref == hyp else 0,
        })

        if i % 25 == 0 or i == len(records):
            el = time.time() - t0
            print(f"    {i}/{len(records)}  ({el:.0f}s, {el / i:.2f}s per clip)")

    # ---- write ----
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)

    with open(out / f"per_utterance_{tag}.csv", "w", newline="", encoding="utf-8") as f:
        w_ = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w_.writeheader()
        w_.writerows(rows)

    summary_rows = []
    for key, title in (("group", "BY GROUP"), ("severity", "BY SEVERITY"), ("speaker", "BY SPEAKER")):
        for r in aggregate(rows, key):
            summary_rows.append({"run": tag, "breakdown": key, **r})

    with open(out / f"summary_{tag}.csv", "w", newline="", encoding="utf-8") as f:
        w_ = csv.DictWriter(f, fieldnames=list(summary_rows[0].keys()))
        w_.writeheader()
        w_.writerows(summary_rows)

    # ---- report ----
    multi = [r for r in rows if r["n_words"] > 1]
    single = [r for r in rows if r["n_words"] == 1]

    print("\n" + "=" * 78)
    print(f"  BASELINE  —  run '{tag}'")
    print("=" * 78)
    print(f"\n  OVERALL")
    if multi:
        print(f"    sentence WER    : {pct(sum(r['wer'] for r in multi) / len(multi))}   ({len(multi)} utterances)")
    if single:
        print(f"    word accuracy   : {pct(sum(r['exact'] for r in single) / len(single))}   ({len(single)} utterances)")

    for key, title in (("group", "BY GROUP  (this gap is your motivating number)"),
                       ("severity", "BY SEVERITY"),
                       ("speaker", "BY SPEAKER")):
        print_table(title, aggregate(rows, key))

    # The headline comparison, stated for you.
    g = {r["bucket"]: r for r in aggregate(rows, "group")}
    if "control" in g and "dysarthric" in g:
        c, d = g["control"], g["dysarthric"]
        if c["sentence_wer"] is not None and d["sentence_wer"] is not None:
            print("\n  " + "-" * 74)
            print(f"  THE GAP: stock Whisper gets {pct(c['sentence_wer'])} sentence WER on control speakers")
            print(f"           and {pct(d['sentence_wer'])} on dysarthric speakers — same prompts, same mics.")
            print(f"           Gap = {pct(d['sentence_wer'] - c['sentence_wer'])}. Closing it is the whole project.")

    print(f"\n  written to: {out}/per_utterance_{tag}.csv and summary_{tag}.csv")
    print("=" * 78)
    print("\n  NOTE: on very short single-word clips Whisper sometimes hallucinates a")
    print("  whole sentence. Skim per_utterance.csv for these — they're a real finding,")
    print("  not a bug in your setup, and worth a slide.\n")


if __name__ == "__main__":
    main()
