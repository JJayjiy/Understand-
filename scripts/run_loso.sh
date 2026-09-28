#!/usr/bin/env bash
# Honest evaluation: for each held-out dysarthric speaker, train a LoRA adapter
# on everyone else (text-disjoint), then compare it to stock Whisper on that
# speaker. See make_loso_split.py for why.
#
#   bash scripts/run_loso.sh              # M04 and F03 (one severe, one mild) — start here
#   bash scripts/run_loso.sh M04 F03 M05  # pick your own
#   bash scripts/run_loso.sh all          # all eight (long: roughly one training run each)
#
# Each training run is ~the same cost as the original general model.
set -euo pipefail
cd "$(dirname "$0")/.."

SPEAKERS=("$@")
[ ${#SPEAKERS[@]} -eq 0 ] && SPEAKERS=(M04 F03)
[ "${SPEAKERS[0]}" = "all" ] && SPEAKERS=(F01 F03 F04 M01 M02 M03 M04 M05)

python3 scripts/make_loso_split.py --speakers "${SPEAKERS[@]}"

for S in "${SPEAKERS[@]}"; do
  echo; echo "================ $S ================"
  python3 scripts/eval_whisper.py --manifest "data/torgo/loso/$S/test.jsonl" \
      --model small --tag "stock-$S" --out "eval_results/loso/stock_$S"

  python3 scripts/finetune_lora.py --train "data/torgo/loso/$S/train.jsonl" \
      --out "models/loso_$S" --epochs 3 --device cpu

  python3 scripts/eval_whisper.py --manifest "data/torgo/loso/$S/test.jsonl" \
      --backend transformers --model "models/loso_$S/merged" \
      --tag "loso-$S" --out "eval_results/loso/cohear_$S"
done

echo; echo "Done. Compare eval_results/loso/stock_<S>/summary.csv with cohear_<S>/summary.csv."
echo "Report sentence WER and single-word accuracy SEPARATELY (see eval_whisper.py header)."
