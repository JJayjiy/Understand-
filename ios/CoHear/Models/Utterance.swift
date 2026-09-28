import Foundation

/// One thing the speaker said.
///
/// `raw` is what the recognizer heard. `clean` is the clarified version, if the
/// speaker asked for one. `text` is whichever the speaker chose to keep — they can
/// edit either, and the edited version always wins. Nothing here is ever sent
/// anywhere; it lives in memory and in the app's private sandbox only.
struct Utterance: Identifiable, Equatable, Codable {
    let id: UUID
    let createdAt: Date
    var raw: String
    var clean: String?
    var point: String?
    var edited: String?

    /// Whether this sounded like the person holding the phone. Nil means the app
    /// had nothing to compare against yet, or the clip was too short to judge.
    /// Never used to delete anything — only to dim it, and always correctable.
    var voice: VoiceMatch?

    /// Lines the speaker has personally confirmed or corrected. These are never
    /// re-scored automatically — the speaker's word beats the classifier's.
    var voiceConfirmedByUser = false

    /// How sure the recognizer was, as Whisper's mean token log-probability.
    /// Nil for lines typed or edited by hand. See `confidence`.
    var avgLogprob: Float?
    /// gzip ratio of the raw text; high values mean the model looped.
    var compressionRatio: Float?

    enum Confidence { case high, medium, low }

    /// Three bands, so the UI can be honest about a guess without turning
    /// every line into a number. Thresholds follow Whisper's own fallback
    /// logic (logprob -1.0, compression 2.4) with a middle band above it.
    /// An edited line is always high — the speaker said so.
    var confidence: Confidence {
        if let edited, !edited.isEmpty { return .high }
        guard let lp = avgLogprob else { return .high }
        if let cr = compressionRatio, cr > 2.4 { return .low }
        if lp < -1.0 { return .low }
        if lp < -0.55 { return .medium }
        return .high
    }

    init(raw: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.raw = raw
    }

    /// What to display and speak. Edited > clean > raw.
    var text: String {
        if let edited, !edited.isEmpty { return edited }
        if let clean, !clean.isEmpty { return clean }
        return raw
    }

    var isClarified: Bool { clean != nil }
}
