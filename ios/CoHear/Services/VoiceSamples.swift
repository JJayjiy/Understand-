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
        /// "en" or "zh". Nil for recordings made before Chinese support (English).
        var lang: String?
    }

    enum Phase: Equatable { case idle, recording, review, playing }

    /// Every recording on the phone, both languages.
    @Published private(set) var allSamples: [Sample] = []
    /// Recordings in the current language — the only ones shown, counted, and
    /// trained on (the Mac build filters by the language in meta.json).
    var samples: [Sample] { allSamples.filter { ($0.lang ?? "en") == AppLanguage.current.rawValue } }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var level: Float = 0
    @Published var index: Int = 0
    @Published var speakerName: String {
        didSet { UserDefaults.standard.set(speakerName, forKey: "voiceSpeakerName") }
    }
    @Published var customPhrases: [String] {
        didSet { UserDefaults.standard.set(customPhrases, forKey: Self.customKey) }
    }
    /// Own phrases are kept per language.
    private static var customKey: String {
        AppLanguage.current == .zh ? "voiceCustomPhrases_zh" : "voiceCustomPhrases"
    }

    /// One take each. The quick start is built for coverage, not repetition.
    static let targetTakes = 1

    static let dir: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VoiceSamples", isDirectory: true)
    private var manifestURL: URL { Self.dir.appendingPathComponent("manifest.jsonl") }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private(set) var pendingURL: URL?

    // MARK: - Phrases

    /// Quick start first, then the user's own phrases, then everything else.
    var phrases: [String] {
        // Quick start, then the user's own phrases, then the rest without repeats
        // (some everyday phrases appear in both the quick start and the extras).
        var seen = Set<String>()
        return (Self.quickStart + customPhrases + Array(Self.prompts.dropFirst(Self.quickStart.count)))
            .filter { seen.insert($0.lowercased()).inserted }
    }
    var currentPhrase: String { phrases.isEmpty ? "" : phrases[index % phrases.count] }
    func takes(for text: String) -> Int { samples.filter { $0.text == text }.count }
    var phrasesDone: Int { phrases.filter { takes(for: $0) >= Self.targetTakes }.count }
    var quickStartDone: Int { Self.quickStart.filter { takes(for: $0) >= 1 }.count }
    var quickStartComplete: Bool { quickStartDone == Self.quickStart.count }
    var isQuickStartPhrase: Bool { Self.quickStart.contains(currentPhrase) }
    var totalMinutes: Double { samples.map(\.durationSec).reduce(0, +) / 60 }

    override init() {
        let d = UserDefaults.standard
        speakerName = d.string(forKey: "voiceSpeakerName") ?? ""
        customPhrases = d.stringArray(forKey: Self.customKey) ?? []
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

    enum KeepResult { case kept, tooShort, tooLong, failed }

    /// Whisper sees at most 30 s of audio at once; anything longer would be cut
    /// off mid-sentence during training and teach it the wrong thing.
    static let maxSeconds = 29.5

    /// Keep the take for the current phrase, unless it's too short to contain
    /// speech or too long for the model to learn from.
    @discardableResult
    func keep() -> KeepResult {
        stopPlayback()
        guard let src = pendingURL else { return .failed }
        let duration = (try? AVAudioFile(forReading: src)).map {
            Double($0.length) / $0.fileFormat.sampleRate
        } ?? 0
        guard duration >= 0.4 else { discardPending(); return .tooShort }
        guard duration <= Self.maxSeconds else { discardPending(); return .tooLong }

        let id = UUID()
        let name = "\(id.uuidString).wav"
        do {
            try FileManager.default.moveItem(at: src, to: Self.dir.appendingPathComponent(name))
        } catch {
            discardPending()
            return .failed
        }
        let s = Sample(id: id, file: name, text: currentPhrase, recordedAt: Date(), durationSec: duration,
                       lang: AppLanguage.current.rawValue)
        allSamples.append(s)
        appendToManifest(s)
        pendingURL = nil
        phase = .idle
        next()
        return .kept
    }

    func discardPending() {
        stopPlayback()
        if let u = pendingURL { try? FileManager.default.removeItem(at: u) }
        pendingURL = nil
        if phase != .recording { phase = .idle }
    }

    func delete(_ sample: Sample) {
        try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(sample.file))
        allSamples.removeAll { $0.id == sample.id }
        rewriteManifest()
    }

    /// Deletes every recording in the current language.
    func deleteAll() {
        let doomed = Set(samples.map(\.id))
        for s in samples { try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(s.file)) }
        allSamples.removeAll { doomed.contains($0.id) }
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
            + (AppLanguage.current == .zh ? "-zh" : "")
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
        allSamples = data.split(separator: "\n").compactMap {
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
        let lines = allSamples.compactMap { try? encoder.encode($0) }
            .compactMap { String(data: $0, encoding: .utf8) }
        try? (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n"))
            .write(to: manifestURL, atomically: true, encoding: .utf8)
        writeMeta()
    }

    private func writeMeta() {
        let meta: [String: Any] = [
            "speaker": speakerName,
            // The language being exported. build_personal_model.sh trains only on
            // recordings in this language and builds a model for it.
            "language": AppLanguage.current.rawValue,
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
            case .couldNotStart: return L("Couldn't start the microphone. Check that CoHear has microphone access.",
                                          "无法启动麦克风。请检查 CoHear 是否有麦克风权限。")
            case .exportFailed: return L("Couldn't package the recordings.", "无法打包录音。")
            }
        }
    }

    // MARK: - Built-in prompts

    /// The prompt set for the current language.
    static var quickStart: [String] { AppLanguage.current == .zh ? quickStartZh : quickStartEn }
    static var prompts: [String] { AppLanguage.current == .zh ? promptsZh : promptsEn }

    /// QUICK START: 32 short everyday phrases (2-7 words, 136 words total).
    ///
    /// Why short phrases instead of passages: our first real tester (post-stroke
    /// dysarthria) struggled to read long English sentences. Short phrases are
    /// easier to read, easy to repeat after "Hear it", and they are the things
    /// people actually say. Google's Project Euphonia used the same kind of
    /// prompts (home automation, caregiver, conversation), and its personalized
    /// models did best on the domains people recorded. So we record the domain
    /// we want to recognise: daily needs, care, and conversation.
    ///
    /// Still checked against the CMU pronouncing dictionary: every English sound
    /// appears, and all but "zh" (usually, pleasure) appear 3+ times.
    static let quickStartEn: [String] = [
        "Good morning",
        "How are you today",
        "I need some help",
        "Can I have some water",
        "I need to use the bathroom",
        "I'm tired, I want to lie down",
        "I'm hungry, what's for lunch",
        "Please wait, I'm not done",
        "Can you say that again",
        "I don't understand",
        "Turn on the TV",
        "Turn the noise down, please",
        "It's too cold in here",
        "Where are my glasses",
        "Call my daughter",
        "What time is it",
        "I feel sick",
        "My leg hurts",
        "Could you push my chair",
        "I'd like some orange juice",
        "I think so",
        "Thank you so much",
        "I love you",
        "Yes, that's right",
        "No, that's not what I said",
        "I usually watch the news",
        "Let's join them for dinner",
        "See you tomorrow",
        "Bring me a blanket",
        "Can I take a shower",
        "I enjoyed that show",
        "It was a pleasure",
    ]

    /// The original quick start: 5 passages, 103 words, every English consonant
    /// 3+ times and every vowel 2+ times. Now the first "Keep improving" items,
    /// for speakers who read comfortably.
    static let passagesLongEn: [String] = [
        "Good morning. I usually have toast with jam and a hot cup of coffee. Then I check the news on television.",
        "My brother Joe enjoys watching the big game with his loud, noisy friends. Would you please ask them to be quiet?",
        "Yesterday we took a long walk through the village. The yellow leaves were falling, and the air smelled fresh.",
        "Can you help me find my shoes? I think they are under the chair by the window, next to the red bag.",
        "Thank you for the beautiful birthday present. The measure of a good friend is how much they share their time.",
    ]

    /// KEEP IMPROVING: more passages. Optional — more speech keeps helping
    /// (TORGO learning curve: ~2 min -> 39%, ~14 min -> 75% on taught phrases).
    /// Short passages: 2-3 everyday sentences, ~20-25 words, so one tap
    /// captures a lot of natural speech. Kept short because Whisper learns from
    /// at most 30 seconds at a time and dysarthric speech is often slow. Together
    /// they cover the English consonants and vowels. Original wording.
    static let passages: [String] = [
        "My name is on the list by the front door. Please call me when the car is ready. I will be waiting outside.",
        "The weather was cold and windy this morning. I wore a thick jacket and warm gloves. Now I would like a cup of hot tea.",
        "Could you help me find my phone? I think I left it in the kitchen. It might be next to the fruit bowl.",
        "We went to the park on Saturday. The children played on the swings while the dog chased a yellow ball.",
        "I have a doctor's appointment next Tuesday at three. Can you drive me there? We should leave by two thirty.",
        "Please turn the music down a little. I am trying to read the newspaper. Thank you, that is much better.",
        "My favorite meal is chicken soup with fresh bread. My mother used to make it every Sunday.",
        "The judge asked the jury to think carefully. Each person shared their view. After an hour, they reached a decision.",
        "She sells shells by the shore in the summer. The shop is small but very busy. Visitors love the bright blue boxes.",
        "I feel a bit tired today, but I am okay. I would like to rest for a while. Maybe we can talk after lunch.",
        "Throw the old papers into the green bin. Then wash your hands with soap and warm water. Dinner will be ready soon.",
        "Yesterday I watched a movie about a zoo. A giraffe escaped and ran through the city. It was silly, but I laughed.",
    ]

    /// Short everyday phrases and sound-coverage sentences, for anyone who finds
    /// the passages too long, or whose passages run past 30 seconds.
    static let promptsEn: [String] = quickStartEn + passagesLongEn + passages + [
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

    // MARK: - Mandarin prompts

    /// QUICK START (普通话): 38 short everyday phrases (2-10 characters, 213
    /// total). Same reasoning as the English set. Checked with pypinyin: all 21
    /// initials appear 2+ times, every final (incl. ü, üe, üan, ün, er, iong,
    /// -i) at least once, and all four tones.
    static let quickStartZh: [String] = [
        "早上好",
        "你今天好吗",
        "我需要帮忙",
        "能给我一杯水吗",
        "我要上厕所",
        "我累了，想躺一会儿",
        "我饿了，中午吃什么",
        "请等一下，我还没说完",
        "你能再说一遍吗",
        "我没听懂",
        "把电视打开",
        "声音小一点",
        "这里太冷了",
        "我的眼镜在哪儿",
        "给我女儿打电话",
        "现在几点了",
        "我不舒服",
        "我的腿疼",
        "帮我推一下轮椅",
        "我想喝果汁",
        "我认识他",
        "非常感谢",
        "我爱你",
        "对，没错",
        "不对，我不是这个意思",
        "我想看新闻",
        "我们一起吃晚饭吧",
        "下个月见",
        "给我拿条毯子",
        "我想洗个澡",
        "这个节目真好看",
        "我想吃苹果",
        "我想去看外婆",
        "我有点头晕",
        "我用一下手机",
        "帮我开一下窗户",
        "我想去公园走走",
        "今天真热",
    ]

    /// The original Mandarin quick start: 5 passages, 143 characters, full
    /// initial/final/tone coverage. Now the first "Keep improving" items.
    static let passagesLongZh: [String] = [
        "早上好。我每天七点起床，先喝一杯热茶，再吃一个苹果和一碗粥。",
        "我女儿周末带孙子来看我。我们一起去公园散步，看小朋友踢足球，非常热闹。",
        "请帮我把窗户关上，外面风很大，有点冷。我想用手机给儿子打个电话。",
        "医生说我的血压正常，但是要多运动，少吃盐，晚上早点睡觉，心情要好。",
        "谢谢你送的生日礼物，我很喜欢。下次你来，我给你做红烧鱼，再炒一盘青菜。",
    ]

    /// KEEP IMPROVING (普通话): more short everyday passages, original wording.
    static let passagesZh: [String] = [
        "我的名字在门口的名单上。车准备好了请叫我，我在外面等。",
        "今天天气又冷又刮风。我穿了厚外套和手套，现在想喝一杯热水。",
        "你能帮我找一下手机吗？我好像放在厨房了，可能在水果盘旁边。",
        "星期六我们去了海边。孩子们在沙滩上玩，小狗追着黄色的球跑。",
        "我下星期二下午三点要看医生。你能开车送我去吗？我们两点半出发。",
        "请把电视声音关小一点，我在看报纸。谢谢，这样好多了。",
        "我最喜欢吃鸡汤面，以前妈妈每个星期天都给我们做。",
        "我今天有点累，不过没事。我想休息一会儿，吃完午饭再聊吧。",
        "把旧报纸扔进绿色的垃圾桶，然后用肥皂洗手。晚饭马上就好。",
        "昨天我看了一部关于熊猫的电影，它们吃竹子的样子特别可爱。",
        "春天来了，花园里的花都开了。爷爷每天早上给花浇水。",
        "我想去银行取钱，顺便去超市买点鸡蛋、牛奶和水果。",
    ]

    static let promptsZh: [String] = quickStartZh + passagesLongZh + passagesZh + [
        // 日常
        "是", "不是", "好的", "谢谢", "请",
        "我需要帮忙", "我没事", "我累了", "我饿了", "我渴了",
        "能给我一杯水吗", "我要上厕所", "请等一下",
        "你能再说一遍吗", "我没听懂", "我想回家",
        "把电视打开", "把灯关掉", "这里太冷了", "这里太热了",
        "给我妈妈打电话", "给我儿子打电话", "我的手机在哪里", "现在几点了",
        "我不舒服", "我这里疼", "我爱你", "回头见",
        "早上好", "晚安", "你好吗", "我今天挺好的",
        "我要吃药了", "帮我叫一下护士",
        // 数字和时间
        "一二三四五", "六七八九十",
        "二十块钱", "三点半", "下星期二中午",
    ]
}
