import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns a raw transcript into a clear version plus a one-line "point",
/// using Apple's on-device language model. No network, no API key, no data
/// leaves the device.
///
/// Availability: Apple Intelligence devices on iOS 26+. Everywhere else,
/// `isAvailable` is false and the app simply shows the raw transcript — which
/// is still the whole product. Clarify is a layer, not a dependency.
///
/// The instructions are conservative on purpose. The model must never add
/// meaning that isn't there. A clarifier that "helpfully" completes someone's
/// sentence has put words in their mouth — the exact harm this app exists to
/// avoid. If the meaning is unclear, it says so.
final class Clarifier {

    struct Result {
        let clean: String
        let point: String
    }

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Why clarify is off, for the settings screen. Nil when available.
    var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return L("This iPhone doesn't support Apple Intelligence, so Clarify is off. Transcription still works.",
                         "这台 iPhone 不支持 Apple 智能，所以“整理”已关闭。语音转文字照常可用。")
            case .unavailable(.appleIntelligenceNotEnabled):
                return L("Turn on Apple Intelligence in Settings to enable Clarify.",
                         "在系统设置中打开 Apple 智能即可使用“整理”。")
            case .unavailable(.modelNotReady):
                return L("Apple Intelligence is still downloading. Clarify will turn on when it's ready.",
                         "Apple 智能还在下载中，下载完成后“整理”会自动打开。")
            case .unavailable:
                return L("Clarify isn't available on this device right now.", "这台设备目前无法使用“整理”。")
            }
        }
        #endif
        return L("Clarify needs iOS 26 or later.", "“整理”需要 iOS 26 或更高版本。")
    }

    private static let instructions = """
    You help listeners understand speech that is hard to understand — atypical speech, \
    stutters, heavy accents, or indirect and rambling speech.

    You will be given a raw transcript of something a person said. Do two things:

    1. CLEAN: rewrite it as clear, fluent text that preserves the speaker's exact meaning \
    and their own voice. Remove stutters, false starts, repeated words, and filler. \
    Never add information that is not in the transcript. Never guess at a word that is \
    unclear — leave it as [unclear] instead.

    2. POINT: in one short sentence, say what the speaker is trying to say or ask.

    If the meaning is genuinely unclear, say so plainly rather than inventing one. \
    You are helping a listener. You are not speaking for the person.
    """

    func clarify(_ raw: String, language: AppLanguage = .en) async throws -> Result {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            // Answer in the speaker's language; Simplified characters for Chinese.
            let lang = language == .zh
                ? "\n\nThe transcript is in Mandarin Chinese. Write CLEAN and POINT in Simplified Chinese."
                : ""
            let session = LanguageModelSession(instructions: Self.instructions + lang)
            let response = try await session.respond(
                to: "Transcript: \(raw)",
                generating: Clarified.self
            )
            return Result(clean: response.content.clean, point: response.content.point)
        }
        #endif
        throw ClarifierError.unavailable
    }

    enum ClarifierError: LocalizedError {
        case unavailable
        var errorDescription: String? { L("Clarify isn't available on this device.", "这台设备无法使用“整理”。") }
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct Clarified {
    @Guide(description: "The transcript rewritten as clear text with the same meaning. No added information.")
    var clean: String

    @Guide(description: "One short sentence: what the speaker is trying to say or ask.")
    var point: String
}
#endif
