#!/usr/bin/env python3
"""
make_loso_split.py — the honest evaluation split.

WHY THIS EXISTS
The original split (torgo_prep.py --split random) held out 15% of each
speaker's clips. But TORGO reuses a fixed prompt list across sessions and
speakers, so 98% of test utterances had the exact same text as a training
utterance (100% for M04). The 84.4% -> 34.6% WER result on M04 therefore
measured "a voice I've heard, saying a sentence I've seen" — not how the
model does for a new person saying new things, which is what the app faces.

WHAT THIS DOES
Leave-one-speaker-out (LOSO), text-disjoint:
  test  = every clip from the held-out dysarthric speaker
  train = every clip from every OTHER speaker, minus any clip whose
          normalised text appears anywhere in the held-out speaker's set

So at test time the model has never heard this voice AND never seen any of
these words/sentences as training targets. It's the closest TORGO gets to
"a new person walks up and talks."

(The reverse — keep training intact and test only on unseen sentences —
leaves 1–12 test clips per speaker. Too few to mean anything.)

USAGE
    python scripts/make_loso_split.py                 # all 8 dysarthric speakers
    python scripts/make_loso_split.py --speakers M04 F03

    # then, per speaker (see scripts/run_loso.sh to do it all):
    python scripts/finetune_lora.py --train data/torgo/loso/M04/train.jsonl --out models/loso_M04 --device cpu
    python scripts/eval_whisper.py --manifest data/torgo/loso/M04/test.jsonl --backend transformers \
        --model models/loso_M04/merged --tag loso-M04 --out eval_results/loso_M04
    python scripts/eval_whisper.py --manifest data/torgo/loso/M04/test.jsonl --model small \
        --tag stock-M04 --out eval_results/stock_M04

Report both numbers side by side. That pair is the real result.
"""

import argparse
import json
import re
from collections import Counter
from pathlib import Path


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z' ]", " ", t.lower())).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="data/torgo/manifest_all.jsonl")
    ap.add_argument("--out", default="data/torgo/loso")
    ap.add_argument("--speakers", nargs="*", default=None,
                    help="held-out speakers (default: every dysarthric speaker)")
    args = ap.parse_args()

    rows = [json.loads(l) for l in open(args.manifest)]
    dys = sorted({r["speaker"] for r in rows if r["group"] == "dysarthric"})
    targets = args.speakers or dys

    out = Path(args.out)
    print(f"{'held out':<9}{'severity':<10}{'test':>6}{'train':>8}{'dropped':>9}   "
          f"{'test 1-word':>11}{'test sent.':>11}")
    summary = []
    for s in targets:
        test = [r for r in rows if r["speaker"] == s]
        if not test:
            print(f"{s}: no clips, skipping")
            continue
        banned = {norm(r["text"]) for r in test}
        others = [r for r in rows if r["speaker"] != s]
        train = [r for r in others if norm(r["text"]) not in banned]

        # Sanity: nothing leaks.
        assert not ({r["speaker"] for r in train} & {s})
        assert not ({norm(r["text"]) for r in train} & banned)

        d = out / s
        d.mkdir(parents=True, exist_ok=True)
        for name, part in (("train", train), ("test", test)):
            with open(d / f"{name}.jsonl", "w") as f:
                for r in part:
                    f.write(json.dumps(r) + "\n")

        one = sum(r["n_words"] == 1 for r in test)
        sev = test[0].get("severity", "?")
        print(f"{s:<9}{sev:<10}{len(test):>6}{len(train):>8}{len(others) - len(train):>9}   "
              f"{one:>11}{len(test) - one:>11}")
        summary.append({"held_out": s, "severity": sev, "test": len(test), "train": len(train),
                        "train_speakers": sorted({r['speaker'] for r in train}),
                        "dropped_for_text_overlap": len(others) - len(train)})

    (out / "summary.json").write_text(json.dumps(summary, indent=2))
    print(f"\nWrote {out}/<speaker>/train.jsonl and test.jsonl. Nothing leaks: speaker- and text-disjoint.")


if __name__ == "__main__":
    main()
