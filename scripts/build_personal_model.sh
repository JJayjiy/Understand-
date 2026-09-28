#!/usr/bin/env bash
# Build a personal CoHear model from recordings exported by the app
# ("Teach CoHear your voice" -> Export -> AirDrop to this Mac).
#
#   bash scripts/build_personal_model.sh <name> <export.zip>
#   bash scripts/build_personal_model.sh alex ~/Downloads/CoHear-voice-alex-2026-09-28.zip
#
# Steps
#   1. split     held-out takes + never-recorded phrases, so we can measure honestly
#   2. measure   stock Whisper vs a personal model trained on the split  (--skip-eval to skip)
#   3. final     personal model trained on ALL recordings (nothing held back from the user)
#   4. convert   to WhisperKit / Core ML, ready to copy onto the phone
#
# Recipe = what the TORGO study validated on 4 speakers:
#   stock openai/whisper-small + LoRA r=32, lr 3e-4, 10 epochs, divergence guard.
#
# PRIVACY: recordings and the model stay on this Mac. The ONE exception is step 4:
# whisperkittools converts from a Hugging Face repo, so the merged model is pushed
# to a PRIVATE repo, converted, and the repo is deleted afterwards. Only do this
# with the person's consent (consent_form.md). Pass --keep-remote to keep it.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?usage: build_personal_model.sh <name> <export.zip> [--skip-eval] [--keep-remote]}"
EXPORT="${2:?usage: build_personal_model.sh <name> <export.zip>}"
shift 2
SKIP_EVAL=0; KEEP_REMOTE=0
for a in "$@"; do
  case "$a" in --skip-eval) SKIP_EVAL=1 ;; --keep-remote) KEEP_REMOTE=1 ;; esac
done
SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
LR=3e-4; EPOCHS=10
D="data/personal/$SLUG"
R="eval_results/personal/$SLUG"

echo "== 1/4  Split"
python3 scripts/make_personal_split.py --speaker "$SLUG" --export "$EXPORT"
python3 - "$D" <<'PY'
import json, sys
d = sys.argv[1]
rows = [json.loads(l) for p in ("train", "test_seen", "test_unseen") for l in open(f"{d}/{p}.jsonl")]
with open(f"{d}/all.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
n, mins = len(rows), sum(r["duration_sec"] for r in rows) / 60
print(f"  all.jsonl: {n} recordings, {mins:.1f} min")
if n < 60:
    print("  !! fewer than 60 recordings — expect a weak model. ~100+ is a good first batch.")
PY

if [ "$SKIP_EVAL" = 0 ]; then
  echo "== 2/4  Measure (stock vs personal, on held-out recordings)"
  for T in test_seen test_unseen; do
    [ -s "$D/$T.jsonl" ] || continue
    python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --model small --guard \
        --tag "stock-$T" --out "$R/stock_$T"
  done
  [ -d "models/personalstock_$SLUG/merged" ] || \
    python3 scripts/finetune_lora.py --model openai/whisper-small --train "$D/train.jsonl" \
        --out "models/personalstock_$SLUG" --epochs "$EPOCHS" --lr "$LR" --device cpu
  for T in test_seen test_unseen; do
    [ -s "$D/$T.jsonl" ] || continue
    python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --backend transformers --guard \
        --model "models/personalstock_$SLUG/merged" --tag "personalstock-$T" --out "$R/personalstock_$T"
  done
  python3 scripts/compare_personal.py "$SLUG" | tee "$R/RESULTS.txt"
else
  echo "== 2/4  Measure: skipped"
fi

echo "== 3/4  Final model on all recordings"
FINAL="models/personal_final_$SLUG"
[ -d "$FINAL/merged" ] || \
  python3 scripts/finetune_lora.py --model openai/whisper-small --train "$D/all.jsonl" \
      --out "$FINAL" --epochs "$EPOCHS" --lr "$LR" --device cpu

echo "== 4/4  Convert to WhisperKit (Core ML)"
command -v xcrun >/dev/null && xcrun --find coremlcompiler >/dev/null 2>&1 || {
  echo "!! Xcode's coremlcompiler not found. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"; exit 1; }
if ! command -v whisperkit-generate-model >/dev/null; then
  [ -f .venv-wkt/bin/activate ] || { python3 -m venv .venv-wkt; .venv-wkt/bin/pip install -q "git+https://github.com/argmaxinc/whisperkittools.git"; }
  # shellcheck disable=SC1091
  source .venv-wkt/bin/activate
fi
HF_USER=$(hf auth whoami 2>/dev/null | head -1 | awk '{print $NF}')
HF_USER=${HF_USER:-JJaysz}
REPO="$HF_USER/cohear-personal-$SLUG"
hf repo create "$REPO" --type model --private -y 2>/dev/null || true
hf upload "$REPO" "$FINAL/merged" . --repo-type model
OUT="models/whisperkit_personal/$SLUG"
mkdir -p "$OUT"
whisperkit-generate-model --model-version "$REPO" --output-dir "$OUT" || true   # validation step may fail offline; checked below
VARIANT_DIR="$OUT/${REPO//\//_}"
for part in AudioEncoder.mlmodelc TextDecoder.mlmodelc MelSpectrogram.mlmodelc; do
  [ -d "$VARIANT_DIR/$part" ] || { echo "!! $part missing — conversion failed. See output above."; exit 1; }
done
PKG="$OUT/PersonalModel"
rm -rf "$PKG"; mkdir -p "$PKG"
cp -R "$VARIANT_DIR"/*.mlmodelc "$PKG"/
cp "$FINAL/merged"/tokenizer*.json "$PKG"/ 2>/dev/null || true
python3 - "$PKG" "$NAME" "$D/all.jsonl" <<'PY'
import json, sys, datetime
pkg, name, allf = sys.argv[1:]
rows = [json.loads(l) for l in open(allf)]
json.dump({"name": name, "clips": len(rows),
           "minutes": round(sum(r["duration_sec"] for r in rows) / 60, 1),
           "built": datetime.date.today().isoformat(),
           "recipe": "openai/whisper-small + LoRA r32 lr3e-4 10ep"},
          open(f"{pkg}/personal.json", "w"), indent=2)
PY
if [ "$KEEP_REMOTE" = 0 ]; then
  hf repo delete "$REPO" --repo-type model -y 2>/dev/null \
    && echo "  deleted private repo $REPO" \
    || echo "  !! couldn't auto-delete $REPO — delete it at https://huggingface.co/$REPO/settings"
fi

cat <<EOF

Done. Personal model for $NAME: $PKG  ($(du -sh "$PKG" | cut -f1))

Put it on the phone:
  1. Plug the iPhone into this Mac, open Finder, click the iPhone in the sidebar.
  2. Files tab -> expand CoHear.
  3. Drag the folder  $PKG  onto CoHear. (It must be named "PersonalModel".)
  4. On the phone: CoHear -> Settings -> Speech model -> "Your voice ($NAME)".
EOF
