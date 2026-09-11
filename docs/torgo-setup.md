# TORGO — what you have, and how to use it

I unpacked all four archives (F, M, FC, MC) and ran the prep script on the real data. Here's the picture.

---

## Headline: you now have a complete, usable corpus

| | utterances | minutes |
|---|---|---|
| **Total usable** | **8,039** | **391.5 (6.5 hrs)** |
| Dysarthric (8 speakers) | 3,004 | 172.7 |
| Control (7 speakers) | 5,035 | 218.8 |

Audio is **16 kHz mono WAV** — Whisper's native format, no resampling.

> These counts came from extracting **head-mic audio only** (disk limits on my end). Extracting everything on your machine recovers the ~1,037 utterances currently skipped as "no matching wav," since the script falls back to the array mic. **Treat these numbers as a floor.**

---

## The severity picture — this is the important part

Each speaker's `Notes/*.csv` holds a Frenchay-style assessment (**a** = normal → **e** = most impaired). I read the intelligibility ratings for all 8 dysarthric speakers and baked them into the script:

| Speaker | Words | Sentences | Severity | Utts | Min |
|---|---|---|---|---|---|
| **M04** | d/e | d–e | **severe** | 277 | 21.7 |
| **M01** | c/d | d–e | **severe** | 370 | 21.2 |
| **M02** | c/d | d–e | **severe** | 388 | 24.9 |
| **F01** | d | d–e | **severe** | 118 | 4.7 |
| M05 | a | c | moderate | 470 | 37.0 |
| F03 | a | a | mild | 545 | 22.5 |
| F04 | a | a | mild | 430 | 21.0 |
| M03 | a | a | mild | 406 | 19.6 |

**This fixes the problem from the female-only set.** Before, your only severe speaker was F01 with 4.7 minutes. Now you have **four severe speakers and 72.6 minutes of severe dysarthric speech** — three of them (M01, M02, M04) with 21–25 minutes each, which is enough for real per-speaker adaptation.

**M04 is your demo speaker.** Most impaired on the scale (d/e), with 21.7 minutes of audio. That's where stock Whisper will fail hardest and where your improvement will look most dramatic.

Also note: F01's notes say *"difficult making /t/ sound → tip of tongue won't go to roof of mouth."* That's a documented phoneme-level deficit your friend can predict from the clinical note and verify against Allosaurus. Clinical prediction confirmed by data is a genuinely strong result.

---

## The experiment that makes your pitch

You now have **matched controls** — same prompts, same mics, same room, only the speaker differs. That enables a controlled comparison instead of an anecdote:

1. **Show the gap.** Stock Whisper on control test set vs. dysarthric test set.
   > "Stock Whisper gets X% WER on control speakers and Y% on dysarthric speakers reading the same prompts on the same equipment."
2. **Close the gap.** Fine-tune on dysarthric train, re-measure both.
   > "We cut the dysarthric WER to Z%, closing N% of the gap."
3. **Go further per speaker.** Adapt to M04 alone, measure M04 before/after.
   > "On the most severely dysarthric speaker, WER fell from A% to B%."

That three-step story — gap, closure, personalization — is a much stronger slide than any single number.

---

## Run it

```bash
mkdir -p ~/torgo
for f in F M FC MC; do tar -xjf $f.tar.bz2 -C ~/torgo; done
python scripts/torgo_prep.py --root ~/torgo --out data/torgo
```

Each record:

```json
{"audio_path": "...", "text": "beta", "speaker": "F01", "group": "dysarthric",
 "severity": "severe", "session": "Session1", "utt_id": "F01_Session1_0050",
 "mic": "headMic", "duration_sec": 1.934, "n_words": 1}
```

Useful variants:

```bash
# Controls only — for the baseline comparison
python scripts/torgo_prep.py --root ~/torgo --out data/torgo_control --group control

# Severe dysarthric sentences only — 266 utts / 36.5 min across F01, M01, M02, M04
python scripts/torgo_prep.py --root ~/torgo --out data/torgo_severe --severity severe --min-words 2

# Speaker-independent split (hardest, most rigorous)
python scripts/torgo_prep.py --root ~/torgo --out data/torgo_si --group dysarthric --split speaker --holdout-speaker M04
```

Split modes: `--split random` (15% per speaker — best for per-speaker adaptation), `--split speaker` (holds out a whole speaker), `--split session` (holds out each speaker's last session). The script asserts no utterance lands in both splits.

---

## What the script throws away, and why

386 prompts aren't transcripts at all — instructions like `[relax your mouth in its normal position]`, image references like `input/images/story_starters_17.jpg`, and `xxx` markers. **Training on these teaches the model to hallucinate.** All filtered automatically, and the counts are printed so you can see what went.

---

## The single-word caveat (still applies)

**6,023 of 8,039 utterances are one word.** Two consequences:

1. Weak training signal — isolated words teach little about connected speech, where dysarthria actually breaks intelligibility.
2. WER gets noisy and inflated — one error on a one-word clip is 100% WER, and averages get dominated by them.

**Report two numbers, never blended:** sentence WER (on the 2,016 multi-word utterances) and single-word accuracy. Judges with an ML background will ask; having it split makes you look rigorous.

---

## Honest expectations

- **6.5 hours total, 2.9 hours dysarthric** is comfortably past the point where published work sees real gains (~1.4 hrs). You have enough. Start training.
- **8 dysarthric speakers is still small** for broad generalization claims. Say "adapted to these speakers," not "generalizes to all dysarthric speech."
- **Diminishing returns are real** — going from ~1.4h to ~22h of adaptation data bought about 5 WER points in published work. Don't wait for more data; spend the time on per-speaker adaptation instead.
- Start with `whisper-small` + LoRA. Prove the pipeline end to end before scaling the model.

---

## Next steps

1. Run the prep script; check `summary.csv`.
2. **Baseline stock Whisper** on the test sets — per speaker, per group, sentence WER and single-word accuracy separately. This is your "before," and the control-vs-dysarthric gap is your motivating number.
3. LoRA fine-tune on dysarthric train; re-measure identically.
4. Per-speaker adaptation on **M04**; that's your headline.
5. Keep collecting FCSN clips — TORGO gives you a credible general model, but your own speakers are the moat.
