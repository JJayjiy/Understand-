#!/usr/bin/env python3
"""
torgo_prep.py — turn a raw TORGO folder into a clean Whisper fine-tuning manifest.

TORGO layout:
    <SPEAKER>/<Session#>/prompts/0001.txt     the text that was prompted
    <SPEAKER>/<Session#>/wav_headMic/0001.wav close-talk mic  (preferred: cleaner)
    <SPEAKER>/<Session#>/wav_arrayMic/0001.wav far-field array mic

Most of the work here is THROWING THINGS AWAY. Raw TORGO prompts include
instructions ("[relax your mouth]"), image-description references, and junk
markers — none of which are transcripts of what was said. Training on those
teaches the model to hallucinate.

Usage
-----
    python torgo_prep.py --root /path/to/TORGO --out data/torgo
    python torgo_prep.py --root /path/to/TORGO --out data/torgo --min-words 2 --split speaker

Outputs (in --out):
    manifest_all.jsonl   every usable utterance
    train.jsonl          training split
    test.jsonl           held-out split (NEVER train on this)
    summary.csv          per-speaker counts and minutes

Only the standard library is required.
"""

import argparse
import csv
import json
import random
import re
import unicodedata
import wave
from collections import Counter, defaultdict
from pathlib import Path

# Prompts that are instructions/images/junk rather than transcripts.
RE_BRACKET = re.compile(r"^\s*\[.*\]\s*$", re.S)
RE_IMAGE = re.compile(r"(input/images|\.jpe?g$|\.png$)", re.I)
JUNK_TEXT = {"xxx", "yyy", "", "-", "--"}

# TORGO speaker IDs: F01/M01 = dysarthric, FC01/MC01 = control (non-dysarthric).
RE_CONTROL = re.compile(r"^[FM]C\d+$", re.I)

# Severity read from each speaker's Notes/*.csv (Frenchay-style "Intel." ratings,
# a = normal ... e = most impaired). Words/sentences ratings in comments.
SEVERITY = {
    "F01": "severe",    # d   / d-e
    "F03": "mild",      # a   / a
    "F04": "mild",      # a   / a
    "M01": "severe",    # c/d / d-e
    "M02": "severe",    # c/d / d-e
    "M03": "mild",      # a   / a
    "M04": "severe",    # d/e / d-e   (most impaired)
    "M05": "moderate",  # a   / c
}


def speaker_group(speaker: str) -> str:
    return "control" if RE_CONTROL.match(speaker) else "dysarthric"


def speaker_severity(speaker: str) -> str:
    if speaker_group(speaker) == "control":
        return "none"
    return SEVERITY.get(speaker.upper(), "unknown")


def clean_text(raw: str):
    """Return normalized transcript, or None if this prompt isn't a transcript."""
    t = unicodedata.normalize("NFKC", raw).strip()
    if not t or RE_BRACKET.match(t) or RE_IMAGE.search(t):
        return None
    # Strip any leftover bracketed asides, collapse whitespace.
    t = re.sub(r"\[[^\]]*\]", " ", t)
    t = " ".join(t.split())
    if t.lower() in JUNK_TEXT:
        return None
    # Must contain at least one letter (drops stray punctuation-only prompts).
    if not re.search(r"[A-Za-z]", t):
        return None
    return t


def wav_duration(path: Path):
    try:
        with wave.open(str(path)) as w:
            if w.getnframes() == 0 or w.getframerate() == 0:
                return None
            return w.getnframes() / float(w.getframerate())
    except Exception:
        return None


def collect(root: Path, mic_pref):
    """Walk TORGO and pair each prompt with its audio."""
    records, skipped = [], Counter()

    for prompt_file in sorted(root.glob("*/Session*/prompts/*.txt")):
        session_dir = prompt_file.parent.parent
        speaker = session_dir.parent.name
        session = session_dir.name
        utt = prompt_file.stem

        try:
            raw = prompt_file.read_text(encoding="utf-8", errors="replace")
        except Exception:
            skipped["unreadable prompt"] += 1
            continue

        text = clean_text(raw)
        if text is None:
            skipped["not a transcript (instruction/image/junk)"] += 1
            continue

        # Pick a mic, preferring the close-talk head mic.
        audio = None
        used_mic = None
        for mic in mic_pref:
            cand = session_dir / f"wav_{mic}" / f"{utt}.wav"
            if cand.exists():
                audio, used_mic = cand, mic
                break
        if audio is None:
            skipped["no matching wav"] += 1
            continue

        dur = wav_duration(audio)
        if dur is None:
            skipped["unreadable/empty wav"] += 1
            continue

        records.append({
            "audio_path": str(audio.resolve()),
            "text": text,
            "speaker": speaker,
            "group": speaker_group(speaker),
            "severity": speaker_severity(speaker),
            "session": session,
            "utt_id": f"{speaker}_{session}_{utt}",
            "mic": used_mic,
            "duration_sec": round(dur, 3),
            "n_words": len(text.split()),
        })

    return records, skipped


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True, help="TORGO root (the folder containing F01/, F03/, ...)")
    ap.add_argument("--out", default="data/torgo", help="output directory")
    ap.add_argument("--mic", default="head", choices=["head", "array", "head-only", "array-only"],
                    help="head = prefer headMic then arrayMic (default); *-only = no fallback")
    ap.add_argument("--group", default="all", choices=["all", "dysarthric", "control"],
                    help="which speakers to include. dysarthric = F##/M##, control = FC##/MC##")
    ap.add_argument("--severity", default="all", nargs="+",
                    choices=["all", "severe", "moderate", "mild", "none", "unknown"],
                    help="filter by dysarthria severity (from the Notes assessments)")
    ap.add_argument("--min-words", type=int, default=1,
                    help="drop utterances shorter than this. Use 2+ to exclude isolated words.")
    ap.add_argument("--min-dur", type=float, default=0.3, help="seconds")
    ap.add_argument("--max-dur", type=float, default=30.0, help="Whisper's window is 30s")
    ap.add_argument("--split", default="random", choices=["random", "speaker", "session"],
                    help="random = 15%% per speaker (personalization). "
                         "speaker = hold out whole speakers (hardest, speaker-independent). "
                         "session = hold out each speaker's last session.")
    ap.add_argument("--test-frac", type=float, default=0.15)
    ap.add_argument("--holdout-speaker", default=None, help="for --split speaker; default = last speaker alphabetically")
    ap.add_argument("--seed", type=int, default=13)
    args = ap.parse_args()

    root = Path(args.root).expanduser()
    if not root.exists():
        raise SystemExit(f"--root not found: {root}")

    mic_pref = {"head": ["headMic", "arrayMic"], "array": ["arrayMic", "headMic"],
                "head-only": ["headMic"], "array-only": ["arrayMic"]}[args.mic]

    records, skipped = collect(root, mic_pref)

    kept, dropped = [], Counter()
    for r in records:
        sev_filter = set(args.severity) if isinstance(args.severity, list) else {args.severity}
        if args.group != "all" and r["group"] != args.group:
            dropped[f"not in --group {args.group}"] += 1
        elif "all" not in sev_filter and r["severity"] not in sev_filter:
            dropped[f"severity not in {sorted(sev_filter)}"] += 1
        elif r["n_words"] < args.min_words:
            dropped[f"< {args.min_words} words"] += 1
        elif r["duration_sec"] < args.min_dur:
            dropped["too short"] += 1
        elif r["duration_sec"] > args.max_dur:
            dropped["too long (>30s)"] += 1
        else:
            kept.append(r)

    if not kept:
        raise SystemExit("No usable utterances. Check --root points at the folder containing F01/, F03/, ...")

    # ---- split ----
    rng = random.Random(args.seed)
    by_speaker = defaultdict(list)
    for r in kept:
        by_speaker[r["speaker"]].append(r)

    train, test = [], []
    if args.split == "speaker":
        holdout = args.holdout_speaker or sorted(by_speaker)[-1]
        if holdout not in by_speaker:
            raise SystemExit(f"--holdout-speaker {holdout} not found. Options: {sorted(by_speaker)}")
        for spk, rows in by_speaker.items():
            (test if spk == holdout else train).extend(rows)
        split_desc = f"speaker-independent (held out {holdout})"
    elif args.split == "session":
        for spk, rows in by_speaker.items():
            sessions = sorted({r["session"] for r in rows})
            last = sessions[-1]
            for r in rows:
                (test if r["session"] == last and len(sessions) > 1 else train).append(r)
        split_desc = "held out each speaker's last session"
    else:
        for spk, rows in by_speaker.items():
            rows = rows[:]
            rng.shuffle(rows)
            n_test = max(1, int(round(len(rows) * args.test_frac)))
            test.extend(rows[:n_test])
            train.extend(rows[n_test:])
        split_desc = f"random {args.test_frac:.0%} per speaker"

    # Safety: no utterance may appear in both splits.
    overlap = {r["utt_id"] for r in train} & {r["utt_id"] for r in test}
    assert not overlap, f"LEAK: {len(overlap)} utterances in both splits"

    # ---- write ----
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)

    def dump(rows, name):
        with open(out / name, "w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

    dump(kept, "manifest_all.jsonl")
    dump(train, "train.jsonl")
    dump(test, "test.jsonl")

    with open(out / "summary.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["speaker", "group", "severity", "utterances", "minutes",
                    "single_word", "multi_word", "train", "test"])
        tr = Counter(r["speaker"] for r in train)
        te = Counter(r["speaker"] for r in test)
        for spk in sorted(by_speaker):
            rows = by_speaker[spk]
            w.writerow([spk, speaker_group(spk), speaker_severity(spk), len(rows),
                        round(sum(r["duration_sec"] for r in rows) / 60, 2),
                        sum(1 for r in rows if r["n_words"] == 1),
                        sum(1 for r in rows if r["n_words"] > 1),
                        tr.get(spk, 0), te.get(spk, 0)])

    # ---- report ----
    total_min = sum(r["duration_sec"] for r in kept) / 60
    multi = sum(1 for r in kept if r["n_words"] > 1)
    print("=" * 62)
    print("TORGO → Whisper manifest")
    print("=" * 62)
    print(f"  prompts skipped : {sum(skipped.values())}")
    for k, v in skipped.most_common():
        print(f"      {v:5d}  {k}")
    if dropped:
        print(f"  filtered out    : {sum(dropped.values())}")
        for k, v in dropped.most_common():
            print(f"      {v:5d}  {k}")
    print(f"\n  USABLE          : {len(kept)} utterances, {total_min:.1f} min")
    print(f"      single-word : {len(kept) - multi}")
    print(f"      multi-word  : {multi}")

    for grp in ("dysarthric", "control"):
        rows = [r for r in kept if r["group"] == grp]
        if rows:
            spks = sorted({r["speaker"] for r in rows})
            mins = sum(r["duration_sec"] for r in rows) / 60
            print(f"  {grp:15s} : {len(rows):5d} utts, {mins:6.1f} min  ({len(spks)} speakers: {', '.join(spks)})")

    print("  by severity     :")
    for sev in ("severe", "moderate", "mild", "none", "unknown"):
        rows = [r for r in kept if r["severity"] == sev]
        if rows:
            spks = sorted({r["speaker"] for r in rows})
            mins = sum(r["duration_sec"] for r in rows) / 60
            print(f"      {sev:9s} : {len(rows):5d} utts, {mins:6.1f} min  ({', '.join(spks)})")
    print(f"\n  split           : {split_desc}")
    print(f"      train       : {len(train)}")
    print(f"      test        : {len(test)}   ← never train on this")
    print(f"\n  written to      : {out}/")
    if multi < 100:
        print("\n  NOTE: few multi-word utterances. Isolated words are a weak training")
        print("        signal and make WER noisy (one wrong word = 100% WER for that clip).")
        print("        Consider reporting single-word accuracy separately from sentence WER.")
    print("=" * 62)


if __name__ == "__main__":
    main()
