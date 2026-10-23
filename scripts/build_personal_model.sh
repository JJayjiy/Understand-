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
SKIP_EVAL=0; KEEP_REMOTE=0; EVAL_ONLY=0
for a in "$@"; do
  case "$a" in
    --skip-eval) SKIP_EVAL=1 ;;
    --keep-remote) KEEP_REMOTE=1 ;;
    # Fastest route to the phone: build with --skip-eval first (final model +
    # convert only), install it, then run again later with --eval-only to get
    # the before/after numbers. Each half takes about the same time.
    --eval-only) EVAL_ONLY=1 ;;
  esac
done
# "user_" prefix keeps real users apart from the TORGO study folders. macOS paths
# are case-insensitive, so a bare "m04" would silently overwrite the study's "M04".
SLUG="user_$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
LR=3e-4
# Training device. cpu on a Mac (MPS leaks memory on long runs). On an NVIDIA
# machine (e.g. a DGX Spark) run with DEVICE=cuda: same recipe, minutes not an hour.
DEVICE="${DEVICE:-cpu}"
D="data/personal/$SLUG"

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
if mins < 1:
    print("  !! under a minute of speech — expect a weak model. The 5 quick-start passages are ~1-2 min.")
open(f"{d}/count.txt", "w").write(str(n))
open(f"{d}/language.txt", "w").write(rows[0].get("language", "en") if rows else "en")
PY
N=$(cat "$D/count.txt")
LANG_CODE=$(cat "$D/language.txt")   # en or zh, from the app's export
echo "  language: $LANG_CODE"
# Separate model folders per language, so a Chinese model never reuses an
# English one built for the same person (and vice versa).
MSLUG="$SLUG"; [ "$LANG_CODE" = "zh" ] && MSLUG="${SLUG}_zh"
R="eval_results/personal/$MSLUG"   # per language, so English results never overwrite Chinese ones
# Tiny sets (quick start = 5 clips) give one optimizer step per epoch, so scale
# epochs to reach ~60+ steps. LoRA's low rank and the divergence guard keep it
# from simply memorizing.
EPOCHS=$(python3 -c "import math; n=$N; print(max(10, min(80, math.ceil(60*16/max(n,1)))))")
echo "  training for $EPOCHS epochs on $N recordings"
# The held-out measurement needs enough clips to split; skip it for small sets.
[ "$N" -lt 30 ] && SKIP_EVAL=1 && echo "  (fewer than 30 recordings: skipping the before/after measurement)"
if [ "$EVAL_ONLY" = 1 ] && [ "$SKIP_EVAL" = 1 ]; then
  echo "!! --eval-only needs 30+ recordings to hold some back for testing."; exit 1
fi

if [ "$SKIP_EVAL" = 0 ]; then
  echo "== 2/4  Measure (stock vs personal, on held-out recordings)"
  for T in test_seen test_unseen; do
    [ -s "$D/$T.jsonl" ] || continue
    python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --model small --guard --language "$LANG_CODE" \
        --tag "stock-$T" --out "$R/stock_$T"
  done
  [ -d "models/${MSLUG}_measure/merged" ] || \
    python3 scripts/finetune_lora.py --model openai/whisper-small --train "$D/train.jsonl" \
        --out "models/${MSLUG}_measure" --epochs "$EPOCHS" --lr "$LR" --augment --language "$LANG_CODE" --device "$DEVICE"
  for T in test_seen test_unseen; do
    [ -s "$D/$T.jsonl" ] || continue
    python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --backend transformers --guard --language "$LANG_CODE" \
        --model "models/${MSLUG}_measure/merged" --tag "personalstock-$T" --out "$R/personalstock_$T"
  done
  python3 scripts/compare_personal.py "$MSLUG" | tee "$R/RESULTS.txt"
else
  echo "== 2/4  Measure: skipped"
fi
if [ "$EVAL_ONLY" = 1 ]; then
  echo "Done (--eval-only). Results: $R/RESULTS.txt"
  exit 0
fi

echo "== 3/4  Final model on all recordings"
FINAL="models/${MSLUG}_final"
[ -d "$FINAL" ] && [ ! -d "$FINAL/merged" ] && { echo "  previous final run was interrupted; starting it over"; rm -rf "$FINAL"; }
[ -d "$FINAL/merged" ] || \
  python3 scripts/finetune_lora.py --model openai/whisper-small --train "$D/all.jsonl" \
      --out "$FINAL" --epochs "$EPOCHS" --lr "$LR" --augment --language "$LANG_CODE" --device "$DEVICE"

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
REPO="$HF_USER/cohear-personal-$MSLUG"
hf repo create "$REPO" --type model --private -y 2>/dev/null || true
hf upload "$REPO" "$FINAL/merged" . --repo-type model
OUT="models/whisperkit_personal/$MSLUG"
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
python3 - "$PKG" "$NAME" "$D/all.jsonl" "$LANG_CODE" <<'PY'
import json, sys, datetime
pkg, name, allf, lang = sys.argv[1:]
rows = [json.loads(l) for l in open(allf)]
json.dump({"name": name, "clips": len(rows), "language": lang,
           "minutes": round(sum(r["duration_sec"] for r in rows) / 60, 1),
           "built": datetime.date.today().isoformat(),
           "recipe": "openai/whisper-small + LoRA r32 lr3e-4 + audio augmentation"},
          open(f"{pkg}/personal.json", "w"), indent=2, ensure_ascii=False)
PY
if [ "$KEEP_REMOTE" = 0 ]; then
  python3 -c "import sys; from huggingface_hub import delete_repo; delete_repo(sys.argv[1], repo_type='model')" "$REPO" 2>/dev/null \
    && echo "  deleted private repo $REPO" \
    || echo "  !! couldn't auto-delete $REPO — delete it at https://huggingface.co/$REPO/settings"
fi

# Zip for remote testers: they save it to Files, tap to unzip, then use
# Teach CoHear your voice -> "Install personal model" in the app.
ZIP="$OUT/PersonalModel-$MSLUG.zip"
rm -f "$ZIP"; (cd "$OUT" && zip -qry "$(basename "$ZIP")" PersonalModel)

cat <<EOF

Done. Personal model for $NAME: $PKG  ($(du -sh "$PKG" | cut -f1))
Zip for remote testers: $ZIP  ($(du -sh "$ZIP" | cut -f1)) — share via Google Drive or iCloud link (too big for email).
  On their iPhone: open the link -> Save to Files -> tap the zip to unzip ->
  CoHear -> Settings -> Teach CoHear your voice -> Install personal model -> pick "PersonalModel".

Put it on the phone:
  1. Plug the iPhone into this Mac, open Finder, click the iPhone in the sidebar.
  2. Files tab -> expand CoHear.
  3. Drag the folder  $PKG  onto CoHear. (It must be named "PersonalModel".)
  4. On the phone: CoHear -> Settings -> Speech model -> "Your voice ($NAME)".
EOF
