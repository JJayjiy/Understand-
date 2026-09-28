#!/usr/bin/env python3
"""Personalization results tables.

    python scripts/compare_personal.py M04              # one speaker
    python scripts/compare_personal.py M04 M01 M05 F03  # several + summary

Finds every model evaluated under eval_results/personal/<S>/<model>_<test>/.

Columns:
  word acc   exact-match accuracy on single-word clips
  sent WER   mean sentence WER (what eval_whisper prints)
  WER*       mean sentence WER excluding runaway loops (hyp > 2x ref + 2 words)
  median     median sentence WER — robust to one bad clip
  loops      runaway outputs among sentences
"""
import csv
import re
import statistics
import sys
from pathlib import Path

SPEAKERS = sys.argv[1:] or ["M04"]
ROOT = Path("eval_results/personal")
TESTS = (("test_seen", "NEW TAKE OF A TAUGHT PHRASE"), ("test_unseen", "PHRASES NEVER TAUGHT"))
ORDER = ["stock", "general", "personalstock", "personal25", "personal50", "personal100", "personal"]
LABEL = {
    "stock": "stock Whisper-small",
    "general": "TORGO general (never heard them)",
    "personalstock": "personal, from stock",
    "personal25": "personal, 25 clips",
    "personal50": "personal, 50 clips",
    "personal100": "personal, 100 clips",
    "personal": "personal, all (~190-320 clips)",
}


def models_for(S, test):
    d = ROOT / S
    if not d.exists():
        return []
    found = {p.name[: -len(test) - 1] for p in d.iterdir() if p.name.endswith("_" + test)}
    return [m for m in ORDER if m in found] + sorted(found - set(ORDER))


def load(S, model, test):
    f = next((ROOT / S / f"{model}_{test}").glob("per_utterance_*.csv"), None)
    return list(csv.DictReader(open(f))) if f else None


def stats(rows):
    words = [r for r in rows if int(r["n_words"]) == 1]
    sents = [r for r in rows if int(r["n_words"]) > 1]
    acc = sum(r["exact"] in ("1", "True", "true") for r in words) / len(words) if words else float("nan")
    w = [float(r["wer"]) for r in sents]
    runaway = [r for r in sents if len(r["hypothesis"].split()) > 2 * int(r["n_words"]) + 2]
    ok = [float(r["wer"]) for r in sents if r not in runaway]
    mean = lambda xs: sum(xs) / len(xs) if xs else float("nan")
    med = statistics.median(w) if w else float("nan")
    return dict(acc=acc, wer=mean(w), ok=mean(ok), med=med, loops=len(runaway), nw=len(words), ns=len(sents))


summary = {}
for S in SPEAKERS:
    print(f"\n==================  {S}  ==================")
    for test, title in TESTS:
        ms = models_for(S, test)
        if not ms:
            continue
        print(f"\n{title}  ({test})")
        print(f"  {'model':<34}{'word acc':>9}{'sent WER':>10}{'WER*':>8}{'median':>8}{'loops':>7}")
        for m in ms:
            rows = load(S, m, test)
            if not rows:
                continue
            s = stats(rows)
            summary[(S, test, m)] = s
            print(f"  {LABEL.get(m, m):<34}{s['acc']:>8.1%}{s['wer']:>10.1%}{s['ok']:>8.1%}{s['med']:>8.0%}{s['loops']:>7}")
        print(f"  ({s['nw']} single words, {s['ns']} sentences)")

if len(SPEAKERS) > 1:
    print("\n==================  SUMMARY: never-taught phrases, stock vs personal-from-stock  ==================")
    print(f"  {'speaker':<9}{'word acc':>20}{'median sent WER':>22}")
    for S in SPEAKERS:
        a, b = summary.get((S, "test_unseen", "stock")), summary.get((S, "test_unseen", "personalstock"))
        if a and b:
            print(f"  {S:<9}{a['acc']:>9.0%} -> {b['acc']:<8.0%}{a['med']:>11.0%} -> {b['med']:<8.0%}")

print("\nWER* excludes runaway loops; median is robust to single bad clips.\n")
