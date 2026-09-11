# App Store Review — guideline-by-guideline

Every item maps a specific App Store Review Guideline to a concrete thing in this build. Reviewers reject against the guidelines by number; this is how you argue back if they do.

---

## The blocker you need to solve first

**You must be 18 to hold an Apple Developer Program account.** That's a legal requirement, not a policy Apple bends.

Options, in order of preference:

1. **A parent enrolls as an Individual** ($99/yr). The account is theirs; you build under it. This is what most under-18 developers do. Your parent's name appears as the seller unless you set a display name.
2. **Your school enrolls as an Organization** if Mitty has a developer account (many schools do for CS classes). Ask your CS teacher.
3. **Apple Developer Program for education** — some schools qualify for fee-waived org accounts. Worth one email.

Do this **today**. Enrollment takes 24–48h and can take longer if identity verification stalls. Nothing else on this list matters until it's done.

---

## Guidelines that apply, and how the build satisfies them

### 4.2 — Minimum Functionality
*"Your app should include features, content, and UI that elevate it beyond a repackaged website."*

This is the guideline that kills thin-wrapper apps. **The build passes because nothing is a website.** Speech recognition and Clarify both run on-device via Core ML and Foundation Models. The app works in airplane mode after first launch. There is no web view anywhere in it.

If a reviewer questions it anyway, the response is one sentence: "All inference is on-device; the app has no server and functions fully offline."

### 5.1.1 — Data Collection and Storage
*Apps must get consent and explain what data is collected and how.*

- `NSMicrophoneUsageDescription` states what audio is used for and that it never leaves the device.
- `PrivacyInfo.xcprivacy` declares **no data collected**, **no tracking**.
- Privacy nutrition label in App Store Connect: select **"Data Not Collected."** This must match the privacy manifest exactly — mismatch is a rejection.
- Settings screen contains a plain-language privacy statement.

### 5.1.2 — Data Use and Sharing
*Don't send data to third parties without consent.*

Nothing is sent. The only network request is the one-time model download from Hugging Face, which sends no user data (it's a GET for a public file). Say this in the App Store description and in Settings — both done.

### 1.4.1 — Physical Harm / Medical
*Apps that could provide inaccurate data or information that leads to harm are scrutinized. Medical apps must be clear about limitations.*

CoHear is **not** a medical app and must not be categorized as one. Category is **Utilities**, not Medical or Health & Fitness. The build states, in Settings and in the App Store description, that it is not a medical device, is not clinically validated, and should not be relied on for medical, legal, or financial decisions.

Do **not** use the words "diagnose," "treat," "therapy," or "clinical" anywhere in the app or listing. Do not claim it "helps people with dysarthria" in the listing — say it helps *listeners understand hard-to-understand speech*. The distinction keeps you out of the medical category.

### 2.1 — App Completeness
*No placeholder content, no crashes, must be a finished app.*

- No "coming soon," no beta labels, no TODO strings visible.
- First-launch download shows real progress and a retry button on failure — the reviewer *will* hit a slow network.
- Test with the mic denied. The app must explain and offer Settings, not crash. (It does — `RecorderError.permissionDenied`.)

### 2.3 — Accurate Metadata
- Screenshots must show the actual app. Take them from the real build, not mockups.
- Description must not promise features that aren't there. Don't mention "live conversation mode" as continuous background listening — it isn't.
- App name **CoHear**: check it isn't taken on the App Store before submitting. Search it. If taken, "CoHear — Speech Clarity" as the display name.

### 2.5.4 — Background Modes
No background audio requested. The app only records in the foreground. Don't add `UIBackgroundModes: audio` — it invites scrutiny and you don't need it.

### 5.1.1(v) — Account Sign-In
No account required. Good — apps that force sign-in for no reason get flagged. Don't add one.

### 3.1 — Payments
Free, no IAP. Nothing to review.

### 4.0 — Design (HIG)
Not a rejection criterion by itself, but reviewers do reject apps that are unusable. This build's accessibility rules (64pt targets, 24pt text floor, Dynamic Type, no gestures) exceed the HIG. Note it in the review notes.

### Age rating
**4+**. No objectionable content, no unrestricted web access. If App Store Connect asks about "medical/treatment information," answer **no** — the app provides none.

---

## App Store Connect fields — write these once, reuse everywhere

**Name:** CoHear
**Subtitle:** Understand hard-to-understand speech
**Category:** Utilities
**Age rating:** 4+
**Privacy:** Data Not Collected

**Description (draft):**

> CoHear turns what you say into clear text — on your phone, for you.
>
> Tap Listen and talk. Pause, and what you said appears on screen, just for you. When you want someone else to see it, tap Show for large text, or Speak to have it read aloud in a clear voice. Nothing is shown to anyone until you decide.
>
> Everything happens on your iPhone. Your voice is never sent anywhere. There's no account, no server, and nothing is saved after you close the app.
>
> CoHear's speech recognition was adapted for speech that standard voice technology gets wrong — it makes about half as many errors as off-the-shelf recognition on hard-to-understand speech. It is still wrong sometimes. Read what it wrote before you show it.
>
> On iPhones with Apple Intelligence, Clarify cleans up the transcript and adds a one-line summary, also on-device.
>
> CoHear is a research tool, not a medical device. It has not been clinically validated and should not be relied on where a mistake would matter.

**Review notes (the box only reviewers see):**

> All speech recognition and text processing runs on-device (Core ML / Foundation Models). The app has no backend. The only network request is a one-time ~500 MB model download from Hugging Face on first launch, which sends no user data. Fully functional offline after that. To test: tap Listen, speak a sentence, pause ~1 second. Tap Show to see the large-text view. Microphone permission is required; denying it shows an explanation and a link to Settings.

---

## Before you hit Submit

- [ ] Developer account under a parent or school, verified
- [ ] Bundle ID registered (`com.yourfamily.cohear` or similar — not `com.example`)
- [ ] `PrivacyInfo.xcprivacy` in the target and included in the build
- [ ] Nutrition label = Data Not Collected
- [ ] Tested on a real iPhone, not just the simulator (the simulator has no Neural Engine and no Apple Intelligence)
- [ ] Tested with mic permission denied
- [ ] Tested in airplane mode after first launch
- [ ] Tested with Dynamic Type at the largest accessibility size
- [ ] Tested with VoiceOver on — every button reads sensibly
- [ ] Screenshots from the real app, 6.9" and 6.5" sizes
- [ ] "CoHear" searched on the App Store — name is free
- [ ] No word "medical," "clinical," "diagnose," "therapy" in listing or app
- [ ] TestFlight build sent to at least three people who aren't you
