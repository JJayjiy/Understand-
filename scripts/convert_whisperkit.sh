#!/usr/bin/env bash
# Convert the CoHear fine-tuned Whisper to WhisperKit (Core ML) format and
# publish it to Hugging Face, so the iOS app can download it on first launch.
#
# Run this ON YOUR MAC. It needs Xcode's coremlcompiler and a Hugging Face
# write token (you already have one from `hf login`).
#
# What it does:
#   1. Pushes models/general/merged (base + LoRA merged) to HF as a full model repo.
#      whisperkittools converts from a HF *model repo*, not a local folder.
#   2. Runs whisperkit-generate-model, which converts to Core ML and publishes
#      to JJaysz/cohear-whisperkit under the variant name
#      "JJaysz_cohear-whisper-small-merged" (source repo with "/" -> "_").
#
# After this succeeds, flip `Transcriber.spec` in the iOS app to `.cohear`.
#
# Takes 15-40 minutes. Needs ~5 GB free disk.

set -euo pipefail

MERGED_DIR="models/general/merged"
SRC_REPO="JJaysz/cohear-whisper-small-merged"      # full PyTorch model, published in step 1
DST_REPO="JJaysz/cohear-whisperkit"                # Core ML output, read by the app
OUT_DIR="models/whisperkit"

cd "$(dirname "$0")/.."

[ -d "$MERGED_DIR" ] || { echo "!! $MERGED_DIR not found. Run scripts/merge_checkpoint.py first."; exit 1; }
command -v xcrun >/dev/null || { echo "!! Xcode command line tools not found."; exit 1; }
xcrun --find coremlcompiler >/dev/null 2>&1 || {
  echo "!! coremlcompiler not found. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"; exit 1; }

echo "== 1/3  Publishing merged PyTorch model to $SRC_REPO"
hf repo create "$SRC_REPO" --type model -y 2>/dev/null || true
hf upload "$SRC_REPO" "$MERGED_DIR" . --repo-type model

echo "== 2/3  Installing whisperkittools (one-time)"
if ! command -v whisperkit-generate-model >/dev/null; then
  python3 -m venv .venv-wkt
  # shellcheck disable=SC1091
  source .venv-wkt/bin/activate
  pip install -q --upgrade pip
  pip install -q "git+https://github.com/argmaxinc/whisperkittools.git"
else
  # shellcheck disable=SC1091
  [ -f .venv-wkt/bin/activate ] && source .venv-wkt/bin/activate
fi

echo "== 3/3  Converting to Core ML and publishing to $DST_REPO"
hf repo create "$DST_REPO" --type model -y 2>/dev/null || true
mkdir -p "$OUT_DIR"
MODEL_REPO_ID="$DST_REPO" whisperkit-generate-model \
  --model-version "$SRC_REPO" \
  --output-dir "$OUT_DIR"

cat <<EOF

Done. The app can now load it with:

  WhisperKit.download(variant: "JJaysz_cohear-whisper-small-merged",
                      from:    "JJaysz/cohear-whisperkit")

Set  Transcriber.spec = .cohear  in ios/CoHear/Services/Transcriber.swift

Add this to the README of $DST_REPO (same TORGO wording Frank required):
  This model was fine-tuned using the TORGO Database ... TORGO data are not
  included ... Please cite Rudzicz, Namasivayam & Wolff (2012). Non-commercial.
EOF
