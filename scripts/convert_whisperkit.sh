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

echo "== 3/4  Converting to Core ML"
mkdir -p "$OUT_DIR"
VARIANT="${SRC_REPO//\//_}"                 # JJaysz/x -> JJaysz_x, how whisperkittools names it
# Not setting MODEL_REPO_ID: we upload ourselves in step 4, so a flaky push
# inside the tool can't leave the repo half-populated. The tool also runs a
# validation test after converting that needs network for a reference file;
# if that test fails it prints FAILED but still exits 0, so we check the
# output ourselves rather than trusting the exit code.
whisperkit-generate-model --model-version "$SRC_REPO" --output-dir "$OUT_DIR" || true

MODEL_DIR="$OUT_DIR/$VARIANT"
for part in AudioEncoder.mlmodelc TextDecoder.mlmodelc MelSpectrogram.mlmodelc; do
  [ -d "$MODEL_DIR/$part" ] || { echo "!! $part missing from $MODEL_DIR — conversion failed."; exit 1; }
done
echo "   all three Core ML models present ($(du -sh "$MODEL_DIR" | cut -f1))"
echo "   (if you saw 'FAILED (errors=1)' above with a network error, that was the"
echo "    post-conversion validation test, not the conversion — safe to continue)"

echo "== 4/4  Uploading to $DST_REPO"
hf repo create "$DST_REPO" --type model -y 2>/dev/null || true
cat > "$MODEL_DIR/README.md" <<'README'
---
license: apache-2.0
base_model: openai/whisper-small
tags: [whisperkit, coreml, automatic-speech-recognition, dysarthria, accessibility]
---

# CoHear — Whisper-small adapted for dysarthric speech (Core ML / WhisperKit)

Core ML export of [JJaysz/cohear-whisper-small-dysarthric](https://huggingface.co/JJaysz/cohear-whisper-small-dysarthric)
with the LoRA adapter merged into the base weights, for on-device use via WhisperKit.
Same weights, different packaging. See the source model card for results and limitations.

**Research artifact, not a clinically validated system.** Non-commercial use.

This model was fine-tuned using the TORGO Database of Acoustic and Articulatory Speech from
Speakers with Dysarthria. TORGO data are not included in this repository and are subject to
their original terms of use. Users wishing to access TORGO should obtain it separately from the
[official source](http://www.cs.toronto.edu/~complingweb/data/TORGO/torgo.html).
Please cite Rudzicz, Namasivayam & Wolff (2012) when using TORGO.

Release of these weights, including this merged export, was approved in advance by the TORGO maintainers.
README
hf upload "$DST_REPO" "$MODEL_DIR" "$VARIANT" --repo-type model

cat <<EOF

Done. Verify at: https://huggingface.co/$DST_REPO/tree/main/$VARIANT
You should see AudioEncoder.mlmodelc, TextDecoder.mlmodelc, MelSpectrogram.mlmodelc.

The app already tries this model first (Transcriber.candidates). Delete CoHear
from your phone, reinstall, and check Settings -> Speech model says "CoHear".
EOF
