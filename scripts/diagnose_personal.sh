#!/usr/bin/env bash
# Why does "Your voice (M04)" output junk on the phone?
# Feeds the SAME clean demo clips (no speaker, no mic) to:
#   A. the trained personal model in Python     (models/user_m04_final/merged)
#   B. the converted phone model (Core ML)      (models/whisperkit_personal/user_m04/PersonalModel)
#   C. the converted CoHear model (Core ML)     (models/whisperkit/..., if present) for comparison
#
#   bash scripts/diagnose_personal.sh            # first 6 demo clips
#
# Reading the result:
#   A good, B good  -> conversion is fine; the junk came from speaker->mic audio
#                      (model too specialised to clean head-mic audio)
#   A good, B junk  -> the Core ML conversion / loading is broken
#   A junk          -> the trained model itself is bad
set -uo pipefail
cd "$(dirname "$0")/.."
N="${1:-6}"
DEMO="exports/M04_demo"
PY_MODEL="models/user_m04_final/merged"
CM_PERSONAL="models/whisperkit_personal/user_m04/PersonalModel"
CM_COHEAR="$(ls -d models/whisperkit/*cohear* 2>/dev/null | head -1)"

[ -d "$DEMO" ] || { echo "!! $DEMO missing — run: python3 scripts/torgo_to_export.py M04"; exit 1; }
if ! command -v whisperkit-cli >/dev/null; then
  echo "Installing whisperkit-cli (one time)..."
  brew install whisperkit-cli || { echo "!! brew install whisperkit-cli failed"; exit 1; }
fi

# A: Python, all clips at once
python3 - "$PY_MODEL" "$DEMO" "$N" > /tmp/cohear_py.txt 2>/dev/null <<'PY'
import sys, torch, soundfile as sf
from transformers import WhisperProcessor, WhisperForConditionalGeneration
from transformers.utils import logging; logging.set_verbosity_error()
m, d, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
proc = WhisperProcessor.from_pretrained(m); model = WhisperForConditionalGeneration.from_pretrained(m).eval()
forced = proc.get_decoder_prompt_ids(language="english", task="transcribe")
for k in range(1, n + 1):
    a, sr = sf.read(f"{d}/{k:02d}.wav", dtype="float32")
    f = proc.feature_extractor(a, sampling_rate=16000, return_tensors="pt").input_features
    with torch.no_grad():
        ids = model.generate(f, forced_decoder_ids=forced, max_new_tokens=120, no_repeat_ngram_size=3)
    print(proc.batch_decode(ids, skip_special_tokens=True)[0].strip())
PY

cm() { whisperkit-cli transcribe --model-path "$1" --audio-path "$2" --language en 2>/dev/null | tail -1; }

k=0
while IFS= read -r line && [ "$k" -lt "$N" ]; do
  k=$((k+1)); n="${line%% *}"
  echo "──────── clip $n"
  echo "  truth        : ${line#*]  }"
  echo "  A python     : $(sed -n "${k}p" /tmp/cohear_py.txt)"
  echo "  B phone model: $(cm "$CM_PERSONAL" "$DEMO/$n.wav")"
  [ -n "$CM_COHEAR" ] && echo "  C CoHear     : $(cm "$CM_COHEAR" "$DEMO/$n.wav")"
done < "$DEMO/answers.txt"
