# CoHear iOS — brief for Claude Code

You are building and fixing a native SwiftUI iPhone app. All source is in `CoHear/`. The project file is generated, not hand-maintained.

## What this app is

An on-device speech-to-text tool for people whose speech standard recognizers get wrong. The speaker holds the phone. What they say appears on their screen only; they tap **Show** to display it to someone else, or **Speak** to have it read aloud. Nothing leaves the device. Read `DESIGN_DECISIONS.md` before changing anything structural — every choice there has a reason, and several are ethical constraints, not preferences.

## Hard rules — do not violate

- **No network calls** except WhisperKit's one-time model download. No analytics, no crash reporting SDKs, no remote config. The privacy manifest says "Data Not Collected" and must stay true.
- **No gestures.** No swipe-to-delete, no long-press, no drag, no double-tap. The user may have limited motor control. Every interaction is a single tap on a large target.
- **Minimum 64pt tap targets, 24pt body text.** See `Views/Theme.swift`. Don't shrink anything.
- **Nothing destructive without confirmation.** Delete and Clear always ask.
- **Nothing times out or auto-dismisses.**
- **Clarify must never invent meaning.** If you touch the prompt in `Services/Clarifier.swift`, keep the `[unclear]` rule and the "never add information" rule.
- Don't add persistence of transcripts. Don't add accounts. Don't add a web view.

## Build

```bash
# once
brew install xcodegen

# every time files are added/removed
cd ios && xcodegen generate

# build for simulator (fast, catches compile errors — but no Neural Engine, no Apple Intelligence)
xcodebuild -project CoHear.xcodeproj -scheme CoHear \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -40

# build for a connected iPhone (real test — requires signing to be set up once in Xcode)
xcodebuild -project CoHear.xcodeproj -scheme CoHear \
  -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | tail -40
```

Read the errors, fix the source, rebuild. Repeat until clean. Expect the first build to have a few errors — the source was written without a compiler and verified only against docs.

## Likely first-build issues, and what they mean

- **`DecodingOptions` argument order / unknown label** — WhisperKit's init signature moved. Check `Sources/WhisperKit/Core/Text/DecodingOptions.swift` in the package checkout (`~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/argmax-oss-swift`) and match it.
- **`WhisperKit.download(variant:from:progressCallback:)` unknown** — same; check `WhisperKit.swift` for the current static download signature.
- **`WhisperKitConfig(modelFolder:verbose:load:)`** — same; match the current init.
- **`FoundationModels` not found** — Xcode < 26 or deployment target issue. The code is guarded with `#if canImport(FoundationModels)`; if the SDK lacks it entirely, Clarify simply compiles out. Don't remove the guard.
- **`@Generable` macro errors** — needs Xcode 26+. Same guard applies.
- **`AVAudioApplication` not found** — deployment target must be ≥ iOS 17.
- **Signing errors** — not a code problem. Open the project in Xcode once, select the target → Signing & Capabilities → pick the team. Then CLI builds work.

## Run on a device from the CLI

```bash
xcrun devicectl list devices                      # find the iPhone's identifier
xcodebuild -project CoHear.xcodeproj -scheme CoHear \
  -destination 'id=<DEVICE_ID>' -configuration Debug build
xcrun devicectl device install app --device <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/CoHear-*/Build/Products/Debug-iphoneos/CoHear.app
xcrun devicectl device process launch --device <DEVICE_ID> com.jingjinglei.CoHear
```

## What to test after it runs

1. Tap Listen, say a sentence, pause ~1s. Text should appear.
2. Tap the sentence → edit → Save.
3. Tap Show → full-screen text → close.
4. Tap Speak → hear it.
5. Settings → text-size slider → confirm everything scales.
6. Kill the app. Reopen. Transcript should be gone (by design). Model should NOT re-download.
7. Deny mic in Settings → reopen → tap Listen → should explain, not crash.
8. Airplane mode → everything still works.

## When changing the model

`Services/Transcriber.swift` → `static let spec: ModelSpec = .stock` → change to `.cohear` after `scripts/convert_whisperkit.sh` has published the Core ML model. Delete and reinstall the app so it fetches the new one.

## Archive for App Store

Do this one in Xcode's GUI — Product → Archive → Distribute. The CLI path works but is fiddly and you only do it a few times.
