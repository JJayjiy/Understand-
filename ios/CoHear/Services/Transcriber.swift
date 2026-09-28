import Foundation
import WhisperKit

/// On-device speech recognition.
///
/// Nothing leaves the phone. Models are downloaded once from Hugging Face
/// (with a visible progress bar), cached in the app's container, and run on
/// the Neural Engine via Core ML after that.
///
/// Several models are selectable in Settings so the same speaker can be A/B'd
/// on the same phone. The fine-tuned model was trained on eight TORGO
/// speakers; on a person it has never heard, stock large-v3 may do better.
/// That is an empirical question and the picker exists to answer it.
actor Transcriber {

    enum ModelChoice: String, CaseIterable, Codable, Identifiable {
        case personal, cohear, small, large, apple
        var id: String { rawValue }

        /// The personal model only appears once one has been installed.
        static var available: [ModelChoice] {
            allCases.filter { $0 != .personal || PersonalModel.isInstalled }
        }

        var title: String {
            switch self {
            case .personal: return "Your voice" + (PersonalModel.name.map { " (\($0))" } ?? "")
            case .cohear: return "CoHear (adapted for dysarthria)"
            case .small:  return "Whisper small.en (stock)"
            case .large:  return "Whisper large-v3 turbo (stock)"
            case .apple:  return "Apple dictation (built in)"
            }
        }
        var note: String {
            switch self {
            case .personal: return "Trained on your own recordings from Teach CoHear your voice. In testing on four speakers, about 15 minutes of someone's recordings roughly doubled accuracy, even on words they never recorded."
            case .cohear: return "Whisper small fine-tuned on eight adults with cerebral palsy and ALS (TORGO). Best on speech like theirs; unproven on speakers it hasn't heard. ~500 MB."
            case .small:  return "The same base model without the adaptation. Useful to see what the fine-tuning changed. ~500 MB."
            case .large:  return "OpenAI's largest model, distilled. Has heard far more varied speech in pretraining and may do better on a new speaker. Slower — a few seconds per line. ~1.5 GB download."
            case .apple:  return "The recognizer behind iOS dictation, run on-device. The baseline everyone already has. No download."
            }
        }
        /// Nil for the Apple path and the personal model (loaded from a local folder).
        var spec: ModelSpec? {
            switch self {
            case .personal: return nil
            case .cohear: return .cohear
            case .small:  return .stockSmall
            case .large:  return .stockLarge
            case .apple:  return nil
            }
        }
    }

    struct ModelSpec: Equatable {
        let variant: String
        let repo: String?

        static let cohear = ModelSpec(variant: "JJaysz_cohear-whisper-small-merged",
                                      repo: "JJaysz/cohear-whisperkit")
        static let stockSmall = ModelSpec(variant: "openai_whisper-small.en", repo: nil)
        static let stockLarge = ModelSpec(variant: "openai_whisper-large-v3-v20240930_turbo", repo: nil)
    }

    /// What the recognizer produced for one segment of audio, with how sure it was.
    struct Result {
        let text: String
        /// Mean log-probability of the decoded tokens, weighted by segment length.
        /// Whisper's own fallback threshold is -1.0. Roughly: above -0.5 the
        /// model was confident; -0.5 to -1.0 it was guessing some words;
        /// below -1.0 it was mostly making up plausible English.
        let avgLogprob: Float
        /// gzip ratio of the text. Above ~2.4 means repetition — a hallucination tell.
        let compressionRatio: Float
        let noSpeechProb: Float
    }

    private var pipe: WhisperKit?
    private let apple = AppleRecognizer()
    private(set) var loadedSpec: ModelSpec?
    private(set) var loadedChoice: ModelChoice?

    var isReady: Bool { pipe != nil || loadedChoice == .apple }

    var loadedName: String {
        loadedChoice?.title ?? "not loaded"
    }

    /// Load `choice`, falling back to stock small if it can't be fetched, so the
    /// app still works if the CoHear repo is unreachable. Which one actually
    /// loaded is exposed and shown in Settings, so nobody mistakes stock results
    /// for the research model.
    func load(_ choice: ModelChoice, progress: @escaping (Double) -> Void) async throws {
        if loadedChoice == choice, isReady { return }
        pipe = nil
        loadedSpec = nil
        loadedChoice = nil

        if choice == .apple {
            guard await apple.isAvailable else { throw AppleRecognizer.Error.unavailable }
            guard await apple.requestAuthorization() else { throw AppleRecognizer.Error.notAuthorized }
            loadedChoice = .apple
            print("[CoHear] using Apple on-device recognizer")
            progress(1.0)
            return
        }

        if choice == .personal {
            guard PersonalModel.isInstalled else { throw TranscriberError.noPersonalModel }
            progress(0.5)
            let config = WhisperKitConfig(modelFolder: PersonalModel.folder.path, verbose: false, load: true)
            pipe = try await WhisperKit(config)
            loadedChoice = .personal
            print("[CoHear] loaded personal model from \(PersonalModel.folder.path)")
            progress(1.0)
            return
        }

        var order: [ModelChoice] = [choice]
        if choice != .small { order.append(.small) }

        var lastError: Error?
        for c in order {
            guard let spec = c.spec else { continue }
            do {
                // Two steps so the download shows real progress. A blank screen
                // for a 500 MB (or 1.5 GB) download is how people decide an app
                // is broken. Cached after the first time.
                let repo = spec.repo ?? "argmaxinc/whisperkit-coreml"
                let folder = try await WhisperKit.download(
                    variant: spec.variant,
                    from: repo,
                    progressCallback: { p in progress(p.fractionCompleted) }
                )
                let config = WhisperKitConfig(modelFolder: folder.path, verbose: false, load: true)
                pipe = try await WhisperKit(config)
                loadedSpec = spec
                loadedChoice = c
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
    func transcribe(_ samples: [Float]) async throws -> Result {
        if loadedChoice == .apple { return try await apple.transcribe(samples) }
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
        let segments = results.flatMap(\.segments)
        // Repetition guard: collapse runaway loops ("what what what what...") to one
        // copy. The loop still shows up in compressionRatio, so the line is flagged
        // as uncertain; the reader just doesn't have to wade through it.
        let text = Self.collapseRepeats(results.map(\.text).joined(separator: " "))

        // Length-weighted mean so one short confident "Yeah." doesn't mask a
        // long guessed sentence.
        var weighted: Float = 0, total: Float = 0
        var maxCR: Float = 0, minNoSpeech: Float = 1
        for s in segments {
            let w = Float(max(s.tokens.count, 1))
            weighted += s.avgLogprob * w
            total += w
            maxCR = max(maxCR, s.compressionRatio)
            minNoSpeech = min(minNoSpeech, s.noSpeechProb)
        }
        let avg = total > 0 ? weighted / total : -2.0

        print(String(format: "[CoHear] segment %.1fs  logprob %.2f  cr %.2f  nospeech %.2f  \"%@\"",
                     Float(samples.count) / 16000, avg, maxCR, minNoSpeech, text))

        return Result(text: text, avgLogprob: avg, compressionRatio: maxCR, noSpeechProb: minNoSpeech)
    }

    /// Any 1-4 word phrase repeated 3+ times in a row becomes one copy.
    /// "its easy its easy its easy" -> "its easy". Natural doubles ("really really") survive.
    /// Same rule as scripts/eval_whisper.py --guard.
    static func collapseRepeats(_ text: String, maxN: Int = 4, minReps: Int = 3) -> String {
        var words = text.split(separator: " ").map(String.init)
        var changed = true
        while changed {
            changed = false
            for n in 1...maxN {
                var out: [String] = []
                var i = 0
                while i < words.count {
                    guard i + n <= words.count else { out.append(words[i]); i += 1; continue }
                    let chunk = Array(words[i..<(i + n)])
                    var reps = 1
                    while i + (reps + 1) * n <= words.count,
                          Array(words[(i + reps * n)..<(i + (reps + 1) * n)]) == chunk {
                        reps += 1
                    }
                    if reps >= minReps {
                        out += chunk
                        i += reps * n
                        changed = true
                    } else {
                        out.append(words[i])
                        i += 1
                    }
                }
                words = out
            }
        }
        return words.joined(separator: " ")
    }

    enum TranscriberError: LocalizedError {
        case notLoaded, noPersonalModel
        var errorDescription: String? {
            switch self {
            case .notLoaded: return "The speech model isn't loaded yet."
            case .noPersonalModel: return "No personal model is installed on this phone yet."
            }
        }
    }
}
