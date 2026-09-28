#!/usr/bin/env bash
# Overnight personalization study. Two questions:
#
#  A. REPLICATION — does personalization work beyond M04?
#     For M01 (severe), M05 (moderate), F03 (mild): stock Whisper vs a personal
#     adapter trained on stock Whisper + that speaker's teaching clips.
#     Also runs the same "personal from stock" on M04, which tells us whether
#     starting from the TORGO general model matters at all.
#
#  B. LEARNING CURVE — how many recordings does the app need to ask for?
#     M04, personal adapter from the general model, trained on 25 / 50 / 100
#     clips (192 was already run).
#
#   caffeinate -i bash scripts/run_personal_study.sh 2>&1 | tee eval_results/personal_study.log
#
# Safe to re-run: finished steps are skipped. Ctrl+C anytime and re-run later.
set -euo pipefail
cd "$(dirname "$0")/.."

SPEAKERS=(${SPEAKERS:-M01 M05 F03})
EPOCHS=10
# 3e-4, not the 1e-3 used for the 4,000-clip general model: at 1e-3 on ~250 clips
# M01 and M05 diverged (loss 0.2 -> 16, model output went empty).
LR=${LR:-3e-4}

done_eval() { ls "$1"/summary_*.csv >/dev/null 2>&1; }

evaluate() {   # evaluate <speaker> <name> <model> <backend>
  local S=$1 NAME=$2 MODEL=$3 BACKEND=$4
  for T in test_seen test_unseen; do
    local OUT="eval_results/personal/$S/${NAME}_$T"
    if done_eval "$OUT"; then echo "  skip $NAME $T (done)"; continue; fi
    if [ "$BACKEND" = stock ]; then
      python3 scripts/eval_whisper.py --manifest "data/personal/$S/$T.jsonl" --model small \
          --tag "$NAME-$T" --out "$OUT"
    else
      python3 scripts/eval_whisper.py --manifest "data/personal/$S/$T.jsonl" --backend transformers \
          --model "$MODEL" --tag "$NAME-$T" --out "$OUT"
    fi
  done
}

train() {      # train <base> <train.jsonl> <out>
  if [ -d "$3/merged" ]; then echo "  skip training $3 (done)"; return; fi
  python3 scripts/finetune_lora.py --model "$1" --train "$2" --out "$3" --epochs "$EPOCHS" --lr "$LR" --device cpu
}

echo "================ A. REPLICATION ================"
for S in "${SPEAKERS[@]}" M04; do
  echo; echo "---------- $S ----------"
  python3 scripts/make_personal_split.py --speaker "$S"
  evaluate "$S" stock small stock
  train openai/whisper-small "data/personal/$S/train.jsonl" "models/personalstock_$S"
  evaluate "$S" personalstock "models/personalstock_$S/merged" hf
done

echo; echo "================ B. LEARNING CURVE (M04) ================"
S=M04
BASE="models/loso_${S}/merged"
if [ -d "$BASE" ]; then
  for N in 25 50 100; do
    SUB="data/personal/$S/train_$N.jsonl"
    python3 - "$S" "$N" <<'PY'
import json, random, sys
S, N = sys.argv[1], int(sys.argv[2])
rows = [json.loads(l) for l in open(f"data/personal/{S}/train.jsonl")]
random.Random(13).shuffle(rows)
with open(f"data/personal/{S}/train_{N}.jsonl", "w") as f:
    for r in rows[:N]:
        f.write(json.dumps(r) + "\n")
mins = sum(r.get("duration_sec", 0) for r in rows[:N]) / 60
print(f"  train_{N}: {N} clips, {mins:.1f} min")
PY
    train "$BASE" "$SUB" "models/personal${N}_$S"
    evaluate "$S" "personal$N" "models/personal${N}_$S/merged" hf
  done
else
  echo "  $BASE missing — skipping learning curve"
fi

echo; echo "================ RESULTS ================"
python3 scripts/compare_personal.py M04 "${SPEAKERS[@]}"
