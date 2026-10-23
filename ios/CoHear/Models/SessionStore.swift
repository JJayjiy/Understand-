import Foundation
import Combine

/// The two languages CoHear supports. Switching changes both the interface text
/// and what the recognizer listens for. Kept in UserDefaults so non-view code
/// (model titles, prompts, error messages) can read it without a reference to
/// the store.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case en, zh
    var id: String { rawValue }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .en
    }

    /// Shown in the picker in its own language, so anyone can find theirs.
    var nativeName: String { self == .zh ? "中文" : "English" }
    /// Whisper language code.
    var whisperCode: String { self == .zh ? "zh" : "en" }
    /// Apple speech recognizer and text-to-speech locale.
    var locale: String { self == .zh ? "zh-CN" : "en-US" }
}

/// Pick the string for the current language. Both versions sit side by side at
/// the call site, so nothing goes missing when one is edited.
func L(_ en: String, _ zh: String) -> String {
    AppLanguage.current == .zh ? zh : en
}

/// App state. One conversation at a time, held in memory.
///
/// Deliberately no persistence of transcripts across launches in v1. The product
/// promise is "nothing is stored", and the simplest way to keep that promise is
/// to not store it. Settings (font size, clarify on/off) are the only things saved.
@MainActor
final class SessionStore: ObservableObject {
    @Published var utterances: [Utterance] = []
    @Published var isListening = false
    @Published var isTranscribing = false
    @Published var modelState: ModelState = .notLoaded
    @Published var statusMessage: String = ""

    /// Live mic level (0...1) and whether the recorder currently reads speech.
    /// Shown on screen while listening: the user gets confirmation the mic is
    /// live, and any failure to hear them is visible rather than silent.
    @Published var level: Float = 0
    @Published var hearingSpeech = false

    // Settings — the only persisted state.
    @Published var textScale: Double {
        didSet { UserDefaults.standard.set(textScale, forKey: "textScale") }
    }
    @Published var clarifyEnabled: Bool {
        didSet { UserDefaults.standard.set(clarifyEnabled, forKey: "clarifyEnabled") }
    }
    /// When on, lines that don't sound like the speaker are dimmed and left out
    /// of Show and Speak. Never deletes anything.
    /// Which recognizer to run. Switching unloads the current model and
    /// downloads the new one if needed; the setup screen shows progress.
    @Published var modelChoice: Transcriber.ModelChoice {
        didSet { UserDefaults.standard.set(modelChoice.rawValue, forKey: "modelChoice") }
    }

    @Published var showConfidence: Bool {
        didSet { UserDefaults.standard.set(showConfidence, forKey: "showConfidence") }
    }

    @Published var filterOtherVoices: Bool {
        didSet { UserDefaults.standard.set(filterOtherVoices, forKey: "filterOtherVoices") }
    }

    /// Interface and recognition language. Change it with `setLanguage(_:)`,
    /// which also swaps to a model that understands that language.
    @Published private(set) var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    /// Home screen: speak and see it written down, or tap ready-made phrases.
    enum HomeMode: String { case talk, phrases }
    @Published private(set) var homeMode: HomeMode {
        didSet { UserDefaults.standard.set(homeMode.rawValue, forKey: "homeMode") }
    }

    func setHomeMode(_ mode: HomeMode) {
        guard mode != homeMode else { return }
        if isListening { stopListening() }
        speaker.stop()
        homeMode = mode
    }

    /// Whether the welcome screens have been seen. The model download waits
    /// until then, so it fetches the model for the language the user picked.
    @Published private(set) var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    let recorder = AudioRecorder()
    let transcriber = Transcriber()
    let clarifier = Clarifier()
    let speaker = Speaker()
    let voice = VoiceProfile()

    /// Fingerprints kept only for the current session, so a line can be
    /// re-assigned after the fact. Cleared with everything else.
    private var fingerprints: [UUID: VoiceFingerprint] = [:]

    private var cancellables = Set<AnyCancellable>()

    enum ModelState: Equatable {
        case notLoaded
        case downloading(Double)   // 0...1
        case loading
        case ready
        case failed(String)
    }

    init() {
        let d = UserDefaults.standard
        textScale = d.object(forKey: "textScale") as? Double ?? 1.0
        clarifyEnabled = d.object(forKey: "clarifyEnabled") as? Bool ?? true
        filterOtherVoices = d.object(forKey: "filterOtherVoices") as? Bool ?? true
        showConfidence = d.object(forKey: "showConfidence") as? Bool ?? true
        // Never start the app on large-v3: on a 6 GB iPhone it can exhaust memory
        // (iOS kills the app), and if it's the saved choice the app would crash on
        // every launch before the user can switch away. Large is a per-session
        // experiment you pick in Settings; launch always falls back to CoHear.
        language = AppLanguage.current
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        homeMode = HomeMode(rawValue: d.string(forKey: "homeMode") ?? "") ?? .talk
        let fallback = Transcriber.ModelChoice.defaultChoice
        let saved = Transcriber.ModelChoice(rawValue: d.string(forKey: "modelChoice") ?? "") ?? fallback
        // Also fall back if the saved model doesn't support the current language
        // (e.g. CoHear, which only knows English).
        modelChoice = (saved == .large || !Transcriber.ModelChoice.available.contains(saved)) ? fallback : saved

        // Every time the recorder finishes a speech segment, transcribe it.
        recorder.onSegment = { [weak self] samples in
            Task { await self?.handleSegment(samples) }
        }

        recorder.onLevel = { [weak self] rms, speech in
            Task { @MainActor in
                // Scale for display: normal speech sits well under 0.1 raw.
                self?.level = min(rms * 12, 1.0)
                self?.hearingSpeech = speech
            }
        }

        // Speaker is its own ObservableObject; forward its changes so views that
        // read `session.speaker.isSpeaking` re-render when speech starts/stops.
        speaker.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Model

    /// Load on first use, or try again after a failure (the Try again button).
    func loadModelIfNeeded() async {
        switch modelState {
        case .notLoaded, .failed: break
        default: return
        }
        await loadModel(modelChoice)
    }

    /// Switch recognizers. Stops listening first — a segment landing mid-swap
    /// would go nowhere. Falls back to whatever loaded if the choice fails.
    func switchModel(to choice: Transcriber.ModelChoice) async {
        if isListening { stopListening() }
        modelChoice = choice
        await loadModel(choice)
    }

    /// Switch the whole app between English and Chinese. Stops listening, then
    /// loads a model that understands the new language (keeping the current
    /// one if it does, e.g. large-v3 or Apple dictation).
    func setLanguage(_ new: AppLanguage) async {
        guard new != language else { return }
        if isListening { stopListening() }
        speaker.stop()
        language = new
        statusMessage = ""
        let choice = Transcriber.ModelChoice.available.contains(modelChoice)
            ? modelChoice : Transcriber.ModelChoice.defaultChoice
        modelChoice = choice
        // During the welcome screens nothing is loaded yet: just remember the
        // choice, and the first load will fetch the right model.
        guard modelState != .notLoaded else { return }
        await loadModel(choice)
    }

    /// End of the welcome screens: remember it, then start the model download.
    func finishOnboarding() {
        hasOnboarded = true
        Task { await loadModelIfNeeded() }
    }

    /// A line the speaker typed instead of said. Treated as theirs and certain.
    func addTyped(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var u = Utterance(raw: t)
        u.voice = .own
        u.voiceConfirmedByUser = true
        utterances.append(u)
    }

    private func loadModel(_ choice: Transcriber.ModelChoice) async {
        modelState = .loading
        do {
            try await transcriber.load(choice, language: language) { [weak self] progress in
                Task { @MainActor in self?.modelState = .downloading(progress) }
            }
            // The transcriber may have fallen back to stock small; reflect that
            // so Settings never claims a model that isn't running.
            if let actual = await transcriber.loadedChoice, actual != choice {
                modelChoice = actual
                statusMessage = L("Couldn't load \(choice.title); using \(actual.title).",
                                  "无法加载\(choice.title)，改用\(actual.title)。")
            }
            modelState = .ready
        } catch {
            // A comparison model that won't load shouldn't strand the user on
            // an error screen. Say what happened and go back to the default.
            let fallback = Transcriber.ModelChoice.defaultChoice
            if choice != fallback {
                statusMessage = L("\(choice.title) isn't available: \(error.localizedDescription)",
                                  "\(choice.title)暂时不可用：\(error.localizedDescription)")
                modelChoice = fallback
                await loadModel(fallback)
            } else {
                modelState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Listening

    func startListening() async {
        await loadModelIfNeeded()
        guard modelState == .ready else { return }
        do {
            try await recorder.start()
            isListening = true
            statusMessage = L("Listening", "正在听")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stopListening() {
        recorder.stop()
        isListening = false
        statusMessage = ""
        level = 0
        hearingSpeech = false
    }

    private func handleSegment(_ samples: [Float]) async {
        isTranscribing = true
        defer { isTranscribing = false }

        // Fingerprint before transcribing — it's cheap, and we want it even if
        // recognition comes back empty.
        let print_ = VoiceFingerprint.extract(from: samples)

        do {
            let result = try await transcriber.transcribe(samples)
            let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Whisper is confident there was no speech but wrote something
            // anyway — that text is invented. Drop it rather than show it.
            if result.noSpeechProb > 0.8 && result.avgLogprob < -1.0 { return }

            var u = Utterance(raw: trimmed)
            u.avgLogprob = result.avgLogprob
            u.compressionRatio = result.compressionRatio

            if let fp = print_ {
                fingerprints[u.id] = fp
                if let verdict = voice.classify(fp) {
                    u.voice = verdict
                    // Only clearly-own lines feed the reference. Uncertain ones
                    // are shown but don't teach the profile, so one odd line
                    // can't drag the centroid toward the other person.
                    if verdict == .own { voice.confirm(fp) }
                } else {
                    // Warm-up: the first few things said after tapping Listen
                    // become the reference. The speaker is holding the phone,
                    // so this is nearly always them — and if it isn't, one tap
                    // on any line re-anchors everything.
                    voice.confirm(fp)
                    u.voice = .own
                }
            }

            if clarifyEnabled, clarifier.isAvailable {
                if let result = try? await clarifier.clarify(trimmed, language: language) {
                    u.clean = result.clean
                    u.point = result.point
                }
            }
            utterances.append(u)
        } catch {
            statusMessage = L("Couldn't transcribe that — try again.", "没能识别这句话，请再试一次。")
        }
    }

    // MARK: - Voice assignment

    /// The speaker correcting us. Flipping a line to "mine" re-anchors the whole
    /// profile on it, because being wrong here usually means we latched onto the
    /// wrong person at the start of the conversation.
    func setOwnVoice(_ id: UUID, isOwn: Bool) {
        guard let i = utterances.firstIndex(where: { $0.id == id }) else { return }
        utterances[i].voice = isOwn ? .own : .other
        utterances[i].voiceConfirmedByUser = true
        guard let fp = fingerprints[id] else { return }

        if isOwn {
            // Rebuild the reference from every line the speaker has confirmed
            // as theirs, with this one first. Then re-score only the lines the
            // speaker hasn't personally ruled on.
            voice.reanchor(to: fp)
            for u in utterances where u.id != id && u.voiceConfirmedByUser && u.voice == .own {
                if let other = fingerprints[u.id] { voice.confirm(other) }
            }
            for j in utterances.indices where !utterances[j].voiceConfirmedByUser {
                if let other = fingerprints[utterances[j].id] {
                    utterances[j].voice = voice.classify(other) ?? .own
                }
            }
        }
    }

    /// Lines to include in Show and Speak. Only lines that are *clearly* another
    /// voice are left out. Uncertain ones stay in — hiding the speaker's own
    /// words by mistake is the error we refuse to make.
    var visibleUtterances: [Utterance] {
        guard filterOtherVoices else { return utterances }
        return utterances.filter { $0.voice != .other }
    }

    // MARK: - Editing

    func update(_ id: UUID, text: String) {
        guard let i = utterances.firstIndex(where: { $0.id == id }) else { return }
        utterances[i].edited = text
    }

    func delete(_ id: UUID) {
        utterances.removeAll { $0.id == id }
        fingerprints[id] = nil
    }

    func clearAll() {
        utterances.removeAll()
        fingerprints.removeAll()
        voice.reset()
    }

    /// Everything the speaker said this session, in order, as they approved it.
    /// Other people's lines are left out — this is the speaker's transcript.
    var fullText: String {
        visibleUtterances.map(\.text).joined(separator: language == .zh ? "" : " ")
    }
}

// MARK: - Previews

#if DEBUG
extension SessionStore {
    /// A store pre-filled for Xcode's preview canvas. Model marked ready so
    /// the view never tries to download anything.
    static func preview(empty: Bool = false, listening: Bool = false) -> SessionStore {
        let s = SessionStore()
        s.hasOnboarded = true
        s.modelState = .ready
        s.isListening = listening
        s.hearingSpeech = listening
        s.level = listening ? 0.55 : 0
        if !empty {
            var a = Utterance(raw: "Can we go to the park after lunch")
            var b = Utterance(raw: "I want the blue one")
            var c = Utterance(raw: "Sure, let me grab my keys")
            c.voice = .other
            var d = Utterance(raw: "Not that one, the other one")
            d.voice = .uncertain
            var e = Utterance(raw: "So things that you then chase you down the chinky chair")
            e.voice = .own; e.avgLogprob = -1.3
            b.avgLogprob = -0.3; a.avgLogprob = -0.7
            b.voice = .own; a.voice = .own
            s.utterances = [a, c, b, d, e]
        }
        return s
    }
}
#endif
