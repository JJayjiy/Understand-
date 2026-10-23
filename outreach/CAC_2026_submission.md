# Congressional App Challenge 2026: CoHear (CA-17, Rep. Ro Khanna)

**Khanna's deadline:** Oct 30, 2026, 11:59 pm ET. **Aim for Oct 26** in case the national site closes earlier.
**Register:** congressionalappchallenge.us. You'll need a personal (not school) email, your home and school **9-digit ZIP codes** (look them up at tools.usps.com), CA-17 / Ro Khanna, and a parent's name and email.
**Judged on:** (1) quality of the idea, (2) implementation and UX, (3) coding skill. Judges may ask to see the app and source code.

---

## Written answers (all under the character limits)

**1. Title:** CoHear

**2. Purpose in one sentence** (130/140)
CoHear turns hard-to-understand speech into clear text on an iPhone, and learns each person's voice so it understands them better.

**3. What inspired you?** (179/200)
People with dysarthria from stroke, ALS, Parkinson's or CP know what they want to say, but strangers and dictation apps can't understand them. I wanted a tool that listens better.

**4. What is your app trying to accomplish?** (171/200)
Give people with speech disabilities more independence: they speak, check the text privately, then show it or have the phone say it aloud. All on-device, free, no account.

**5. Technical difficulty and how you addressed it** (1378/1500)
My first model, Whisper fine-tuned with LoRA on the TORGO dysarthria dataset, cut errors from 84% to 35% for a severe speaker. Then a real person with dysarthria tried the app and it got almost nothing right. I went back and found 98% of my test sentences also appeared in training, so the model had mostly memorized the dataset's prompt list. I rebuilt the evaluation to test on unseen speakers and unseen sentences: a model trained on other people barely helped a new person (97% to 85% error).

So I pivoted to personalization. Dysarthric speech is hard for strangers but consistent within one person, so I fine-tuned a small LoRA adapter (1.4% of the model) on 13-23 minutes of one speaker's recordings. Across four speakers, word accuracy on sentences they never recorded went from 21% to 47%. Two runs failed (training loss exploded and the model output nothing), so I added a guard that detects the spike and rolls back to the best weights, and lowered the learning rate.

Getting this onto a phone was its own challenge: I converted the model to Core ML to run fully offline, fixed an app crash from running out of memory, and built a 2-minute recording flow using 5 passages I checked against a pronunciation dictionary so they cover every English sound. I used AI coding assistants to help write code, and I designed, tested, and debugged every experiment and feature.

> If your tester session works, swap in her result. Replace the "Getting this onto a phone" paragraph's first sentence, or add: "With my first real tester, accuracy went from __% to __%." Stay under 1500.

---

## Demo video script (about 2:45)

The rules require: participant name(s), app name, one-sentence purpose, target audience, tools and languages, and a demo of how it works. All of these are covered below, marked ✓.

Record the phone screen (screen recording with mic on), plus a few short clips of you talking to camera. Plain cuts are fine; "this is not a video-creation competition."

**0:00–0:20 | Hook (you on camera)**
"Imagine knowing exactly what you want to say, and no one understanding you. That's daily life for millions of people with dysarthria, a speech disorder caused by stroke, ALS, Parkinson's, or cerebral palsy. I'm Nick Lei ✓, and I built **CoHear** ✓."

**0:20–0:35 | Purpose and audience**
"CoHear turns hard-to-understand speech into clear text on an iPhone, and learns each person's voice so it understands them better ✓. It's for people whose speech is hard for others to understand, and the families and caregivers who talk with them ✓."

**0:35–1:20 | How it works (phone screen)**
- Tap **Listen**, speak, and the line appears. "You talk, and your words show up just for you first."
- Tap a line, fix a word. "If it's wrong, you fix it. You're always in control."
- Show an amber **"not sure"** line. "When the model is guessing, it says so, instead of pretending."
- Tap **Show**: "Then turn the phone around," and the big text appears. Tap **Speak**: "or have it read aloud."
- Settings: big text slider. "Every button is huge and there are no gestures, because many users have limited hand control. Everything runs on the phone. No account, nothing uploaded."

**1:20–2:05 | The key result (the most important part)**
- Play a TORGO M04 clip near the phone with the **regular model** and show the garbled output on screen.
- Switch to **Your voice (M04)** and play the same clip, showing the much better output.
- Say: "My first model looked great, until I found it had memorized the test sentences. When I tested honestly, a general model barely helped a new person. But a model that learns *your* voice does: with about 15 minutes of someone's recordings, accuracy on sentences they'd never recorded more than doubled, across four speakers."
- Optional: 10 seconds of your real tester (only with her written permission to be filmed).

**2:05–2:25 | Teach your voice (phone screen)**
"So I built it into the app. A quick start that takes about 2 minutes: five passages I designed to cover every sound in English."

**2:25–2:45 | Tools and close (you on camera)**
"I built CoHear in **Swift and SwiftUI** for iOS, with **Python, PyTorch and Hugging Face** for training, **LoRA** fine-tuning of **OpenAI's Whisper**, and **Core ML** with WhisperKit to run it on-device ✓. I used AI coding assistants along the way, and designed and tested every experiment myself. My goal is simple: help people be understood. Thank you."

**Checklist before uploading**
- [ ] 1–3 minutes long (aim for 2:30–2:50)
- [ ] Says your name, the app name, the one-sentence purpose, the audience, and the tools
- [ ] The before/after clip is clearly visible: zoom in on the text
- [ ] Uploaded to YouTube as **Public** (not Unlisted or Private), and the link pasted into the submission
- [ ] No TORGO audio posted beyond short demo clips, with TORGO credited on screen ("Audio: TORGO database, Univ. of Toronto")

---

## Before submitting

- [ ] GitHub README: what CoHear is, how to run it, results, and an **AI-use statement**
- [ ] Remove the outdated 84→35 claim from `outreach/CoHear_Research_Writeup.md` (or mark it as the flawed first result)
- [ ] App runs on your phone in case judges ask for a live demo
- [ ] Submit by **Oct 26**, then complete the exit questionnaire
