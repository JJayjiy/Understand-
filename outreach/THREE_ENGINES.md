# CoHear — the three engines, and what we measured

A one-page reference. What each option in the app actually is, and the results behind them.

---

## The three engines

| | **OpenAI API** | **Local (free)** | **Our fine-tuned model** |
|---|---|---|---|
| Underlying model | Whisper **large-v2** | Whisper **base** | Whisper **small** + our adapter |
| Parameters | ~1.5 billion | 74 million | 244 million (+3.5M trained) |
| Runs on | OpenAI's servers | This device | This device |
| Needs internet | Yes | No | No |
| Cost per use | ~$0.006 / minute | Free | Free |
| Audio leaves the device | **Yes** | No | No |
| Trained on dysarthric speech | **No** | **No** | **Yes** |

**The headline:** ours is the *only* one of the three trained on speech like this — and it's **6× smaller** than OpenAI's while running entirely on the device for free.

Adaptation is not the same as scale. You can either make the model bigger, or you can make it right for the person speaking. We did the second.

---

## Why "runs on the device" is the part that matters

The OpenAI option is a large, capable model. It's also the one that:

- costs money on every use, forever
- stops working without internet
- **sends a disabled person's voice recording to a third-party company**

That last point is what blocks adoption in schools and clinics. Cloud AI services processing student or patient voice require data-privacy agreements, vendor review, and months of approval. A model that runs on the device sidesteps all of it.

It also can't run on a phone or a small device. Ours can.

---

## What we measured

### 1. The gap

The TORGO research corpus records speakers with and without dysarthria reading **the same prompts** into **the same microphones** in the same room. The only variable is who is speaking.

Off-the-shelf Whisper, on 1,362 held-out utterances from 15 speakers:

| Speaker group | Sentence word error rate |
|---|---|
| Control (no dysarthria) | **2.9%** |
| Dysarthric | **48.0%** |

**About 16× more errors, under identical conditions.**

### 2. It scales with clinical severity

| Severity | Sentence WER | Single-word accuracy |
|---|---|---|
| Control | 2.9% | 71.3% |
| Mild | 12.7% | 62.2% |
| Moderate | 29.5% | 42.1% |
| **Severe** | **77.8%** | **12.9%** |

Those severity ratings were assigned by speech-language pathologists in 2008 using the Frenchay Dysarthria Assessment, with no knowledge of this project. **They predict machine failure almost exactly** — rank the speakers by clinician rating and you have very nearly ranked them by error rate.

### 3. What adaptation does

We adapted Whisper-small using LoRA on 2.5 hours of dysarthric speech — training 3.5M parameters, **1.44% of the model**. Evaluated on 59 held-out utterances from M04, the most severely affected speaker in the corpus. Same test set every time; only the model changes. **No test utterance was seen during training.**

| Model | Trained on | Sentence WER | Single words correct |
|---|---|---|---|
| Whisper-small, off the shelf | — | 84.4% | 3 of 37 (8.1%) |
| + adapted to M04 alone | 24 min, 1 speaker | 50.8% | 20 of 37 (54.1%) |
| **+ adapted to 8 speakers** | 152 min, 8 speakers | **34.6%** | **25 of 37 (67.6%)** |

**59% relative reduction in word error. Word accuracy up 8.3×.**

Training cost: **2.5 hours on a laptop CPU. No GPU, no cloud, nothing paid for.**

### 4. The result we didn't expect

Training on **eight speakers beat training on the target speaker's own 24 minutes** — by a wide margin.

That matters more practically than the accuracy number: it suggests a shared model can help a new person **with no enrollment at all**. Nobody has to record hundreds of phrases before the tool works. Since setup burden is a documented driver of assistive-technology abandonment, a tool that works immediately may matter more than one that's slightly more accurate after an hour of setup.

---

## What this looks like on real audio

Speaker M04, held-out clips. Off-the-shelf Whisper vs. ours:

| He said | Off-the-shelf heard | Ours heard |
|---|---|---|
| **storm** | **dumb** | **storm** |
| storm | dumb | storm |
| knee | nyeh | knee |
| swarm | its one | swarm |
| warm | one | warm |
| read | what | read |
| my sister made the flowered curtains | my my my it took hugeapanmi the the fl | my sister made the flowers cut thin |

37 of 59 clips improved.

The first row is the one worth sitting with. A man says an ordinary word and the machine returns something crude. That is the cost of this problem — not only a wrong word, but an undignified one, in front of whoever is listening.

---

## What we don't claim

- **34.6% is better, not solved.** A third of the words in a sentence are still wrong.
- **Eight speakers is a small sample.** We say "adapted to these speakers," not "generalizes to dysarthric speech."
- **No one with a speech difference has used this yet.** Every result here is on a research corpus.
- **It does not transfer to autism-related speech differences**, which involve apraxia and prosody rather than motor weakness, and produce inconsistent errors that this approach handles poorly.
- **It is a research prototype, not a medical device.** It assists a listener; it does not replace one.
- **The speaker reviews and approves everything.** It offers a suggestion. It never speaks for someone.

---

## Method, briefly

- **Base model:** OpenAI Whisper-small (244M parameters)
- **Adaptation:** LoRA on attention projections, r=32, α=64 — 3.5M trainable parameters (1.44%)
- **Data:** TORGO corpus, 2,651 utterances / 152 minutes, 8 speakers with dysarthria from cerebral palsy and ALS
- **Held out:** 15% per speaker, never trained on, enforced in code
- **Hardware:** laptop CPU, 2.5 hours
- **Metrics:** sentence-level word error rate and single-word accuracy, reported separately (TORGO is ~75% single words; blending them would be misleading)

Data: TORGO database, University of Toronto — Rudzicz, F., Namasivayam, A.K., Wolff, T. (2012), *Language Resources and Evaluation* 46(4), 523–541. Academic/non-profit use.

---

**CoHear** — Jingjing Lei and Melodie Lee, Archbishop Mitty High School
