# Cohear

**Understand people who are hard to understand.**

*co- (together) + hear — and a homophone of cohere: to hold together, to make coherent.*

A tool that takes speech that's hard to parse — atypical speech, stutters, heavy accents, or rambling/indirect speech — and makes it understandable: a clean transcript, the speaker's actual point in one sentence, and optional clear audio playback.

Not language-to-language translation. **Hard-speech → clear-speech, within a language.**

---

## Why

People with atypical speech get talked over, misheard, and left out — not because they have nothing to say, but because listeners can't parse it. Mainstream speech recognition (Siri, YouTube captions, stock Whisper) is trained mostly on typical speech and fails exactly where it's needed most.

This project started from three real situations:

- Students with special needs whose speech isn't understood by the people around them
- An elderly grandmother whose point gets lost, which turns into family conflict
- Same-language accents that are genuinely hard to follow

All three are the same underlying problem: **systematic differences between what a speaker produces and what a listener expects.**

---

## How it works

```
audio
  │
  ├─ Stage 1: HEAR IT RIGHT     Whisper → transcript
  │            + custom vocabulary bias
  │            + per-speaker correction memory
  │
  ├─ Stage 2: GET THE POINT     LLM → clean text + one-sentence intent
  │
  └─ optional: speak the clean version back
```

**Planned Stage 1.5 — the phonological layer.** Phoneme-level (IPA) recognition to build a per-speaker profile of systematic sound substitutions. The key idea: word-level corrections scale with your vocabulary (tens of thousands of entries, no generalization), while phoneme rules scale with the alphabet (~44 English phonemes, and one rule fixes thousands of unseen words). See [`docs/phonological-layer.md`](docs/phonological-layer.md).

---

## Quick start

```bash
git clone <this-repo>
cd understand
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export OPENAI_API_KEY=sk-...        # or paste it in the app sidebar
streamlit run app.py
```

Opens at http://localhost:8501.

### Two transcription engines

| Engine | Cost | Notes |
|---|---|---|
| **OpenAI API** | ~$0.006/min | Fastest to start. Needs a key. |
| **Local (free)** | $0 | Runs on your computer, offline, no key. `pip install faster-whisper`. First run downloads the model. |

Stage 2 (clarify) uses the API either way. Model names are constants at the top of `app.py` — swap freely.

---

## The tabs

- **Clarify** — the core loop. Record or upload → the point, plus raw vs. clarified side by side → speak it back.
- **Personalize** — correction memory + custom vocabulary. Lightweight per-speaker personalization, no training required.
- **Measure WER** — paste what the speaker actually meant, get baseline vs. Cohear word error rate. **This delta is the headline metric.**

---

## Roadmap

- [x] v0 — working pipeline, two engines, WER measurement
- [ ] Session logging + training-dataset export
- [ ] LoRA fine-tuning on atypical speech ([`docs/data-and-finetuning.md`](docs/data-and-finetuning.md))
- [ ] Per-speaker model adaptation — the real moat
- [ ] Phonological (IPA) layer ([`docs/phonological-layer.md`](docs/phonological-layer.md))
- [ ] Earbuds + phone: near-real-time listener-side clarification
- [ ] Purpose-built device for users who can't use phones (one big button, status light, mic array)

---

## Privacy & ethics — read before collecting anything

This project involves **vulnerable populations**: people with disabilities, minors, and elderly speakers.

- **Written consent before any recording.** Parental consent for minors. Template: [`docs/consent-form.md`](docs/consent-form.md)
- **Speaker codes, never names** (`S01`, `S02`…).
- **Never commit** audio, transcripts, consent forms, or `.env`. The `.gitignore` covers these — don't override it.
- **Data minimization.** Store only what's needed; let people delete their data.
- With the OpenAI engine, audio is sent to OpenAI. With the local engine, it stays on the machine.

---

## Repo layout

```
app.py                        research app (Streamlit) — three engines side by side
scripts/
  torgo_prep.py               build train/test manifests from TORGO
  finetune_lora.py            LoRA fine-tuning (laptop CPU, ~2.5h)
  eval_whisper.py             WER / single-word accuracy
  phone_calibration.py        control-calibrated phone deviation (.PHN based)
  convert_whisperkit.sh       export merged model to Core ML for iOS
results/                      measured numbers + write-ups (PHONE_CALIBRATION, LAYER_DECISION)
release/                      model card + release guide (HF: JJaysz/cohear-whisper-small-dysarthric)
space/                        Hugging Face Space demo (huggingface.co/spaces/JJaysz/cohear)
ios/                          native iPhone app — on-device, App Store bound
  CoHear/                     SwiftUI source
  BUILD.md                    Xcode steps
  APP_STORE_CHECKLIST.md      guideline-by-guideline
outreach/                     research write-up, one-pagers, email drafts
docs/                         plans and specs
```

---

## Team

- **Nick** — pipeline, app, fine-tuning, hardware, outreach
- **[Friend]** — linguistics: phonological layer, intent extraction, error analysis

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for how we split work.

---

## License

MIT — see [`LICENSE`](LICENSE).
