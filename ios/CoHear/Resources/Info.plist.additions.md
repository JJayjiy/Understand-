# Info.plist — keys to add in Xcode

Xcode manages Info.plist through the target's **Info** tab. Add these rows there
(or paste the XML into a custom Info.plist if you switch to one).

| Key | Value |
|---|---|
| `NSMicrophoneUsageDescription` | `CoHear listens so it can show you what you said. Your voice is processed on this phone and never sent anywhere.` |
| `UIBackgroundModes` | *(leave empty — the app does not record in the background)* |
| `ITSAppUsesNonExemptEncryption` | `NO` |
| `UISupportedInterfaceOrientations` | Portrait, Landscape Left, Landscape Right |
| `UIRequiresFullScreen` | `NO` |
| `LSApplicationCategoryType` | `public.app-category.utilities` |

The microphone string is the one Apple's reviewer reads. It has to say **what** you're doing with the audio and be true. "Processed on this phone and never sent anywhere" is true of this build and is the single sentence that will matter most in review — don't shorten it to "needs mic access."

`ITSAppUsesNonExemptEncryption = NO` skips the export-compliance questionnaire on every upload. The app uses only HTTPS for the one-time model download, which is exempt.

## Deployment target

**iOS 17.0** minimum. WhisperKit requires iOS 16+; `AVAudioApplication.requestRecordPermission()` requires iOS 17. Clarify (Foundation Models) is gated at runtime to iOS 26 and Apple Intelligence devices, and degrades cleanly below that.

## Capabilities

None. No push, no background audio, no iCloud, no Sign in with Apple. The fewer entitlements you request, the less there is to review.
