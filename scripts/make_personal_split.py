#!/usr/bin/env python3
"""
make_personal_split.py — does personalization work? Test it before building UI.

Simulates the app's "teach it your voice" flow using one TORGO speaker:

  base model  = the LOSO model that NEVER heard this speaker or their sentences
                (models/loso_<S>/merged, from run_loso.sh) — i.e. what a new
                user starts with
  train       = some of this speaker's recordings (their "teaching" session)
  test_seen   = a NEW recording of a phrase they taught it
                (the realistic app case: people repeat their own phrases)
  test_unseen = phrases they never taught it at all
                (does it learn the VOICE, or just memorise phrases?)

Split rules (per speaker, by normalised text, seeded):
  1. ~30% of distinct phrases -> test_unseen (every take)
  2. of the rest, phrases with >=2 takes -> one take held out as test_seen
  3. everything else -> train
Nothing in either test set shares an audio file with train, and nothing in
test_unseen shares text with train.

    python scripts/make_personal_split.py --speaker M04
    bash scripts/run_personal_sim.sh M04

Real user (recordings exported from the app's "Teach CoHear your voice"):
    python scripts/make_personal_split.py --speaker alex --export ~/Downloads/CoHear-voice-alex-2026-09-28.zip
"""

import argparse
import json
import random
import re
import shutil
import zipfile
from collections import defaultdict
from pathlib import Path


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z' ]", " ", t.lower())).strip()


def load_export(src: Path, name: str):
    """Unpack an app export into data/personal_raw/<name>/ and turn its
    manifest.jsonl into rows in the same schema as the TORGO manifest."""
    dest = Path("data/personal_raw") / name
    if src.is_file() and src.suffix == ".zip":
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True)
        with zipfile.ZipFile(src) as z:
            z.extractall(dest)
    elif src.is_dir():
        dest = src
    else:
        raise SystemExit(f"--export must be a .zip or a folder: {src}")
    man = next(dest.rglob("manifest.jsonl"), None)
    if not man:
        raise SystemExit(f"no manifest.jsonl inside {src} — is this a CoHear export?")
    rows = []
    for line in open(man):
        if not line.strip():
            continue
        s = json.loads(line)
        wav = (man.parent / s["file"]).resolve()
        if not wav.exists():
            continue
        text = s["text"].strip()
        rows.append({
            "audio_path": str(wav), "text": text, "speaker": name,
            "group": "dysarthric", "severity": "unknown", "session": "app",
            "utt_id": f"{name}_{s['id'][:8]}", "mic": "iphone",
            "duration_sec": float(s.get("durationSec", 0)), "n_words": len(text.split()),
        })
    print(f"loaded {len(rows)} recordings from {man.parent}")
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", required=True)
    ap.add_argument("--manifest", default="data/torgo/manifest_all.jsonl")
    ap.add_argument("--out", default="data/personal")
    ap.add_argument("--unseen-frac", type=float, default=0.30)
    ap.add_argument("--seed", type=int, default=13)
    ap.add_argument("--export", default=None,
                    help="zip or folder exported from the app (instead of a TORGO speaker)")
    args = ap.parse_args()

    if args.export:
        rows = load_export(Path(args.export).expanduser(), args.speaker)
    else:
        rows = [json.loads(l) for l in open(args.manifest)]
        rows = [r for r in rows if r["speaker"] == args.speaker]
    if not rows:
        raise SystemExit(f"no clips for {args.speaker}")

    by_text = defaultdict(list)
    for r in rows:
        by_text[norm(r["text"])].append(r)

    rng = random.Random(args.seed)
    texts = sorted(by_text)
    rng.shuffle(texts)
    n_unseen = round(len(texts) * args.unseen_frac)
    unseen_texts = set(texts[:n_unseen])

    train, seen, unseen = [], [], []
    for t, clips in by_text.items():
        clips = sorted(clips, key=lambda r: r["utt_id"])
        if t in unseen_texts:
            unseen += clips
        elif len(clips) >= 2:
            j = rng.randrange(len(clips))
            seen.append(clips[j])
            train += clips[:j] + clips[j + 1:]
        else:
            train += clips

    # Leak checks
    tr_audio = {r["audio_path"] for r in train}
    assert not tr_audio & {r["audio_path"] for r in seen + unseen}
    assert not {norm(r["text"]) for r in train} & unseen_texts

    d = Path(args.out) / args.speaker
    d.mkdir(parents=True, exist_ok=True)
    for name, part in (("train", train), ("test_seen", seen), ("test_unseen", unseen)):
        with open(d / f"{name}.jsonl", "w") as f:
            for r in part:
                f.write(json.dumps(r) + "\n")

    def desc(part):
        one = sum(r["n_words"] == 1 for r in part)
        mins = sum(r.get("duration_sec", 0) for r in part) / 60
        return f"{len(part):>4} clips ({one} words, {len(part) - one} sentences, {mins:.1f} min)"

    print(f"{args.speaker}: personal split -> {d}")
    print(f"  train        {desc(train)}   <- the 'teaching' recordings")
    print(f"  test_seen    {desc(seen)}   <- new take of a taught phrase")
    print(f"  test_unseen  {desc(unseen)}   <- phrases never taught")


if __name__ == "__main__":
    main()
