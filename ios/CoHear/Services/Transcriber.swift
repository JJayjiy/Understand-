import Foundation
import WhisperKit

/// On-device speech recognition using the CoHear fine-tuned Whisper model.
///
/// Nothing leaves the phone. The model is downloaded once from Hugging Face on
/// first launch (with a visible progress bar), cached in the app's container,
/// and run entirely on the Neural Engine via Core ML after that.
///
/// Model selection:
///   - `ModelSpec.cohear` is the fine-tuned model, once converted with
///     whisperkittools and pushed to `JJaysz/cohear-whisperkit`. See BUILD.md.
///   - `ModelSpec.stock` is Argmax's stock `small.en` — use it to get the app
///     running before the conversion is done, and to A/B against.
actor Transcriber {

    struct ModelSpec {
        let variant: String
        let repo: String?

        /// Fine-tuned CoHear model, once scripts/convert_whisperkit.sh has run.
        /// whisperkittools names the variant after the source repo with "/" -> "_".
        static let cohear = ModelSpec(variant: "JJaysz_cohear-whisper-small-merged",
                                      repo: "JJaysz/cohear-whisperkit")
        /// Stock Whisper small.en from Argmax — for development.
        static let stock = ModelSpec(variant: "small.en", repo: nil)
    }

    /// Models to try, in order. The fine-tuned CoHear model first; stock as a
    /// fallback so the app still works if the CoHear repo is unreachable or the
    /// conversion hasn't been pushed yet. Which one actually loaded is exposed
    /// via `loadedSpec` and shown in Settings, so nobody mistakes stock results
    /// for the research model.
    static let candidates: [ModelSpec] = [.cohear, .stock]

    private var pipe: WhisperKit?
    private(set) var loadedSpec: ModelSpec?

    var isReady: Bool { pipe != nil }

    /// Human-readable name of whichever model is running.
    var loadedName: String {
        guard let s = loadedSpec else { return "not loaded" }
        return s.repo == nil ? "Stock Whisper (small.en)" : "CoHear (adapted for dysarthria)"
    }

    func load(progress: @escaping (Double) -> Void) async throws {
        guard pipe == nil else { return }

        var lastError: Error?
        for spec in Self.candidates {
            do {
                // Two steps so the download shows real progress. A 500MB model
                // with a blank screen is exactly the first-launch experience that
                // loses people (and App Store reviewers). Cached after the first time.
                let repo = spec.repo ?? "argmaxinc/whisperkit-coreml"
                let folder = try await WhisperKit.download(
                    variant: spec.variant,
                    from: repo,
                    progressCallback: { p in progress(p.fractionCompleted) }
                )
                let config = WhisperKitConfig(modelFolder: folder.path, verbose: false, load: true)
                pipe = try await WhisperKit(config)
                loadedSpec = spec
                print("[CoHear] loaded model: \(spec.variant) from \(repo)")
                progress(1.0)
                return
            } catch {
                print("[CoHear] could not load \(spec.variant): \(error.localizedDescription) — trying next")
                lastError = error
            }
        }
        throw lastError ?? TranscriberError.notLoaded
    }

    /// Transcribe one utterance of 16 kHz mono samples.
    func transcribe(_ samples: [Float]) async throws -> String {
        guard let pipe else { throw TranscriberError.notLoaded }

        // Force English and disable auto language detection. Whisper routinely
        // misidentifies dysarthric English as another language and then
        // "transcribes" it in that language — the single most common way it
        // produces garbage on this population.
        let options = DecodingOptions(
            task: .transcribe,
            language: "en",
            temperature: 0.0,
            usePrefillPrompt: true,
            detectLanguage: false
        )

        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
    }

    enum TranscriberError: LocalizedError {
        case notLoaded
        var errorDescription: String? { "The speech model isn't loaded yet." }
    }
}
