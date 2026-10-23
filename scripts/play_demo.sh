#!/usr/bin/env bash
# Play held-out TORGO clips out loud, one at a time, next to the phone.
# Put the iPhone ~30 cm from the Mac speaker, tap Listen in CoHear, then run:
#
#   bash scripts/play_demo.sh M04          # plays all, pausing for Enter between clips
#   bash scripts/play_demo.sh M04 auto     # plays all with a 4 s gap (for screen recording)
#
# The answer is printed AFTER each clip so you can judge the phone first.
# Run it twice: once with Speech model = CoHear, once with Your voice (M04).
set -euo pipefail
cd "$(dirname "$0")/.."
S="${1:-M04}"; MODE="${2:-step}"
DIR="exports/${S}_demo"
[ -d "$DIR" ] || { echo "!! $DIR missing — run: python3 scripts/torgo_to_export.py $S"; exit 1; }
command -v afplay >/dev/null || { echo "!! afplay not found (this script is for macOS)"; exit 1; }

while IFS= read -r line; do
  n="${line%% *}"
  echo; echo "▶ clip $n"
  afplay -v 1.0 "$DIR/$n.wav"
  echo "   answer: ${line#*  }"
  if [ "$MODE" = auto ]; then sleep 4; else read -r -p "   (Enter for next) " _ </dev/tty; fi
done < "$DIR/answers.txt"
echo; echo "Done."
