#!/usr/bin/env python3
"""
make_results.py — turn eval runs into the CSVs you'll actually cite.

Reads the per-utterance CSVs written by eval_whisper.py and produces:

    results/comparison.csv       one row per condition — the headline table
    results/side_by_side.csv     one row per clip: truth, stock, ours — demo material
    results/by_severity.csv      the severity gradient from the full baseline run

Usage:
    python scripts/make_results.py --before m04-stock --after m04-lora --label M04
    python scripts/make_results.py --before m04-stock --after m04-lora --label M04 \\
        --full-baseline stock
"""

import argparse
import csv
from pathlib import Path

EVAL_DIR = Path("eval_results")
OUT_DIR = Path("results")


def load(tag):
    p = EVAL_DIR / f"per_utterance_{tag}.csv"
    if not p.exists():
        raise SystemExit(f"not found: {p}\n  (tags available: "
                         f"{[f.stem.replace('per_utterance_','') for f in EVAL_DIR.glob('per_utterance_*.csv')]})")
    return list(csv.DictReader(open(p, encoding="utf-8")))


def metrics(rows):
    multi = [r for r in rows if int(r["n_words"]) > 1]
    single = [r for r in rows if int(r["n_words"]) == 1]
    return {
        "n_clips": len(rows),
        "n_sentences": len(multi),
        "sentence_wer": sum(float(r["wer"]) for r in multi) / len(multi) if multi else None,
        "n_single_words": len(single),
        "word_accuracy": sum(int(r["exact"]) for r in single) / len(single) if single else None,
        "words_correct": sum(int(r["exact"]) for r in single),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--before", required=True, help="tag of the stock run, e.g. m04-stock")
    ap.add_argument("--after", required=True, help="tag of the fine-tuned run, e.g. m04-lora")
    ap.add_argument("--label", default="speaker", help="name for this comparison, e.g. M04")
    ap.add_argument("--full-baseline", default=None,
                    help="tag of the whole-test-set run, for the severity table (e.g. stock)")
    args = ap.parse_args()

    OUT_DIR.mkdir(exist_ok=True)
    before, after = load(args.before), load(args.after)
    mb, ma = metrics(before), metrics(after)

    # ---------- comparison.csv ----------
    rows = []
    for name, m, tag in ((f"Stock Whisper-small", mb, args.before),
                         (f"+ personal adaptation ({args.label})", ma, args.after)):
        rows.append({
            "condition": name,
            "run_tag": tag,
            "clips": m["n_clips"],
            "sentences": m["n_sentences"],
            "sentence_wer": round(m["sentence_wer"], 4) if m["sentence_wer"] is not None else "",
            "single_words": m["n_single_words"],
            "words_correct": m["words_correct"],
            "word_accuracy": round(m["word_accuracy"], 4) if m["word_accuracy"] is not None else "",
        })

    if mb["sentence_wer"] and ma["sentence_wer"] is not None:
        abs_drop = mb["sentence_wer"] - ma["sentence_wer"]
        rel_drop = abs_drop / mb["sentence_wer"]
        rows.append({
            "condition": "IMPROVEMENT",
            "run_tag": "",
            "clips": "",
            "sentences": "",
            "sentence_wer": f"-{abs_drop:.4f} absolute / -{rel_drop:.1%} relative",
            "single_words": "",
            "words_correct": f"{ma['words_correct'] - mb['words_correct']:+d}",
            "word_accuracy": (f"{ma['word_accuracy'] / mb['word_accuracy']:.1f}x"
                              if mb["word_accuracy"] else ""),
        })

    with open(OUT_DIR / "comparison.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # ---------- side_by_side.csv ----------
    b_by_id = {r["utt_id"]: r for r in before}
    sbs = []
    for r in after:
        b = b_by_id.get(r["utt_id"])
        if not b:
            continue
        sbs.append({
            "utt_id": r["utt_id"],
            "n_words": r["n_words"],
            "duration_sec": r["duration_sec"],
            "what_they_said": r["reference"],
            "stock_whisper_heard": b["hypothesis"],
            "cohear_heard": r["hypothesis"],
            "stock_wer": round(float(b["wer"]), 3),
            "cohear_wer": round(float(r["wer"]), 3),
            "stock_correct": b["exact"],
            "cohear_correct": r["exact"],
            "improved": int(float(r["wer"]) < float(b["wer"])),
        })
    sbs.sort(key=lambda d: float(d["stock_wer"]) - float(d["cohear_wer"]), reverse=True)
    with open(OUT_DIR / "side_by_side.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(sbs[0].keys()))
        w.writeheader()
        w.writerows(sbs)

    # ---------- by_severity.csv ----------
    if args.full_baseline:
        full = load(args.full_baseline)
        buckets = {}
        for r in full:
            buckets.setdefault(r["severity"], []).append(r)
        order = ["none", "mild", "moderate", "severe"]
        srows = []
        for sev in order:
            if sev not in buckets:
                continue
            m = metrics(buckets[sev])
            srows.append({
                "severity": sev,
                "speakers": ",".join(sorted({r["speaker"] for r in buckets[sev]})),
                "clips": m["n_clips"],
                "sentence_wer": round(m["sentence_wer"], 4) if m["sentence_wer"] is not None else "",
                "word_accuracy": round(m["word_accuracy"], 4) if m["word_accuracy"] is not None else "",
            })
        with open(OUT_DIR / "by_severity.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(srows[0].keys()))
            w.writeheader()
            w.writerows(srows)

    # ---------- report ----------
    print("=" * 66)
    print(f"  RESULTS — {args.label}")
    print("=" * 66)
    print(f"\n  {'':26s} {'sentence WER':>13s} {'word accuracy':>15s}")
    print(f"  {'stock Whisper-small':26s} {mb['sentence_wer']:>12.1%} {mb['word_accuracy']:>15.1%}")
    print(f"  {'+ personal adaptation':26s} {ma['sentence_wer']:>12.1%} {ma['word_accuracy']:>15.1%}")
    print(f"\n  sentence WER  : {mb['sentence_wer']:.1%} -> {ma['sentence_wer']:.1%} "
          f"({(mb['sentence_wer']-ma['sentence_wer'])/mb['sentence_wer']:.1%} relative reduction)")
    print(f"  words correct : {mb['words_correct']}/{mb['n_single_words']} -> "
          f"{ma['words_correct']}/{ma['n_single_words']} "
          f"({ma['word_accuracy']/mb['word_accuracy']:.1f}x)")
    print(f"\n  written to {OUT_DIR}/:")
    print(f"    comparison.csv     the headline table")
    print(f"    side_by_side.csv   every clip, sorted by biggest improvement — demo material")
    if args.full_baseline:
        print(f"    by_severity.csv    the severity gradient")
    print("=" * 66)


if __name__ == "__main__":
    main()
