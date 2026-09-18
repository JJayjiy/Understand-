# Publishing CoHear — the exact sequence

Metadata copy (description, review notes, keywords) is in `APP_STORE_CHECKLIST.md`. This file is just the clicks, in order.

---

## 0. Before you archive — 40 minutes, do not skip

**Put your model in.** Right now the app ships stock Whisper. The App Store version should ship yours.

```
cd ~/Desktop/Understand
bash scripts/convert_whisperkit.sh
```

When it finishes, delete CoHear from your phone, ⌘R to reinstall, open Settings → **Speech model** should say *CoHear (adapted for dysarthria)*. If it says Stock, something didn't upload — check the script output.

**Commit.**

```
git add -A && git commit -m "team, bundle id, model fallback, voice filter" && git push
```

---

## 1. Create the app record — App Store Connect, 10 minutes

Sign in at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) **as your dad** (he can sign in on your Mac; you don't need his password after — the session persists).

**My Apps → + (top left) → New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | **CoHear** — if taken, try "CoHear: Speech Clarity" |
| Primary Language | English (U.S.) |
| Bundle ID | **com.leifamily.cohear.CoHear** (select from dropdown — it's there because Xcode registered it) |
| SKU | `cohear-ios-1` (anything unique; never shown to users) |
| User Access | Full Access |

**Create.** You now have an app page with a version "1.0 Prepare for Submission."

---

## 2. Archive — Xcode, 5 minutes

1. Top bar destination dropdown → **Any iOS Device (arm64)** (not your phone, not a simulator)
2. **Product → Archive**
3. Wait ~3 minutes. The **Organizer** window opens with your archive listed.

If Archive is greyed out, you have a simulator selected. Pick Any iOS Device.

---

## 3. Upload — Organizer, 5 minutes

1. Select the archive → **Distribute App**
2. **App Store Connect** → Next
3. **Upload** → Next
4. Leave the defaults (upload symbols, manage version) → Next
5. **Automatically manage signing** → Next
6. Review → **Upload**

Takes 2–10 minutes. Then App Store Connect emails you when it's "processed" — another 10–30 minutes.

---

## 4. TestFlight — 1 week, and worth every day

This is the same upload; TestFlight just lets people install it before review.

**App Store Connect → your app → TestFlight tab.** The build appears once processed.

**Internal testing** (instant, no review): Add yourself and your dad. Install TestFlight on your phone from the App Store, accept the invite.

**External testing** (Apple does a light review, ~1 day): **+ next to External Testing → create group "Friends" → add build → add tester emails.** Add three people who aren't you. At least one who has never seen the app.

**What to watch for in a week:**
- Did the first-launch download work on their wifi?
- Did the mic permission make sense?
- Did the voice filter dim *their* words? (It shouldn't now, but this is the test.)
- Did anyone tap Show?
- Did it crash? Crashes show up in **TestFlight → Crashes** automatically.

Fix what you find. Re-archive, re-upload — new build number is automatic. Then submit.

---

## 5. Fill in the store page — App Store Connect, 30 minutes

**Your app → App Store tab → 1.0 Prepare for Submission.** Work down the page:

**Screenshots** — required. 6.9" iPhone (any recent Pro Max) and 6.5" (iPhone 11 Pro Max size). Take them on your real phone:
- Home screen with one transcribed sentence and the big Listen button
- Show screen with large text
- Settings

Four or five is plenty. No mockups, no text overlays — real screens only.

**Promotional text, Description, Keywords** — copy from `APP_STORE_CHECKLIST.md`. Keywords: `dysarthria, speech, transcription, accessibility, communication, cerebral palsy, ALS`

**Support URL** — your GitHub repo works. **Marketing URL** — the Hugging Face Space.

**Version** 1.0. **Copyright** `2026 Jingyu Lei`.

**App Review Information:**
- Contact: your name, phone, email
- **Notes** — paste the review notes from the checklist verbatim. This is where you tell the reviewer it's all on-device and how to test it.
- Sign-in required: **No**

**Version Release:** Manually release. (So it doesn't go live before you're ready.)

**Build** — click + and pick the TestFlight build.

---

## 6. Compliance questions — 10 minutes

**App Privacy** (left sidebar) → **Get Started**
- Does your app collect data? → **No, we do not collect data from this app.**
- Publish.

That matches `PrivacyInfo.xcprivacy`. If you ever add analytics, both change.

**Age Rating** → Edit → answer all **None** → 4+.

**Export Compliance** — asked at upload. "Does your app use encryption?" → **No** (HTTPS-only is exempt, and `ITSAppUsesNonExemptEncryption` is already `NO` in the project).

**Content Rights** → "No, it does not contain, show, or access third-party content."

---

## 7. Submit

**Add for Review → Submit.**

Status goes to **Waiting for Review** → **In Review** → **Ready for Distribution** (or Rejected with a note).

First reviews typically take 24–72 hours. If rejected, the reason is specific and you fix it — most first-time rejections are metadata, not code.

When it says Ready for Distribution, you release it manually. Then it's on the store within a few hours.

---

## If something fails

| Symptom | Fix |
|---|---|
| Archive greyed out | Select Any iOS Device, not a simulator |
| "No accounts with App Store Connect access" | Dad needs to accept the Program License Agreement at developer.apple.com/account |
| Upload fails with a bundle ID error | The ID in App Store Connect must exactly match `project.yml` — check for typos |
| Missing compliance / privacy error | Sections 6 above weren't completed |
| Rejected: "App is a demo / minimum functionality" | Reply in Resolution Center: all inference is on-device, no backend, fully offline after first launch. Cite `APP_STORE_CHECKLIST.md` §4.2. |
| Rejected: screenshots don't match | Retake them on the real device from the build you submitted |
