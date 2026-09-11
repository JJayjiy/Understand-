# Building CoHear for iOS

Native SwiftUI. Everything runs on the phone — no server, no API key, no account.

```
microphone
   │  AVAudioEngine → 16 kHz mono
   ▼
AudioRecorder      splits speech at pauses (energy VAD)
   │  one utterance
   ▼
Transcriber        WhisperKit · Core ML · your fine-tuned model
   │  raw text
   ▼
Clarifier          Apple Foundation Models (iOS 26, Apple Intelligence devices)
   │  clean text + one-line point        ← skipped gracefully elsewhere
   ▼
SessionStore       in memory only, private to the speaker
   │
   ├─► Show   full-screen large text — the speaker turns the phone around
   └─► Speak  AVSpeechSynthesizer, on-device
```

Why on-device and not the Hugging Face Space as a backend: the Space sleeps, is slow on free hardware, and would make the app a thin client — which App Store guideline 4.2 rejects. On-device also makes the privacy story one sentence: *your voice never leaves the phone.* That sentence is the product.

---

## Step 0 — the developer account (start today)

You need to be 18 to hold an Apple Developer account. See `APP_STORE_CHECKLIST.md` → "The blocker." A parent enrolling as an Individual is the normal path. Enrollment takes 1–2 days. You can build and run on your own iPhone with a free Apple ID in the meantime — you just can't ship.

## Step 1 — create the Xcode project

**Recommended: generate it.** No dragging, no clicking, reproducible.

```bash
brew install xcodegen
cd ~/Desktop/Understand/ios
xcodegen generate
open CoHear.xcodeproj
```

That reads `project.yml`, creates the project with WhisperKit already added and all Info.plist keys set. Skip to Step 3. If you're using Claude Code, hand it `CLAUDE.md` and it'll run the build loop from here.

**Manual alternative** (only if xcodegen won't install):

1. Xcode → **File → New → Project → iOS → App**
2. Product Name: `CoHear` · Interface: **SwiftUI** · Language: **Swift** · Storage: **None**
3. Save it as `ios/CoHearApp/` inside this repo (next to the `CoHear/` source folder)
4. In the Project navigator, **delete** the generated `ContentView.swift` and `CoHearApp.swift`
5. Drag the entire `ios/CoHear/` folder from Finder into the project navigator. Check **"Copy items if needed"** is *off* and **"Create groups"** is on. Make sure the CoHear target is ticked.
6. Select the project → target **CoHear** → **General**:
   - Minimum Deployments: **iOS 17.0**
   - Supported Destinations: iPhone (iPad optional)
7. Target → **Info** tab → add the keys from `CoHear/Resources/Info.plist.additions.md`
8. Confirm `PrivacyInfo.xcprivacy` shows in **Build Phases → Copy Bundle Resources**

## Step 2 — add WhisperKit (2 min)

**File → Add Package Dependencies…**
Paste: `https://github.com/argmaxinc/argmax-oss-swift`
Dependency rule: *Up to Next Major* from `0.9.0`
When asked which products: tick **WhisperKit** only.

## Step 3 — build and run on a real iPhone

The Simulator has no Neural Engine and no Apple Intelligence. It will run, slowly, and Clarify will be off. **Test on hardware.**

- Plug in your iPhone → select it as the run destination → ⌘R
- First launch downloads the model (~500 MB, progress bar). Cached after.
- Tap **Listen**, say a sentence, pause. It should appear.
- Tap the sentence to edit. Tap **Show** for the big-text screen. Tap **Speak**.

With `Transcriber.spec = .stock` (the default) this uses Argmax's stock `small.en`, so the app is fully runnable before your model is converted.

## Step 4 — put your model in (30–40 min, once)

```bash
cd ~/Desktop/Understand
bash scripts/convert_whisperkit.sh
```

That publishes the merged model to HF, converts it to Core ML with whisperkittools, and pushes the result to `JJaysz/cohear-whisperkit`. When it finishes, open `CoHear/Services/Transcriber.swift` and change one line:

```swift
static let spec: ModelSpec = .cohear
```

Delete the app from your phone and reinstall so it downloads the new model.

**One thing to send Frank first.** He approved releasing *adapter* weights. The converted Core ML model is the base model with the adapter merged in — it contains nothing that isn't already derivable from two public artifacts, but it's a different file than the one he approved. One sentence in your existing thread: *"For the iOS build I need to publish the adapter merged into whisper-small as a Core ML model — same weights, different packaging. Wanted to confirm that's fine under the same terms."* He'll say yes. Ask anyway.

## Step 5 — test the things reviewers test

- **Deny the mic**, then tap Listen. Should explain, not crash.
- **Airplane mode** after first launch. Everything should work.
- **Settings → Accessibility → Display & Text Size → Larger Text**, slider to max. Nothing should clip or overlap.
- **VoiceOver on.** Swipe through every screen; every button should announce something sensible.
- **A phone without Apple Intelligence** (iPhone 14 or earlier). Clarify should be off with a plain explanation in Settings; transcription unaffected.

## Step 6 — TestFlight, then submit

1. Product → **Archive** → **Distribute App** → App Store Connect → Upload
2. App Store Connect → TestFlight → add three testers who aren't you. Give it a week.
3. Fill in the fields from `APP_STORE_CHECKLIST.md`. Copy the description and review notes verbatim.
4. Submit. First review typically takes 1–3 days.

---

## What's deliberately not in v1

- **No persistence of transcripts.** They're gone when the app closes. That's the privacy promise made simple.
- **No background listening.** Foreground only. Fewer entitlements, less to review, less battery.
- **No cloud anything.** No accounts, no sync, no analytics. If you add analytics later, the privacy manifest and nutrition label both change — don't do it casually.
- **No phoneme layer.** Per `results/LAYER_DECISION.md`.

## Known rough edges to expect

- The energy-based VAD will occasionally split a slow sentence in two, or merge two quick ones. Tune `silenceToEnd` in `AudioRecorder.swift` (0.9 s) after you've watched a real person use it. Slower speakers may need 1.3–1.5 s.
- Whisper sometimes hallucinates a full sentence from a cough. The `minSpeech` floor (0.4 s) catches most of it. If it's a problem, the next step is Silero VAD, not a bigger threshold.
- First transcription after launch is slower (Core ML warm-up, ~2 s). Subsequent ones are fast.
- `small.en` on an iPhone 12 or older will feel sluggish. On iPhone 14+ it's ~1 s per utterance.
