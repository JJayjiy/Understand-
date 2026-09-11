# Data Collection & Fine-Tuning Plan

**Goal:** get a real, defensible WER drop on hard-to-understand speech — without mass data, without buying compute, inside 12 weeks.

---

## The core insight: small and targeted beats big and general

Published work adapting ASR to dysarthric speech found:

| Adaptation data | WER |
|---|---|
| 1.4 hours | 15.8% |
| 22.5 hours | 10.7% |
| All data combined | 9.7% |

A **16× increase in data bought ~5 points**, and everything past that bought half a point. The curve flattens fast.

**What this means for you:** don't chase volume. The first 1–2 hours of *well-matched* audio does most of the work. Your effort belongs in **per-speaker adaptation** — a model tuned to one specific person — not in scraping hundreds of hours.

That's also the only version that's a moat. Anyone can fine-tune on TORGO. Nobody else has your FCSN student's voice.

---

## Two data streams (you need both, for different reasons)

### Stream A — Public datasets (your baseline model)

Use these to make a *generally* better-at-atypical-speech model before any user data exists.

| Dataset | What it is | Access |
|---|---|---|
| **Speech Accessibility Project** (UIUC) | ~415 hrs, 524 participants — Parkinson's, Down syndrome, ALS, cerebral palsy, stroke. Funded by Amazon/Apple/Google/Meta/Microsoft. The big one. | Application + data use agreement — **apply this week**, approval lag is the bottleneck |
| **TORGO** | Dysarthric speech, small, well-known | Easier — request from source |
| **UASpeech** | Dysarthric, ~100 hrs, 19 speakers | Request form |
| **SEP-28k** (Apple) + **FluencyBank** | Stuttering events | Public |
| **Common Voice** (Mozilla) | Huge, many accents | Fully open |
| **L2-ARCTIC** | Accented English | Public |

> **Do today:** submit the Speech Accessibility Project request. Start training on TORGO/UASpeech/Common Voice while it processes.

### Stream B — Your own clips (your moat)

Collected through FCSN + outreach, with consent. Small on purpose — 20–40 minutes per speaker is enough to adapt.

**What makes a clip usable for training:**

- **Paired audio + exact ground-truth transcript.** Audio without a verified transcript is nearly worthless for fine-tuning. This is the single most common mistake.
- **Consistent recording setup** — same device, same room if possible. Varying mic/noise adds noise the model has to fight.
- **Clip length 3–15 seconds.** Whisper trains on ≤30s windows; short utterances are easier to label accurately.
- **Speaker code, never a name** (S01, S02…). Privacy and it keeps your dataset clean.
- **Natural speech, not just word lists.** Have them say real things they'd actually say — asking for directions, making a request.

**Target per speaker:** 100–200 clips ≈ 20–40 min. That's 2–3 sessions. Do this for 3–5 speakers.

**Consent is not optional.** Signed form (parental for minors) before any recording, logged in the Users tab of your tracker.

---

## The efficient way to train: LoRA / PEFT

Don't retrain Whisper's weights. Freeze the model and inject small trainable rank-decomposition matrices into each layer — you train **well under 1% of the parameters**, match or beat full fine-tuning quality, and it fits in **free Colab T4 (16GB)** memory with int8.

**Reference implementations:**

- Hugging Face PEFT Whisper Colab notebook (`peft_bnb_whisper_large_v2_training.ipynb`)
- `Vaibhavs10/fast-whisper-finetuning`

**Compute (all free):**

- Google Colab — free T4
- Kaggle — ~30 GPU hrs/week

**Model size:** start with `whisper-small`. It trains fast, and if the pipeline works you scale to `medium`/`large-v2`. Don't start at large — you'll spend your time debugging OOM errors instead of learning whether your data is any good.

---

## Multiplying small data (augmentation)

When you only have 20 real minutes from a person:

- **Speed / pitch / tempo perturbation** — standard, cheap, effective. Turns 1 clip into 3–5.
- **Noise + room simulation** — makes the model robust to real environments (and to your hero device's mic).
- **Synthetic dysarthric speech from TTS** — recent research generates controllable synthetic atypical speech for personalized fine-tuning. Legitimate way to manufacture volume.

Augmentation is *not* a substitute for real data — it's a multiplier on it.

---

## Training recipe (the actual sequence)

1. **Baseline.** Run stock `whisper-small` on a held-out test set. Record WER. This is the number you beat.
2. **General adaptation.** LoRA fine-tune on public atypical-speech data. Re-measure. Expect a solid drop.
3. **Per-speaker adaptation.** Take the model from step 2, LoRA-tune again on ONE speaker's 20–40 min. Re-measure *for that speaker*. Expect the biggest drop here — this is your demo.
4. **Ablation for the writeup.** Report all three numbers: stock → general → personalized. A three-bar chart is your single best slide.

**Always hold out a test set** (~15–20% of clips, never trained on). If you evaluate on data you trained on, your numbers are fake and any judge with an ML background will catch it.

---

## Success targets

| Milestone | Target |
|---|---|
| Stock Whisper baseline on your clips | (measure it — likely 30–50% WER) |
| After general fine-tune | ≥25% relative reduction |
| After per-speaker adaptation | ≥50% relative reduction for that speaker |
| Clips collected | 100–200 per speaker, 3–5 speakers |
| Test set | Held out, never trained on |

---

## Timeline fit

- **Week 1–2:** apply for SAP access · start logging clips with ground-truth transcripts · baseline WER
- **Week 3–4:** get TORGO/UASpeech · build + verify the LoRA notebook on a small public set
- **Week 5–6:** general fine-tune → measure · begin per-speaker collection at FCSN
- **Week 7–8:** per-speaker adaptation → measure → this is the headline number
- **Week 9+:** freeze, chart the three-bar ablation, write it up

---

## What to avoid

- **Training from scratch.** Whisper cost ~680,000 hours of audio and millions of dollars. Not the game you're playing.
- **Collecting audio without transcripts.** Unusable for training. Transcribe as you collect.
- **Chasing hours.** See the table at the top. Diminishing returns start early.
- **Evaluating on training data.** Invalidates everything.
- **Starting at whisper-large.** Debug at `small`, scale later.

---

**Sources:** Interspeech 2025 Speech Accessibility Project Challenge (arxiv 2507.22047) · Adapting Foundation ASR Models to Dysarthric Speech (arxiv 2606.31722) · HuggingFace PEFT Whisper examples
