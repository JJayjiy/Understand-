# Quickstart — TORGO to a working model

Five commands. Each one produces something you can put in a pitch.

```bash
pip install -r requirements.txt
pip install transformers peft accelerate torch soundfile librosa jiwer faster-whisper
```

---

## 1. Prepare the data

```bash
mkdir -p ~/torgo
for f in F M FC MC; do tar -xjf $f.tar.bz2 -C ~/torgo; done
python scripts/torgo_prep.py --root ~/torgo --out data/torgo
```

Filters out the ~386 prompts that aren't transcripts (instructions, image references), pairs each prompt with its audio, tags every utterance with `group` (dysarthric/control) and `severity`, and splits train/test with a no-leak assertion.

**Expect:** ~8,000 utterances, ~6.5 hours. Check `data/torgo/summary.csv`.

---

## 2. Baseline — the number you're beating

```bash
# smoke test first (~1 min)
python scripts/eval_whisper.py --manifest data/torgo/test.jsonl --model tiny --limit 30

# the real baseline
python scripts/eval_whisper.py --manifest data/torgo/test.jsonl --model small --tag stock
```

Prints sentence WER and word accuracy broken down by group, severity, and speaker — plus the control-vs-dysarthric gap, stated as a sentence you can quote.

**Save this output.** It's your "before."

---

## 3. Train

```bash
# verify the pipeline runs (20 clips, ~2 min)
python scripts/finetune_lora.py --train data/torgo/train.jsonl --model openai/whisper-tiny --smoke-test

# general dysarthric model
python scripts/finetune_lora.py --train data/torgo/train.jsonl \
    --model openai/whisper-small --group dysarthric \
    --out models/torgo_general --epochs 3

# per-speaker adaptation on the most severely affected speaker — this is the moat
python scripts/finetune_lora.py --train data/torgo/train.jsonl --speaker M04 \
    --out models/m04 --epochs 8
```

Trains LoRA adapters (<1% of parameters) and saves both `adapter/` and `merged/`.

**Always run `--smoke-test` first.** Two minutes to catch a bug beats forty minutes of training into a crash.

On a free Colab T4, add `--int8` and `--batch-size 16`.

---

## 4. Measure again — identical command, new model

```bash
python scripts/eval_whisper.py --manifest data/torgo/test.jsonl \
    --backend transformers --model models/torgo_general/merged --tag lora-general

python scripts/eval_whisper.py --manifest data/torgo/test.jsonl \
    --backend transformers --model models/m04/merged --tag lora-m04
```

Three summary CSVs — `stock`, `lora-general`, `lora-m04` — side by side are your result.

---

## 5. Use it in the app

Point `FINETUNED_DIR` at the top of `app.py` at your merged model, then:

```bash
streamlit run app.py
```

Pick **"Our fine-tuned model"** in the sidebar. Same clip through all three engines — OpenAI API, stock local Whisper, and yours — is the demo.

---

## The story this produces

1. **The gap** — stock Whisper on controls vs. dysarthric speakers, same prompts, same mics.
2. **Closing it** — general fine-tune, same test set.
3. **Going further** — per-speaker adaptation on M04, the most severely affected speaker.

Three bars on one chart. That's the slide.

---

## Rules that keep the numbers honest

- **Never train on the test set.** `torgo_prep.py` asserts it; don't work around it.
- **Report sentence WER and single-word accuracy separately.** TORGO is ~75% single words, and one error on a one-word clip is 100% WER — blending them produces a meaningless average.
- **Same test set, same command, every run.** Only the model changes.
- **Say "adapted to these speakers," not "generalizes to dysarthric speech."** Eight speakers isn't a population.
