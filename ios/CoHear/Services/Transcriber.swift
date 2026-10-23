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

        /// Models that understand the current language. The personal model only
        /// appears once one for this language has been installed; CoHear's
        /// TORGO model only knows English.
        static var available: [ModelChoice] {
            let lang = AppLanguage.current
            return allCases.filter { c in
                switch c {
                case .personal: return PersonalModel.isInstalled && PersonalModel.language == lang
                case .cohear: return lang == .en
                default: return true
                }
            }
        }

        /// What a fresh install (or a language switch) starts on.
        static var defaultChoice: ModelChoice {
            AppLanguage.current == .zh ? .small : .cohear
        }

        var title: String {
            let zh = AppLanguage.current == .zh
            switch self {
            case .personal: return L("Your voice", "你的声音") + (PersonalModel.name.map { " (\($0))" } ?? "")
            case .cohear: return "CoHear (adapted for dysarthria)"
            case .small:  return zh ? "Whisper small（标准版）" : "Whisper small.en (stock)"
            case .large:  return L("Whisper large-v3 turbo (stock)", "Whisper large-v3 turbo（标准版）")
            case .apple:  return L("Apple dictation (built in)", "苹果听写（系统自带）")
            }
        }
        var note: String {
            switch self {
            case .personal: return L("Trained on your own recordings from Teach CoHear your voice. In testing on four speakers, about 15 minutes of someone's recordings roughly doubled accuracy, even on words they never recorded.",
                                     "用你在“教 CoHear 认识你的声音”里的录音训练。在四位说话人的测试中，大约 15 分钟的录音让准确率提高了约一倍，连没录过的句子也是。")
            case .cohear: return "Whisper small fine-tuned on eight adults with cerebral palsy and ALS (TORGO). Best on speech like theirs; unproven on speakers it hasn't heard. ~500 MB."
            case .small:  return L("The same base model without the adaptation. Useful to see what the fine-tuning changed. ~500 MB.",
                                   "OpenAI 的多语言模型，没有针对构音障碍调整。个人模型就是在它的基础上训练的，适合用来对比。约 500 MB。")
            case .large:  return L("OpenAI's largest model, distilled. Has heard far more varied speech in pretraining and may do better on a new speaker. Slower, and heavy on memory: may be closed by iOS on 6 GB iPhones. Not kept after the app restarts. ~630 MB download.",
                                   "OpenAI 最大的模型（精简版）。训练时听过更多样的语音，对新说话人可能更准。比较慢，占内存多：在 6 GB 内存的 iPhone 上可能被系统关闭。重启 app 后不会保留。下载约 630 MB。")
            case .apple:  return L("The recognizer behind iOS dictation, run on-device. The baseline everyone already has. No download.",
                                   "iOS 听写用的识别器，在手机上运行。人人都有的基准。无需下载。")
            }
        }
        /// Nil for the Apple path and the personal model (loaded from a local folder).
        /// Stock small is the English-only build for English and the multilingual
        /// one for Chinese (the same base the personal model is trained from).
        func spec(for language: AppLanguage) -> ModelSpec? {
            switch self {
            case .personal: return nil
            case .cohear: return .cohear
            case .small:  return language == .zh ? .stockSmallMultilingual : .stockSmall
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
        static let stockSmallMultilingual = ModelSpec(variant: "openai_whisper-small", repo: nil)
        // Argmax's compressed build of large-v3 turbo, made for iPhone memory limits.
        // The full ~1.6 GB variant got the app killed for memory on a 6 GB iPhone.
        static let stockLarge = ModelSpec(variant: "openai_whisper-large-v3-v20240930_turbo_632MB", repo: nil)
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
    private var apple = AppleRecognizer()
    private(set) var loadedSpec: ModelSpec?
    private(set) var loadedChoice: ModelChoice?
    private(set) var language: AppLanguage = .en

    var isReady: Bool { pipe != nil || loadedChoice == .apple }

    var loadedName: String {
        loadedChoice?.title ?? "not loaded"
    }

    /// Load `choice`, falling back to stock small if it can't be fetched, so the
    /// app still works if the CoHear repo is unreachable. Which one actually
    /// loaded is exposed and shown in Settings, so nobody mistakes stock results
    /// for the research model.
    func load(_ choice: ModelChoice, language: AppLanguage,
              progress: @escaping (Double) -> Void) async throws {
        // Same model, same language: nothing to do. A language switch on a
        // Whisper model only changes decoding options, but the stock small
        // build differs per language, so reload to be safe and simple.
        if loadedChoice == choice, self.language == language, isReady { return }
        self.language = language
        pipe = nil
        loadedSpec = nil
        loadedChoice = nil

        if choice == .apple {
            apple = AppleRecognizer(locale: language.locale)
            guard await apple.isAvailable else { throw AppleRecognizer.Error.unavailable }
            guard await apple.requestAuthorization() else { throw AppleRecognizer.Error.notAuthorized }
            loadedChoice = .apple
            print("[CoHear] using Apple on-device recognizer")
            progress(1.0)
            return
        }

        if choice == .personal {
            guard PersonalModel.isInstalled, PersonalModel.language == language else { throw TranscriberError.noPersonalModel }
            progress(0.5)
            let config = WhisperKitConfig(modelFolder: PersonalModel.slot(for: language).path, verbose: false, load: true)
            pipe = try await WhisperKit(config)
            loadedChoice = .personal
            print("[CoHear] loaded personal model from \(PersonalModel.slot(for: language).path)")
            progress(1.0)
            return
        }

        var order: [ModelChoice] = [choice]
        if choice != .small { order.append(.small) }

        var lastError: Error?
        for c in order {
            guard let spec = c.spec(for: language) else { continue }
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

        // Force the chosen language and disable auto detection. Whisper routinely
        // misidentifies dysarthric speech as another language and then
        // "transcribes" it in that language — the single most common way it
        // produces garbage on this population.
        let options = DecodingOptions(
            task: .transcribe,
            language: language.whisperCode,
            temperature: 0.0,
            usePrefillPrompt: true,
            detectLanguage: false
        )

        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
        let segments = results.flatMap(\.segments)
        // Repetition guard: collapse runaway loops ("what what what what...") to one
        // copy. The loop still shows up in compressionRatio, so the line is flagged
        // as uncertain; the reader just doesn't have to wade through it.
        let text = Self.cleanup(results.map(\.text).joined(separator: " "), language: language)

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

    /// Post-processing for display. English: collapse word loops, drop leading
    /// junk. Chinese: Whisper mixes Traditional and Simplified characters, so
    /// convert everything to Simplified; drop the spaces Whisper puts between
    /// segments; collapse character loops ("我我我我我" -> "我").
    static func cleanup(_ raw: String, language: AppLanguage) -> String {
        switch language {
        case .en:
            return stripLeadingJunk(collapseRepeats(raw))
        case .zh:
            var t = raw.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? raw
            t = t.replacingOccurrences(of: "(?<=\\p{Han})\\s+(?=\\p{Han})", with: "",
                                       options: .regularExpression)
            // Characters are the units; a doubled character ("谢谢") is normal,
            // so require 4+ repeats of a single character before collapsing.
            let chars = t.map(String.init)
            t = collapseTokens(chars, maxN: 6, minReps: 4).joined()
            return String(t.drop(while: { !$0.isLetter && !$0.isNumber }))
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// Small personal models sometimes start with stray tokens ("'s!'s.!! hello").
    /// Drop punctuation-only words at the start; keep everything from the first real word.
    static func stripLeadingJunk(_ text: String) -> String {
        let words = text.split(separator: " ")
        guard let i = words.firstIndex(where: { w in
            w.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count >= 2
                || w.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) } && w.count > 1
                || ["I", "a", "A"].contains(w.trimmingCharacters(in: .punctuationCharacters))
        }) else { return text }
        return words[i...].joined(separator: " ")
    }

    /// Any 1-4 word phrase repeated 3+ times in a row becomes one copy.
    /// "its easy its easy its easy" -> "its easy". Natural doubles ("really really") survive.
    /// Same rule as scripts/eval_whisper.py --guard.
    static func collapseRepeats(_ text: String, maxN: Int = 4, minReps: Int = 3) -> String {
        collapseTokens(text.split(separator: " ").map(String.init), maxN: maxN, minReps: minReps)
            .joined(separator: " ")
    }

    /// Any run of 1...maxN tokens repeated minReps+ times in a row becomes one copy.
    static func collapseTokens(_ tokens: [String], maxN: Int, minReps: Int) -> [String] {
        var words = tokens
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
        return words
    }

    enum TranscriberError: LocalizedError {
        case notLoaded, noPersonalModel
        var errorDescription: String? {
            switch self {
            case .notLoaded: return L("The speech model isn't loaded yet.", "语音模型还没加载好。")
            case .noPersonalModel: return L("No personal model is installed on this phone yet.", "这台手机上还没有安装个人模型。")
            }
        }
    }
}
