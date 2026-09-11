"""
Control-calibrated phone deviation on TORGO.

The problem this answers
------------------------
When a phone-level tool reports "this speaker deletes final /t/", there are two
possible causes: the speaker really deleted it, or the tool failed to detect it.
Counting cannot separate them, because both produce consistent, repeatable,
speaker-specific patterns.

The fix is a baseline. TORGO recorded control speakers reading the SAME prompts
in the SAME room with the SAME microphones. Any deviation measured on control
speakers is, by construction, not dysarthria -- it is natural variation plus
measurement noise. Subtract that floor and what remains is attributable signal.

This script establishes the floor and the signal using TORGO's own hand-checked
phone segmentations (.PHN), so no neural phone recognizer is involved. That is
deliberate: you cannot calibrate a recognizer against a yardstick the recognizer
itself produced. This builds the yardstick.

Method
------
1. Read every .PHN (phone sequence) and its prompt text.
2. Group renditions of the same prompt across speakers.
3. For each prompt, the reference is the MEDOID control rendition -- the control
   sequence with the smallest total edit distance to the other control
   renditions. Not a dictionary pronunciation: how typical speakers actually
   said this word in this room.
4. Noise floor: align each control rendition against the medoid of the OTHER
   controls (leave-one-out). This is control-vs-control disagreement.
5. Signal: align each dysarthric rendition against the control medoid.
6. Report per-phone deletion and substitution rates for both, and the excess.

Usage
-----
    python scripts/phone_calibration.py \
        --dysarthric-root /path/to/torgo/M \
        --control-root /path/to/torgo/MC \
        --out results/
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

# TIMIT-style non-speech labels. Not phones; they carry no phonological content.
NON_SPEECH = {"noi", "sil", "h#", "pau", "epi"}

# TIMIT splits each stop into a closure and a release (dcl+d, tcl+t...).
# We keep the release and drop the closure, so a stop counts once.
CLOSURES = {"dcl", "tcl", "kcl", "pcl", "bcl", "gcl"}

# Valid ARPABET. Anything outside this is an annotation typo (the corpus has a
# handful: "tclt", "kclae", "ahpcl", "lab2"). Dropped rather than guessed at.
ARPABET = {
    "aa", "ae", "ah", "ao", "aw", "ay", "b", "ch", "d", "dh", "eh", "er", "ey",
    "f", "g", "hh", "ih", "iy", "jh", "k", "l", "m", "n", "ng", "ow", "oy", "p",
    "r", "s", "sh", "t", "th", "uh", "uw", "v", "w", "y", "z", "zh",
}

EMPTY = "∅"

# Prompt lines that are instructions to the participant, not speech to compare.
BAD_PROMPT = re.compile(r"^\[|xxx|\.jpg|\.png|input/|described|relax|^\s*$", re.I)


# ---------------------------------------------------------------- loading


def read_phn(path):
    """Return the cleaned phone sequence from one .PHN file."""
    phones = []
    for line in path.read_text(errors="ignore").splitlines():
        parts = line.split()
        if len(parts) != 3:
            continue
        label = parts[2].strip().lower()
        if label in NON_SPEECH or label in CLOSURES:
            continue
        if label not in ARPABET:
            continue
        phones.append(label)
    return phones


def normalize_prompt(text):
    text = text.strip().lower()
    text = re.sub(r"[^a-z' ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def collect(root, group):
    """Walk a speaker root and yield one record per utterance with both a
    prompt and a phone segmentation."""
    root = Path(root)
    records = []
    for phn_path in sorted(root.rglob("phn_headMic/*.PHN")):
        session_dir = phn_path.parent.parent
        prompt_path = session_dir / "prompts" / (phn_path.stem + ".txt")
        if not prompt_path.exists():
            continue
        raw = prompt_path.read_text(errors="ignore").strip()
        if BAD_PROMPT.search(raw):
            continue
        text = normalize_prompt(raw)
        if not text:
            continue
        phones = read_phn(phn_path)
        if not phones:
            continue
        # root.name is the speaker code for .../M04, .../MC01
        speaker = session_dir.parent.name
        records.append({
            "speaker": speaker,
            "group": group,
            "text": text,
            "phones": phones,
            "utt_id": f"{speaker}_{session_dir.name}_{phn_path.stem}",
        })
    return records


# ---------------------------------------------------------------- alignment
# Same algorithm as phonetics.py on the melodie-phonetics branch, kept
# standalone so this script runs on either branch.


def align(expected, produced):
    rows, cols = len(expected) + 1, len(produced) + 1
    cost = [[0] * cols for _ in range(rows)]
    back = [[None] * cols for _ in range(rows)]
    for i in range(1, rows):
        cost[i][0], back[i][0] = i, "deletion"
    for j in range(1, cols):
        cost[0][j], back[0][j] = j, "insertion"
    for i in range(1, rows):
        for j in range(1, cols):
            same = expected[i - 1] == produced[j - 1]
            options = {
                ("match" if same else "substitution"): cost[i - 1][j - 1] + (0 if same else 1),
                "deletion": cost[i - 1][j] + 1,
                "insertion": cost[i][j - 1] + 1,
            }
            op = min(options, key=options.get)
            cost[i][j], back[i][j] = options[op], op
    out, i, j = [], len(expected), len(produced)
    while i > 0 or j > 0:
        op = back[i][j]
        if op in ("match", "substitution"):
            out.append((expected[i - 1], produced[j - 1], op))
            i, j = i - 1, j - 1
        elif op == "deletion":
            out.append((expected[i - 1], EMPTY, op))
            i -= 1
        else:
            out.append((EMPTY, produced[j - 1], op))
            j -= 1
    return list(reversed(out))


def distance(a, b):
    return sum(1 for _, _, op in align(a, b) if op != "match")


def medoid(sequences):
    """The sequence with least total distance to all the others."""
    if len(sequences) == 1:
        return sequences[0]
    best, best_cost = None, None
    for candidate in sequences:
        total = sum(distance(candidate, other) for other in sequences if other is not candidate)
        if best_cost is None or total < best_cost:
            best, best_cost = candidate, total
    return best


# ---------------------------------------------------------------- experiment


def run(dysarthric_root, control_root, out_dir, min_controls=3, max_phones=14):
    control = collect(control_root, "control")
    dysarthric = collect(dysarthric_root, "dysarthric")
    print(f"control utterances:    {len(control)}")
    print(f"dysarthric utterances: {len(dysarthric)}")

    by_text_control = defaultdict(list)
    for r in control:
        by_text_control[r["text"]].append(r)
    by_text_dys = defaultdict(list)
    for r in dysarthric:
        by_text_dys[r["text"]].append(r)

    shared = [
        t for t in by_text_control
        if t in by_text_dys and len(by_text_control[t]) >= min_controls
    ]
    # Long sentences make the O(n^2) medoid search slow and add alignment noise.
    shared = [t for t in shared if len(by_text_control[t][0]["phones"]) <= max_phones]
    print(f"prompts said by both groups (>= {min_controls} controls): {len(shared)}")

    # ref_phone -> Counter of operations, per group
    ops = {"control": defaultdict(Counter), "dysarthric": defaultdict(Counter)}
    # per-speaker totals
    speaker_totals = defaultdict(lambda: {"ref": 0, "err": 0, "clips": 0})
    per_utt = []

    for text in shared:
        controls = by_text_control[text]
        control_seqs = [r["phones"] for r in controls]

        # --- noise floor: leave-one-out control vs control ---
        for r in controls:
            others = [s for s in control_seqs if s is not r["phones"]]
            if len(others) < 2:
                continue
            ref = medoid(others)
            alignment = align(ref, r["phones"])
            errors = 0
            for exp, prod, op in alignment:
                if exp != EMPTY:
                    ops["control"][exp][op] += 1
                if op != "match":
                    errors += 1
            n_ref = sum(1 for e, _, _ in alignment if e != EMPTY)
            st = speaker_totals[r["speaker"]]
            st["ref"] += n_ref
            st["err"] += errors
            st["clips"] += 1
            per_utt.append({
                "utt_id": r["utt_id"], "speaker": r["speaker"], "group": "control",
                "text": text, "n_ref_phones": n_ref, "errors": errors,
                "per": round(errors / n_ref, 4) if n_ref else None,
            })

        # --- signal: dysarthric vs full control medoid ---
        ref = medoid(control_seqs)
        for r in by_text_dys[text]:
            alignment = align(ref, r["phones"])
            errors = 0
            for exp, prod, op in alignment:
                if exp != EMPTY:
                    ops["dysarthric"][exp][op] += 1
                if op != "match":
                    errors += 1
            n_ref = sum(1 for e, _, _ in alignment if e != EMPTY)
            st = speaker_totals[r["speaker"]]
            st["ref"] += n_ref
            st["err"] += errors
            st["clips"] += 1
            per_utt.append({
                "utt_id": r["utt_id"], "speaker": r["speaker"], "group": "dysarthric",
                "text": text, "n_ref_phones": n_ref, "errors": errors,
                "per": round(errors / n_ref, 4) if n_ref else None,
            })

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # ---- per-phone table ----
    rows = []
    phones = sorted(set(ops["control"]) | set(ops["dysarthric"]))
    for phone in phones:
        c, d = ops["control"][phone], ops["dysarthric"][phone]
        c_n, d_n = sum(c.values()), sum(d.values())
        if c_n < 20 or d_n < 20:      # too rare to trust
            continue
        c_del, d_del = c["deletion"] / c_n, d["deletion"] / d_n
        c_sub, d_sub = c["substitution"] / c_n, d["substitution"] / d_n
        rows.append({
            "phone": phone,
            "control_n": c_n, "dysarthric_n": d_n,
            "control_deletion_rate": round(c_del, 4),
            "dysarthric_deletion_rate": round(d_del, 4),
            "excess_deletion": round(d_del - c_del, 4),
            "control_substitution_rate": round(c_sub, 4),
            "dysarthric_substitution_rate": round(d_sub, 4),
            "excess_substitution": round(d_sub - c_sub, 4),
            "control_error_rate": round(1 - c["match"] / c_n, 4),
            "dysarthric_error_rate": round(1 - d["match"] / d_n, 4),
            "excess_error": round(c["match"] / c_n - d["match"] / d_n, 4),
        })
    rows.sort(key=lambda r: -r["excess_error"])
    with (out_dir / "phone_calibration.csv").open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    # ---- per-speaker table ----
    spk_rows = []
    for spk, t in sorted(speaker_totals.items()):
        spk_rows.append({
            "speaker": spk,
            "group": "control" if spk.startswith(("MC", "FC")) else "dysarthric",
            "clips": t["clips"],
            "ref_phones": t["ref"],
            "phone_errors": t["err"],
            "per": round(t["err"] / t["ref"], 4) if t["ref"] else None,
        })
    with (out_dir / "phone_calibration_by_speaker.csv").open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(spk_rows[0].keys()))
        writer.writeheader()
        writer.writerows(spk_rows)

    with (out_dir / "phone_calibration_utterances.csv").open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(per_utt[0].keys()))
        writer.writeheader()
        writer.writerows(per_utt)

    # ---- summary ----
    def rate(group):
        tot = sum(sum(ops[group][p].values()) for p in ops[group])
        match = sum(ops[group][p]["match"] for p in ops[group])
        return 1 - match / tot if tot else None, tot

    c_rate, c_tot = rate("control")
    d_rate, d_tot = rate("dysarthric")
    summary = {
        "prompts_compared": len(shared),
        "control_reference_phones": c_tot,
        "dysarthric_reference_phones": d_tot,
        "control_phone_error_rate": round(c_rate, 4),
        "dysarthric_phone_error_rate": round(d_rate, 4),
        "noise_floor_share": round(c_rate / d_rate, 4) if d_rate else None,
    }
    (out_dir / "phone_calibration_summary.json").write_text(json.dumps(summary, indent=2))

    print()
    print(f"control-vs-control phone error rate (noise floor): {c_rate:.1%}")
    print(f"dysarthric-vs-control phone error rate (signal):   {d_rate:.1%}")
    print(f"the floor is {c_rate / d_rate:.0%} of the measured signal")
    print()
    print(f"{'phone':>6} {'ctrl_err':>9} {'dys_err':>9} {'excess':>8}  {'ctrl_del':>9} {'dys_del':>8}")
    for r in rows[:15]:
        print(f"{r['phone']:>6} {r['control_error_rate']:>9.1%} {r['dysarthric_error_rate']:>9.1%} "
              f"{r['excess_error']:>8.1%}  {r['control_deletion_rate']:>9.1%} {r['dysarthric_deletion_rate']:>8.1%}")
    print(f"\nwrote 4 files to {out_dir}/")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dysarthric-root", required=True)
    ap.add_argument("--control-root", required=True)
    ap.add_argument("--out", default="results")
    ap.add_argument("--min-controls", type=int, default=3)
    ap.add_argument("--max-phones", type=int, default=14)
    a = ap.parse_args()
    run(a.dysarthric_root, a.control_root, a.out, a.min_controls, a.max_phones)
