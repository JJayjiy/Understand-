# CoHear app — build plan

> **Superseded.** The app is now native iOS for App Store release — see `ios/BUILD.md`
> and `ios/APP_STORE_CHECKLIST.md`. The design rules below (speaker-private transcript,
> Show as a deliberate act, accessibility as requirements) all carried over unchanged.
> The PWA/backend architecture did not: the iOS build runs everything on-device.

**Installable web app (PWA) · the speaker is the user · live conversation mode**

---

## The tension you need to resolve first

You picked three things that pull against each other, and it's better to notice now than after building.

- **Live conversation mode** means the transcript appears continuously, as people talk.
- **The speaker is the user** means the phone is in their hand, not the listener's.
- **The speaker approves output before anyone sees it** — the design rule in every document you've written.

Continuous transcription has no approval step. That's what makes it live.

**The resolution:** the live transcript is *private to the speaker* by default. It exists on their screen, for them. Nothing is shown to anyone else, spoken aloud, or sent anywhere until the speaker deliberately does that — one big button, one clear action.

So the app is not "a transcript of the conversation." It's **a draft of what you just said, that you decide whether to show.** That keeps the design rule intact and it keeps the speaker in control, which is the whole product.

Write this down before you build, because every screen decision follows from it.

---

## What runs where

A PWA cannot run whisper-small on-device. Not in v1, not honestly.

```
phone microphone
   │
   ├─ Web Audio API → voice activity detection (in browser, instant)
   │      └─ splits audio at pauses, not on a timer
   │
   └─ each speech segment → HTTPS → your model
                                     │
                              Hugging Face Space
                              whisper-small + LoRA
                                     │
                          text ──────┘
   │
transcript builds on screen, private to the speaker
   │
speaker taps SHOW  →  large-text display / speaks aloud
```

**Why VAD and not fixed 5-second chunks.** Whisper hallucinates on short clips — it will invent a whole sentence from a fragment. If you slice on a timer you will cut words in half and get confident nonsense. Segmenting on silence means every chunk is a complete utterance, which is the input Whisper was built for. `@ricky0123/vad-web` does this in the browser and is the single highest-leverage library in this build.

**Latency to expect:** roughly 1–3 seconds after the speaker stops talking, on the free CPU Space. That is not "live" in the subtitle sense. It's live in the "I finish a sentence and it appears" sense, which is what actually matters here.

**The Space is your backend.** Gradio exposes an HTTP API on every Space — `@gradio/client` calls it from the browser. Free, already deployed, no new infrastructure. It will be slow under load and it sleeps when idle; both are acceptable for a first version with real users, and neither is worth solving before you have any.

---

## Accessibility is not a polish pass here

Your user has dysarthria. In TORGO's population that comes from cerebral palsy and ALS — conditions that affect limb motor control too. **The person holding the phone may not have precise hands.**

This changes the build, so treat these as requirements, not preferences:

- **One primary button, and make it enormous.** Most of the screen. Not a 44pt tap target — a 200pt one.
- **No drag, no swipe, no long-press, no pinch.** Every one of those is a gesture that requires sustained motor control.
- **No double-tap to confirm anything.** Two accurate taps in a row is harder than one.
- **Nothing destructive without a large, separate undo.** A mis-tap must never lose what someone just worked to say.
- **Text at 24pt minimum**, high contrast, and let the OS font-size setting through.
- **Nothing that times out.** No "hold to record," no auto-dismiss, no modal that vanishes. Speaking may take longer; the interface has to wait.
- **Portrait and landscape both**, because a phone on a wheelchair mount is not the same orientation as a phone in a hand.

If you build it for a fast, steady thumb, the person it's for will not be able to use it. That's the most common way tools like this fail, and it happens before any accuracy number matters.

---

## Screens — there are three

**1. Listening.** One giant button. Tap once to start, tap once to stop. A visible indicator that the mic is on, unmissable. Nothing else on the screen.

**2. Transcript.** What you said, big text, most recent at the bottom. Each utterance editable by tapping it — because the model will be wrong a third of the time and the speaker is the only one who knows what they meant. Two buttons: **Show** and **Speak aloud**.

**3. Show.** Full screen, maximum size text, nothing else. This is the screen you turn around and point at someone. It should be readable across a table.

That's the whole app. Resist adding a fourth.

---

## Build order

**Week 1 — prove the pipeline.** Mic capture → VAD → one segment → Space API → text on screen. Ugly is fine. The only question is whether the round trip works on an actual iPhone, and it's the only part that can fail in a way that kills the plan.

**Week 2 — the three screens, built to the accessibility rules above.** Manifest and service worker so it installs to the home screen. Test installed, not in a browser tab — iOS behaves differently in standalone mode, especially around the microphone.

**Week 3 — editing, speak-aloud, offline handling.** The app must say something useful when the network is gone, not fail silently. Web Speech API's `speechSynthesis` handles text-to-speech for free.

**Week 4 — put it in front of one person.** Not five. One. Watch them use it without helping. The list of things you got wrong will be longer than this document, and every item on it will be worth more than another week of building.

---

## What to measure once someone uses it

Corpus results took you as far as they can. The numbers that matter now are different:

- **Did they finish a sentence?** Or abandon it partway.
- **How often did they edit the transcript?** That's your real error rate, on real speech, in a real room.
- **Did they use Show?** If the transcript is never shown to anyone, the app isn't doing its job.
- **Did they open it a second day?** The single strongest signal, and the one most projects never check.

Log these locally on the device, and ask before collecting anything. You're building a tool premised on people staying in control of their own words — the analytics have to respect that or the product is a lie.

---

## Known hard parts

- **iOS PWA microphone access** works in installed PWAs from iOS 16.4, but it is finicky and permissions can reset. Test on a real iPhone early. If it breaks, the fallback is Safari rather than installed mode, which is a worse experience but still works.
- **No background audio in a PWA.** The app must stay in the foreground. For a conversation tool that's mostly fine, but it rules out passive always-on listening.
- **Free Space cold starts** take 30+ seconds after idle. Show an honest loading state; don't let it look broken.
- **34.6% word error is still your accuracy.** The app doesn't change that. This is why the edit step exists and why the speaker approves before showing — the interface is doing real work to make a mediocre number usable.
- **Privacy.** Audio goes to your Space to be transcribed. Say that plainly in the app, in the first screen, before anyone records anything. Don't bury it.

---

## Why a PWA was the right call

No App Store review, no developer account, no $99. You send a link and someone is using it in thirty seconds. That matters more than native polish when your bottleneck is getting the tool in front of people before deadlines.

It also works on Android and desktop from the same code, and the Congressional App Challenge accepts web apps.

Go native later if real users tell you the web version isn't enough — and by then you'll know exactly which part wasn't.
