# CoHear iOS — design decisions, and how good they actually are

Every choice below has a verdict. **Right** means I'd make it again with no reservations. **Right for now** means it's the correct v1 call but has a known expiry. **Debatable** means a reasonable person would choose differently and I might be wrong.

---

## 1. Native iOS instead of the PWA we'd planned

**What:** SwiftUI app for the App Store, not an installable web app.

**Why:** You asked for the App Store. That single requirement decided most of what follows. A PWA can't be listed on the App Store, and a web view wrapped in a native shell gets rejected under guideline 4.2 (Minimum Functionality).

**Cost:** iPhone only — no Android. Needs an 18+ developer account, which you don't have yet. Slower to first user than a link would have been: days instead of minutes. And I can't compile it from here, so the first build errors are yours to paste back.

**Verdict — Right, given the goal.** If the goal had stayed "real users this week," the PWA was better. For "a thing that exists on the App Store before college applications," native is the only path. Worth being clear-eyed that you traded reach and speed for legitimacy.

---

## 2. Everything on-device — no server at all

**What:** Speech recognition, clarification, and text-to-speech all run on the phone. The app makes exactly one network request in its life: downloading the model on first launch.

**Why:** Three independent reasons, any one of which would have been enough.

- The Hugging Face Space is the wrong backend for a product. It sleeps after 48h, runs on a free CPU, and has no uptime guarantee. A reviewer hitting it cold would fail the app.
- Guideline 4.2 again — an app whose only function is calling a remote API is a thin client.
- It makes the privacy story one true sentence: *your voice never leaves the phone.* For a product whose entire ethical position is "the speaker stays in control," sending their voice to a server would have been a contradiction in the architecture. The nutrition label reads **Data Not Collected**, and it's true.

**Cost:** A ~500 MB download on first launch, which is a real barrier on cellular and a real wait on slow wifi. Older phones (iPhone 12 and earlier) will feel slow. And there's no server-side telemetry — you can't see how anyone uses it.

**Verdict — Right.** This is the decision I'm most confident in. The costs are real but they're the honest costs of the privacy promise, not incidental ones.

---

## 3. WhisperKit, not whisper.cpp or Apple's built-in speech recognition

**What:** Argmax's WhisperKit (Core ML) runs your fine-tuned Whisper.

**Why not Apple's `SFSpeechRecognizer`:** It's trained on typical speech — it *is* the 48% WER problem — and you can't load a custom model into it. Using it would throw away the entire research result.

**Why not whisper.cpp:** It works on iOS, but WhisperKit is Core ML native, uses the Neural Engine properly, and has a maintained conversion tool for custom models. whisper.cpp would mean writing an Objective-C bridge and doing the conversion by hand.

**Cost:** A third-party dependency you don't control. If Argmax changes their API, you fix it. Their conversion tool decides whether your model works. And their stock `small.en` is English-only while your LoRA sits on multilingual `whisper-small` — so the dev placeholder and your real model aren't apples-to-apples. Don't draw conclusions from comparing them.

**Verdict — Right for now.** The only mature path for a custom Whisper on iOS. If it becomes a problem, the fallback is whisper.cpp, which is a week of work, not a rewrite.

---

## 4. Model downloaded on first launch, not bundled in the app

**What:** The app ships small and pulls the model from Hugging Face the first time it opens.

**Why:** Bundling 500 MB puts the app over the 200 MB cellular download limit, forcing wifi to install at all. It also means a model update requires an App Store release. Downloading lets you push a better model by uploading to HF — no review cycle.

**Cost:** This is the weakest point in the architecture. First launch depends on Hugging Face being up and the user's connection being decent. If HF has an outage during App Store review, the reviewer sees a failure. I mitigated with real progress and a retry button, but I didn't eliminate it.

**Verdict — Debatable.** A reasonable alternative is bundling a compressed `tiny` or `base` model as a guaranteed fallback and downloading `small` in the background. That's more work and more code paths, so I left it out of v1. If the first-launch download causes a rejection or bad reviews, do that next.

---

## 5. Apple's on-device language model for Clarify, not OpenAI

**What:** The "clean it up and give me the point" step uses Apple Foundation Models (iOS 26, Apple Intelligence devices).

**Why:** The alternative was an OpenAI API call, which means either shipping your API key inside the app — anyone can extract it and run up your bill — or building a proxy server, which reintroduces every problem from decision 2. On-device means no key, no server, no data leaving, and it's free.

**Cost:** Only iPhone 15 Pro and newer. Apple's model is smaller and less capable than GPT-4o-mini; it will produce weaker clarifications. You have no control over its updates. And you can't test it in the Simulator.

**Verdict — Right for now.** The gating is the honest part: on older phones Clarify simply turns off with a plain explanation, and the app is still complete without it. Clarify is a layer, not a dependency — that's the design property that makes this acceptable. Revisit if the Apple model's clarifications turn out to be actively bad rather than just modest.

---

## 6. Split speech at pauses, not on a timer, and not true streaming

**What:** The recorder waits for ~0.9 s of silence, then hands the whole utterance to Whisper.

**Why:** Whisper is built to see a complete thought. Fixed 5-second chunks cut words in half and produce confident nonsense. True streaming (token-by-token as you speak) is what WhisperKit's Pro tier sells, is complex, and for this user isn't better — someone with dysarthria doesn't need to watch words appear mid-sentence; they need the sentence to be right when it lands.

**Cost:** 1–3 seconds of latency after the speaker stops. Slow or hesitant speakers will get split mid-sentence when a pause exceeds the threshold. The threshold will need tuning after watching real people, and there's no one right value.

**Verdict — Right for v1.** "Finish a sentence, it appears" is the right feel. The threshold is a known knob, not a design flaw.

---

## 7. Energy-based voice detection, not a neural VAD

**What:** Speech is detected when RMS energy rises above an adaptive noise floor.

**Why:** It's forty lines, runs in microseconds, and needs no model. For a person speaking into a phone at arm's length it works.

**Cost:** It's crude. A door slam is "speech." A soft speaker in a loud room may never trigger it. Whisper then hallucinates a sentence from the noise.

**Verdict — Right for now, with an expiry.** This is the component most likely to embarrass you in a real room. When it does, the fix is Silero VAD (a small neural model), not a smarter threshold. Budget a day for it after the first real user session.

---

## 8. Transcripts are not saved — ever

**What:** Everything said lives in memory. Close the app, it's gone.

**Why:** The product promise is "nothing is stored." The simplest way to keep a promise is to make it structurally impossible to break. It also removes an entire category of privacy questions, and a whole screen's worth of UI (history, search, delete-all, export).

**Cost:** Some users will want history. A conversation from yesterday, a phrase they say often. The first feature request you get may be this one.

**Verdict — Right for v1, Debatable long-term.** If you add history, it must be opt-in, local-only, and the nutrition label still stays "Data Not Collected" because it never leaves the device. Don't add it because it seems obvious; add it because a real user asked.

---

## 9. The transcript is private until the speaker taps Show

**What:** What the app hears is displayed only to the speaker. Showing it — full-screen large text, or reading it aloud — is a separate, deliberate action.

**Why:** This resolves the tension between "live transcription" and "the speaker approves before anyone sees it." A transcript that appears on a screen facing the listener has already been shared; the speaker had no say. A transcript that appears on a screen facing the speaker is a draft. The speaker turns the phone around when they're ready.

It also means the model being wrong a third of the time is survivable. Wrong text the speaker sees first is an edit. Wrong text the listener sees first is a misunderstanding — the exact thing the app exists to prevent.

**Verdict — Right.** This is the design decision I'd defend hardest. It's the whole app.

---

## 10. One main screen, not three

**What:** The plan said three screens: Listen, Transcript, Show. I merged Listen and Transcript into one — big button at the bottom, what you've said above it.

**Why:** Every navigation is a tap, and every tap is a cost for someone with limited motor control. Listen and Transcript were never meaningfully separate: you listen *in order to* see the transcript. Splitting them added a tap for no reason.

**Cost:** The main screen does two things. On a small phone with a long conversation, the transcript area shrinks. Minor.

**Verdict — Right.** Fewer screens is almost always right for this user.

---

## 11. Accessibility as hard constraints, not polish

**What:** 132 pt Listen button. 64 pt minimum on anything tappable. 24 pt text floor. No swipe, drag, long-press, or double-tap anywhere. Nothing times out. Delete always confirms. Show keeps the screen awake.

**Why:** In TORGO's population, dysarthria comes with cerebral palsy and ALS — conditions that affect the hands too. An app built for a fast steady thumb is unusable by the person it's for, and that failure happens before accuracy matters. These aren't preferences. They're the requirements that make the accuracy number reachable.

**Cost:** It looks big and plain next to a typical app. Some tappable things feel oversized to a user without motor impairment.

**Verdict — Right.** If someone says it looks too simple, the app is working.

---

## 12. Clarify's instructions forbid inventing meaning

**What:** The system prompt tells the model to remove stutters and filler, never add information, mark unclear words as `[unclear]`, and say plainly when meaning is unclear rather than guess.

**Why:** A clarifier that "helpfully" completes someone's sentence has put words in their mouth. That's the harm the app exists to avoid, and a language model's default behavior is to be helpful in exactly that way. The prompt has to actively fight it.

**Cost:** Clarifications will sometimes be less fluent than they could be. `[unclear]` will appear when a bolder model would have guessed right.

**Verdict — Right.** A wrong guess presented as clean text is worse than an honest gap. The speaker can fix a gap; they may not notice a confident wrong word.

---

## 13. No analytics — which contradicts something I told you earlier

**What:** No usage tracking of any kind.

**Why:** Tracking changes the privacy manifest, the nutrition label, and the one-sentence privacy story. It also needs a server to send to.

**The contradiction:** In the earlier app plan I told you to measure four things once real people use it — did they finish a sentence, how often did they edit, did they use Show, did they open it a second day. This build can't measure any of them. I'm flagging it rather than pretending the plan and the build agree.

**Resolution:** Those numbers should come from *watching one person use it* in v1, not from telemetry. If you later want in-app metrics, they must be opt-in, local-only, and visible to the user in Settings. That keeps the label honest.

**Verdict — Right for now.** Watching a person beats a dashboard at this stage anyway.

---

## 14. What I'd change first, in order

1. **Silero VAD** — after the first real user session exposes the energy detector.
2. **Bundled fallback model** — if first-launch download causes a rejection or bad reviews.
3. **Tune the pause threshold** — per real speaker, maybe a slider in Settings.
4. **Opt-in local history** — only if a user asks.
5. **Android** — only if the App Store version has users and one of them asks.

## 15. What I got wrong, or might have

- I told you PWA, then reversed to native when the goal changed. The reversal was right; the initial recommendation wasn't wrong for the goal at the time. But it cost a plan document that's now superseded.
- The first-launch download is a real fragility and I chose it anyway. See decision 4.
- I can't compile Swift. There will be build errors. I checked APIs against current docs, but "checked" isn't "compiled."
- I built for a speaker who can read. A user who is dysarthric *and* has low vision, or can't read at all, is not served by this design, and the Speak button only helps a listener. That's a whole other product.
