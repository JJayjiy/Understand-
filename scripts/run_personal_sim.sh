#!/usr/bin/env bash
# Does personalization work? Three models on the same held-out clips of one speaker:
#   stock      Whisper-small, untouched
#   general    TORGO LoRA that never heard this speaker   (models/loso_<S>/merged)
#   personal   general + fine-tuned on this speaker's teaching recordings
#
#   bash scripts/run_personal_sim.sh M04
#
# Needs models/loso_<S>/merged from run_loso.sh (you already have M04).
# Training is small (~250 clips) — minutes, not hours.
set -euo pipefail
cd "$(dirname "$0")/.."
S="${1:-M04}"
BASE="models/loso_${S}/merged"
[ -d "$BASE" ] || { echo "!! $BASE missing — run: bash scripts/run_loso.sh $S"; exit 1; }

python3 scripts/make_personal_split.py --speaker "$S"
D="data/personal/$S"
R="eval_results/personal/$S"

for T in test_seen test_unseen; do
  python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --model small \
      --tag "stock-$T" --out "$R/stock_$T"
  python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --backend transformers --model "$BASE" \
      --tag "general-$T" --out "$R/general_$T"
done

# Personal adapter on top of the general model. More epochs than the general
# run because there's far less data; LoRA keeps it from wrecking the base.
python3 scripts/finetune_lora.py --model "$BASE" --train "$D/train.jsonl" \
    --out "models/personal_$S" --epochs 10 --device cpu

for T in test_seen test_unseen; do
  python3 scripts/eval_whisper.py --manifest "$D/$T.jsonl" --backend transformers \
      --model "models/personal_$S/merged" --tag "personal-$T" --out "$R/personal_$T"
done

python3 scripts/compare_personal.py "$S"
