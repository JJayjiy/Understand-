---
title: "CoHear test session: walkthrough"
date: "Participant: ______________   Date: __________   Location: __________"
geometry: margin=0.8in
fontsize: 11pt
---

**Total time:** about 75–90 minutes. **Goal:** measure how well stock Whisper understands her, teach CoHear her voice, then measure again on the same sentences.

## 0. Before you leave home (15 min)

- [ ] **Stop the M04 training** in Terminal (Ctrl+C) if it isn't done. Her build needs the Mac to itself.
- [ ] **Rebuild CoHear onto your iPhone** from Xcode (so it has the Teach screen and the junk fix)
- [ ] On the phone: Settings → Speech model → **Whisper small.en (stock)**. Open it once and make sure it has finished downloading.
- [ ] Phone and Mac charged, plus the Mac charger. AirDrop on.
- [ ] Terminal test: `cd ~/Desktop/Understand && source .venv/bin/activate` works
- [ ] Print **2 consent forms** (one for her to keep) and this sheet. Bring a pen.
- [ ] Bring water for her. Talking a lot after a stroke is tiring.

## 1. Arrive and set up (5 min)

- Quiet room. Turn off the TV and fans, and close the windows.
- She sits comfortably. **You hold the phone** about 30 cm (one foot) from her mouth, the same distance every time. Stroke often weakens one hand, so don't make her hold it.
- Sit where she can see your face and the sentences. Use a big font, or let her read off this sheet.

## 2. Welcome and consent (5 min)

- **Talk to her, not to her family**, even if a family member helps.
- Say something like: *"I built an app that writes down what people say. It works better after it learns your voice. Your recordings stay on my computer, I only use them to build your model, and I'll delete them whenever you want. You can stop or take a break anytime."*
- Go through the consent form slowly and let her ask questions. A family member can help her understand it, but she decides.
- [ ] Consent form signed

**Be patient.** Don't finish her sentences or correct how she says things. If a word doesn't come out, just move on; that sentence still counts. Some stroke survivors also have trouble finding words (aphasia), and that's okay.

## 3. Before test: stock Whisper (5–10 min)

Speech model = **Whisper small.en (stock)**. Tap Listen. She says each sentence **once** at her normal pace. If reading is hard, you say it first and she repeats (do the same in the after test). Write down what the app shows, then count the right words later.

**Set A: sentences she will also record during teaching**

| # | Say this | App wrote | Right |
|--|------------------------------|------------------------------|---|
| A1 | Can I have some water? | | /5 |
| A2 | Where are my glasses? | | /4 |
| A3 | Could you push my chair? | | /5 |
| A4 | I usually watch the news. | | /5 |
| A5 | Call my daughter. | | /3 |

**Set B: sentences she will never record**

| # | Say this | App wrote | Right |
|--|------------------------------|------------------------------|---|
| B1 | Please close the window in the bedroom. | | /7 |
| B2 | My grandson is coming to visit on Sunday. | | /8 |
| B3 | I would like some warm soup for dinner. | | /8 |
| B4 | Where did I put my glasses? | | /6 |
| B5 | The doctor said my blood pressure is fine. | | /8 |

**Before totals:** A ____ / 22   B ____ / 37

Tip: snap a photo of the screen after each sentence, so you can fill in the table later instead of writing while she waits.

## 4. Teach CoHear her voice (10–20 min)

Settings → **Teach CoHear your voice**. Type her first name.

1. [ ] Record the 32 **Quick start** phrases. Tap record, she says it, tap stop, then Keep. If reading is hard, tap **Hear it** (or say it yourself) and she repeats.
2. [ ] Add 3–5 of **her own** phrases: family names and things she says every day ("I need my medicine", her grandson's name).
3. [ ] If she still has energy, record more under "Keep improving". More recordings help, and they barely add training time.
4. [ ] **Never add the Set B sentences.** They have to stay unseen for the test to be fair.

**If something goes wrong:**

- **"Too long" message:** clips are capped at 30 seconds. If a passage takes her longer, add each half as its own phrase.
- **She stumbles badly:** tap Redo. A small mistake is fine, so keep the take; it's her real voice.
- **She looks tired:** take a break. A short session is better than an exhausting one.

Recordings: ______   Minutes: ______   Breaks: ______

## 5. Build her model (about 20–30 min)

1. On the Teach screen, tap **Export recordings** and AirDrop the zip to your Mac.
2. In the Mac Terminal:

```
cd ~/Desktop/Understand && source .venv/bin/activate
caffeinate -i bash scripts/build_personal_model.sh NAME \
  ~/Downloads/CoHear-voice-NAME-*.zip --skip-eval
```

3. **While it runs:** take a break, chat, and ask the section 7 feedback questions now while she's fresh.
4. When it prints **Done** (and **"deleted private repo"**; if not, delete it on huggingface.co):
   AirDrop `models/whisperkit_personal/user_NAME/PersonalModel-user_NAME.zip` to the iPhone
   (NAME = her first name, lowercase) → Save to Files → tap the zip to unzip it.
5. CoHear → Settings → Teach CoHear your voice → **Install personal model** → pick the `PersonalModel` folder.
6. Settings → Speech model → **Your voice (her name)**.

Build started: ______   finished: ______

**If the build fails:** take a screenshot of the error, thank her, and do the after test another day. Her recordings are saved, so nothing is lost.

## 6. After test: her personal model (5–10 min)

Same 10 sentences, same order, same phone distance.

| # | App wrote (her personal model) | Right |
|--|------------------------------------------------------------|---|
| A1 | | /5 |
| A2 | | /4 |
| A3 | | /5 |
| A4 | | /5 |
| A5 | | /3 |
| B1 | | /7 |
| B2 | | /8 |
| B3 | | /8 |
| B4 | | /6 |
| B5 | | /8 |

**After totals:** A ____ / 22   B ____ / 37

**Set B is the number that matters.** It shows whether CoHear learned *her voice* rather than the sentences.

## 7. Her feedback (5 min)

- Was recording comfortable? Too long?
- Was the text big enough to read?
- Did the second version feel different to her?
- When in her day would something like this help? (doctor visits, phone calls, family)
- Anything confusing?
- Ask a family member too: *Do you have trouble understanding her? When?*

Notes:

\

\

\

## 8. Wrap up

- [ ] Thank her (a small thank-you gift or card is a nice touch)
- [ ] Ask whether she'd like to keep using it later (TestFlight), and whether you can contact her again
- [ ] Ask before taking any photo or video. Get her written OK if you want to use it in the CAC video.
- [ ] Keep the signed consent form somewhere safe
- [ ] Her recordings stay on your Mac only (git-ignored). Delete them if she asks.
- [ ] Send me the before/after totals and the "App wrote" lines
