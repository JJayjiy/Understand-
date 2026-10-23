#!/usr/bin/env python3
"""
torgo_to_export.py — use a TORGO speaker as a stand-in app user.

Makes two things:
  1. exports/CoHear-voice-<s>-torgo.zip
     The speaker's TEACHING recordings (data/personal/<S>/train.jsonl) packaged
     exactly like the app's "Export recordings" zip. Feed it to
     build_personal_model.sh to get a personal model for the phone.

  2. exports/<S>_demo/
     Held-out clips the model never trained on (from test_unseen and test_seen),
     numbered, sentences first, with answers.txt. Play them out loud next to the
     phone with scripts/play_demo.sh and compare "CoHear" vs "Your voice (<S>)".

    python scripts/make_personal_split.py --speaker M04     # if not already done
    python scripts/torgo_to_export.py M04
    bash scripts/build_personal_model.sh m04 exports/CoHear-voice-m04-torgo.zip
    bash scripts/play_demo.sh M04
"""
import datetime
import json
import shutil
import sys
import uuid
import zipfile
from pathlib import Path

S = sys.argv[1] if len(sys.argv) > 1 else "M04"
N_DEMO = int(sys.argv[2]) if len(sys.argv) > 2 else 20
D = Path("data/personal") / S
if not (D / "train.jsonl").exists():
    sys.exit(f"{D}/train.jsonl missing — run: python scripts/make_personal_split.py --speaker {S}")

out = Path("exports")
out.mkdir(exist_ok=True)
slug = S.lower()

# ---- 1. fake app export --------------------------------------------------
stage = out / f"_stage_{slug}" / "VoiceSamples"
if stage.parent.exists():
    shutil.rmtree(stage.parent)
stage.mkdir(parents=True)

train = [json.loads(l) for l in open(D / "train.jsonl")]
now = datetime.datetime.now(datetime.timezone.utc)
lines, missing, minutes = [], 0, 0.0
for i, r in enumerate(train):
    src = Path(r["audio_path"])
    if not src.exists():
        missing += 1
        continue
    uid = str(uuid.uuid4()).upper()
    shutil.copy(src, stage / f"{uid}.wav")
    dur = float(r.get("duration_sec", 0))
    minutes += dur / 60
    lines.append(json.dumps({
        "id": uid, "file": f"{uid}.wav", "text": r["text"],
        "recordedAt": (now + datetime.timedelta(seconds=i)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "durationSec": dur,
    }))
(stage / "manifest.jsonl").write_text("\n".join(lines) + "\n")
(stage / "meta.json").write_text(json.dumps({
    "speaker": S, "count": len(lines), "minutes": round(minutes, 1),
    "sample_rate": 16000, "format": "wav pcm16 mono", "source": f"TORGO {S} (stand-in user)",
}, indent=2))

zpath = out / f"CoHear-voice-{slug}-torgo.zip"
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
    for f in stage.iterdir():
        z.write(f, f"VoiceSamples/{f.name}")
shutil.rmtree(stage.parent)
print(f"export : {zpath}  ({len(lines)} recordings, {minutes:.1f} min"
      + (f", {missing} missing audio files skipped" if missing else "") + ")")

# ---- 2. demo clips the model never trained on ------------------------------
held = []
for part in ("test_unseen", "test_seen"):
    p = D / f"{part}.jsonl"
    if p.exists():
        held += [dict(json.loads(l), _part=part) for l in open(p)]
# Sentences first (more convincing), then single words; never-taught first.
held.sort(key=lambda r: (r["n_words"] == 1, r["_part"] != "test_unseen"))
demo = out / f"{S}_demo"
if demo.exists():
    shutil.rmtree(demo)
demo.mkdir()
answers = []
for k, r in enumerate([h for h in held if Path(h["audio_path"]).exists()][:N_DEMO], 1):
    name = f"{k:02d}.wav"
    shutil.copy(r["audio_path"], demo / name)
    tag = "never taught" if r["_part"] == "test_unseen" else "new take of a taught phrase"
    answers.append(f"{k:02d}  [{tag}]  {r['text']}")
(demo / "answers.txt").write_text("\n".join(answers) + "\n")
print(f"demo   : {demo}/  ({len(answers)} held-out clips + answers.txt)")
print(f"\nnext   : bash scripts/build_personal_model.sh {slug} {zpath}")
