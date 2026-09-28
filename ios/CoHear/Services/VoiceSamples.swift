import Foundation
import AVFoundation

/// "Teach CoHear your voice": prompted recordings for a personal model.
///
/// WHY: a general model trained on other people's speech barely helps a new
/// severe speaker (TORGO leave-one-speaker-out, M04: 97% -> 85% sentence WER).
/// Dysarthric speech is hard for strangers but *consistent within a person* —
/// the same reason a parent understands what a stranger can't. A model that has
/// heard this person's voice can learn their mapping.
///
/// PRIVACY: recordings are 16 kHz mono WAV files in the app's own Documents
/// folder. Nothing is uploaded. They leave the phone only if the user taps
/// Export and chooses where to send them (AirDrop, Files, etc.), or copies the
/// folder via Finder. Delete removes the file.
///
/// Layout on disk:
///   Documents/VoiceSamples/
///     manifest.jsonl   one JSON object per kept recording
///     meta.json        speaker name, counts, format
///     <uuid>.wav
@MainActor
final class VoiceSamples: NSObject, ObservableObject, AVAudioPlayerDelegate {

    struct Sample: Codable, Identifiable, Equatable {
        let id: UUID
        let file: String
        let text: String
        let recordedAt: Date
        let durationSec: Double
    }

    enum Phase: Equatable { case idle, recording, review, playing }

    @Published private(set) var samples: [Sample] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var level: Float = 0
    @Published var index: Int = 0
    @Published var speakerName: String {
        didSet { UserDefaults.standard.set(speakerName, forKey: "voiceSpeakerName") }
    }
    @Published var customPhrases: [String] {
        didSet { UserDefaults.standard.set(customPhrases, forKey: "voiceCustomPhrases") }
    }

    /// Two takes of each phrase: one to learn from, one to check against.
    static let targetTakes = 2

    static let dir: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VoiceSamples", isDirectory: true)
    private var manifestURL: URL { Self.dir.appendingPathComponent("manifest.jsonl") }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private(set) var pendingURL: URL?

    // MARK: - Phrases

    /// The user's own phrases first — those are what they'll actually say.
    var phrases: [String] { customPhrases + Self.prompts }
    var currentPhrase: String { phrases.isEmpty ? "" : phrases[index % phrases.count] }
    func takes(for text: String) -> Int { samples.filter { $0.text == text }.count }
    var phrasesDone: Int { phrases.filter { takes(for: $0) >= Self.targetTakes }.count }
    var totalMinutes: Double { samples.map(\.durationSec).reduce(0, +) / 60 }

    override init() {
        let d = UserDefaults.standard
        speakerName = d.string(forKey: "voiceSpeakerName") ?? ""
        customPhrases = d.stringArray(forKey: "voiceCustomPhrases") ?? []
        super.init()
        try? FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        load()
        goToNextNeeded(startingAt: 0)
    }

    func next() { goToNextNeeded(startingAt: index + 1) }
    func previous() { index = (index - 1 + phrases.count) % max(phrases.count, 1) }

    /// Skip ahead to the next phrase that still needs takes.
    private func goToNextNeeded(startingAt start: Int) {
        let n = phrases.count
        guard n > 0 else { return }
        for k in 0..<n {
            let i = (start + k) % n
            if takes(for: phrases[i]) < Self.targetTakes { index = i; return }
        }
        index = start % n
    }

    func addPhrase(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !customPhrases.contains(t) else { return }
        customPhrases.insert(t, at: 0)
        index = 0
    }

    func removeCustomPhrase(_ text: String) {
        customPhrases.removeAll { $0 == text }
        index = min(index, max(phrases.count - 1, 0))
    }

    // MARK: - Recording

    func startRecording() throws {
        stopPlayback()
        discardPending()
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try s.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        // 16 kHz mono 16-bit PCM: exactly what Whisper and the training scripts expect.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        guard r.record() else { throw RecordError.couldNotStart }
        recorder = r
        pendingURL = url
        phase = .recording

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let r = self.recorder else { return }
                r.updateMeters()
                let db = r.averagePower(forChannel: 0)      // about -60 (silence) to 0 (loud)
                self.level = max(0, min(1, (db + 50) / 50))
            }
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
        phase = pendingURL == nil ? .idle : .review
    }

    func playPending() {
        guard let url = pendingURL else { return }
        play(url)
    }

    func play(_ sample: Sample) {
        play(Self.dir.appendingPathComponent(sample.file))
    }

    private func play(_ url: URL) {
        stopPlayback()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default,
                                                            options: [.defaultToSpeaker])
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            phase = .playing
        } catch {
            phase = pendingURL == nil ? .idle : .review
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        if phase == .playing { phase = pendingURL == nil ? .idle : .review }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.phase = self.pendingURL == nil ? .idle : .review
        }
    }

    /// Keep the take for the current phrase. Returns false if it was too short
    /// to be useful (a tap-and-release with no speech).
    @discardableResult
    func keep() -> Bool {
        stopPlayback()
        guard let src = pendingURL else { return false }
        let duration = (try? AVAudioFile(forReading: src)).map {
            Double($0.length) / $0.fileFormat.sampleRate
        } ?? 0
        guard duration >= 0.4 else { discardPending(); return false }

        let id = UUID()
        let name = "\(id.uuidString).wav"
        do {
            try FileManager.default.moveItem(at: src, to: Self.dir.appendingPathComponent(name))
        } catch {
            discardPending()
            return false
        }
        let s = Sample(id: id, file: name, text: currentPhrase, recordedAt: Date(), durationSec: duration)
        samples.append(s)
        appendToManifest(s)
        pendingURL = nil
        phase = .idle
        next()
        return true
    }

    func discardPending() {
        stopPlayback()
        if let u = pendingURL { try? FileManager.default.removeItem(at: u) }
        pendingURL = nil
        if phase != .recording { phase = .idle }
    }

    func delete(_ sample: Sample) {
        try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(sample.file))
        samples.removeAll { $0.id == sample.id }
        rewriteManifest()
    }

    func deleteAll() {
        for s in samples { try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(s.file)) }
        samples = []
        rewriteManifest()
        goToNextNeeded(startingAt: 0)
    }

    // MARK: - Export

    /// Zip the whole folder so it can be AirDropped to the Mac that trains the
    /// personal model. Uses the system's built-in folder zipping.
    func exportZip() throws -> URL {
        writeMeta()
        var coordError: NSError?
        var result: URL?
        var copyError: Error?
        let slug = speakerName.isEmpty ? "speaker"
            : speakerName.lowercased().filter { $0.isLetter || $0.isNumber }
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        NSFileCoordinator().coordinate(readingItemAt: Self.dir, options: .forUploading,
                                       error: &coordError) { zipURL in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("CoHear-voice-\(slug)-\(stamp).zip")
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: zipURL, to: dest)
                result = dest
            } catch { copyError = error }
        }
        if let e = coordError ?? (copyError as NSError?) { throw e }
        guard let r = result else { throw RecordError.exportFailed }
        return r
    }

    // MARK: - Persistence

    private var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }

    private func load() {
        guard let data = try? String(contentsOf: manifestURL, encoding: .utf8) else { return }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        samples = data.split(separator: "\n").compactMap {
            try? d.decode(Sample.self, from: Data($0.utf8))
        }.filter { FileManager.default.fileExists(atPath: Self.dir.appendingPathComponent($0.file).path) }
    }

    private func appendToManifest(_ s: Sample) {
        guard let line = try? encoder.encode(s), var str = String(data: line, encoding: .utf8) else { return }
        str += "\n"
        if let h = try? FileHandle(forWritingTo: manifestURL) {
            h.seekToEndOfFile(); h.write(Data(str.utf8)); try? h.close()
        } else {
            try? str.write(to: manifestURL, atomically: true, encoding: .utf8)
        }
        writeMeta()
    }

    private func rewriteManifest() {
        let lines = samples.compactMap { try? encoder.encode($0) }
            .compactMap { String(data: $0, encoding: .utf8) }
        try? (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n"))
            .write(to: manifestURL, atomically: true, encoding: .utf8)
        writeMeta()
    }

    private func writeMeta() {
        let meta: [String: Any] = [
            "speaker": speakerName,
            "count": samples.count,
            "minutes": (totalMinutes * 10).rounded() / 10,
            "sample_rate": 16000,
            "format": "wav pcm16 mono",
            "created": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
        ]
        if let d = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: Self.dir.appendingPathComponent("meta.json"))
        }
    }

    enum RecordError: LocalizedError {
        case couldNotStart, exportFailed
        var errorDescription: String? {
            switch self {
            case .couldNotStart: return "Couldn't start the microphone. Check that CoHear has microphone access."
            case .exportFailed: return "Couldn't package the recordings."
            }
        }
    }

    // MARK: - Built-in prompts

    /// Everyday phrases people actually need, plus sentences chosen to cover
    /// the English consonants and vowels, plus numbers. Original wording.
    static let prompts: [String] = [
        // Everyday
        "Yes", "No", "Maybe", "Thank you", "Please",
        "I need help", "I'm okay", "I'm tired", "I'm hungry", "I'm thirsty",
        "Can I have some water", "I need to use the bathroom", "Please wait a moment",
        "Can you say that again", "I don't understand", "I want to go home",
        "Turn on the TV", "Turn off the light", "It's too cold in here", "It's too hot in here",
        "Call my mom", "Call my dad", "Where is my phone", "What time is it",
        "I feel sick", "Something hurts", "I love you", "See you later",
        "Good morning", "Good night", "How are you", "I'm doing well today",
        // Sound coverage
        "The ship sailed past the rocky shore",
        "She keeps fresh cheese in the kitchen",
        "Bring the big blue box to the garage",
        "Five foxes jumped over the fence",
        "The judge gave a short speech at noon",
        "Put the thick book on the wooden shelf",
        "My brother likes pizza with extra sauce",
        "We went fishing by the quiet river",
        "Please pass the salt and pepper",
        "The yellow cat is sleeping on the chair",
        "Throw the ball through the open window",
        "Children played games in the park all day",
        "A warm cup of tea helps me relax",
        "The garden looks green after the rain",
        // Numbers and time
        "One two three four five",
        "Six seven eight nine ten",
        "Twenty dollars", "Half past three", "Next Tuesday at noon",
    ]
}
