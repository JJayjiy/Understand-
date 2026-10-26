# CoHear

**Helping people with atypical speech be understood.**

CoHear is a free iPhone app for people with **dysarthria**: slurred or hard-to-follow speech caused by stroke, ALS, Parkinson's, or cerebral palsy. You talk, CoHear writes down what you said (privately, so you can check it first), and then the phone reads it aloud or shows it in big letters. It can also learn one person's voice, which is where most of the accuracy comes from.

Everything runs on the phone. No account, no server, nothing uploaded.

Built by Jingyu (Nick) Lei, Archbishop Mitty High School, for the 2026 Congressional App Challenge (CA-17).

---

## What it does

| | |
|---|---|
| **Talk** | Tap one big Listen button and speak. Each sentence appears as a chat bubble. Tap a bubble to hear it read aloud; tap **Show** to display it in large text for the listener. |
| **You / Them** | Your lines appear on the left, the other person's on the right, so a conversation reads like a chat. One tap corrects a wrong guess. |
| **Phrases board** | An AAC-style board for when words won't come: one tap on "I need help," "Water, please," or your own phrases and the phone says it immediately. |
| **Teach CoHear your voice** | Record 32 short everyday phrases (about 5–10 minutes), designed to cover every English sound. A **Hear it** button reads each phrase aloud so users can repeat instead of read. The recordings train a personal model. |
| **Honest about uncertainty** | When the model is guessing, the line is marked "Not sure it heard this right" instead of being shown as fact. |
| **English and Mandarin** | Full Chinese interface and Mandarin recognition, added for my first tester. |

## Why personalization

My first model was OpenAI's Whisper fine-tuned on the TORGO dysarthria dataset. On my first test it cut errors from 84% to 35%, until a real person with dysarthria tried the app and it understood almost nothing. I found that **98% of my test sentences also appeared in training**: the model had memorized sentences, not learned speech.

After rebuilding the evaluation so every test used unseen speakers and unseen sentences, a general model barely helped a new person (97% → 85% word error). But dysarthric speech, while very different between people, is **consistent within one person**. So CoHear trains a small personal add-on per user:

| Four TORGO speakers, sentences they never recorded | Words correct |
|---|---|
| Stock Whisper | 21% |
| Personal model (LoRA, ~15 min of that person's speech) | **47%** |

## How it works

```
iPhone (Swift / SwiftUI)                          Mac (Python)
────────────────────────                          ─────────────
mic → voice activity detection                    app export (WAV + transcripts)
    → Whisper on Core ML (WhisperKit)                 → LoRA fine-tune of whisper-small
    → confidence + repetition guards                    (r=32, ~3.5M params, 1.4% of the model,
    → You/Them voice check                               audio augmentation, divergence guard)
    → bubbles · Show · Speak                          → merge → Core ML conversion
                                                      → PersonalModel folder → AirDrop → app
```

- **Model:** `openai/whisper-small` + LoRA on the attention query/value projections.
- **On-device:** converted with WhisperKit tools; runs on the iPhone's Neural Engine.
- **Robustness:** training adds random noise, echo, and phone-speaker muffling so the model learns the voice, not the microphone.
- **Mandarin:** language forced (Whisper often misidentifies dysarthric speech), output converted to Simplified characters, scored by character error rate.

## Repository

```
ios/                 iPhone app (SwiftUI). Generate the project with XcodeGen.
  CoHear/Views/        Home, Phrases board, Teach, Settings, Welcome, Show
  CoHear/Services/     Transcriber (WhisperKit), recorder, voice check, personal model
scripts/
  finetune_lora.py     LoRA fine-tuning (augmentation, divergence guard)
  eval_whisper.py      WER / CER evaluation
  make_loso_split.py   leave-one-speaker-out, text-disjoint splits (the data-leak fix)
  build_personal_model.sh   app export → personal model → Core ML package
docs/                support and privacy pages (GitHub Pages)
results/             evaluation summaries
```

### Build the app

```bash
brew install xcodegen
cd ios && xcodegen generate && open CoHear.xcodeproj
```

### Build a personal model from an app export

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
bash scripts/build_personal_model.sh <name> <export.zip>          # add --skip-eval for small sets
```

## Privacy

Speech recognition runs entirely on the iPhone. Recordings from "Teach CoHear your voice" stay on the phone unless the user chooses to export them. Personal models are built on a local computer, with the person's consent. No TORGO audio or participant recordings are included in this repository. [Privacy policy](https://jjayjiy.github.io/Understand-/privacy.html)

## How I used AI

I used AI coding assistants (mainly Claude) to write much of the Swift and Python code from my descriptions, explain concepts, and help edit writing. I came up with the idea, made the design decisions, ran every training and evaluation run, tested every build on my iPhone, ran the sessions with my tester, and handled the App Store submission. Details are in my Congressional App Challenge submission.

## Credits

- **TORGO database** (University of Toronto): F. Rudzicz, A. K. Namasivayam, T. Wolff, "The TORGO database of acoustic and articulatory speech from speakers with dysarthria," *Language Resources and Evaluation*, 2012. Used for research only; not redistributed.
- **OpenAI Whisper**, **Argmax WhisperKit**, **Hugging Face Transformers / PEFT**.
- My first tester and her family, and the researchers who answered my emails.

CoHear is a research tool, not a medical device.

MIT License.
