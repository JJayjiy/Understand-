import AVFoundation
import Foundation

/// Captures the microphone and splits it into speech segments at pauses.
///
/// Why segment at pauses and not on a timer: Whisper is built to see a complete
/// utterance. Cutting audio every N seconds slices words in half and produces
/// confident nonsense. Waiting for silence means every chunk handed to the model
/// is a whole thing the person said.
///
/// The VAD here is deliberately simple — RMS energy against an adaptive noise
/// floor. It runs in microseconds, needs no model, and is good enough for a
/// person speaking into a phone at arm's length. If it proves too crude in real
/// rooms, the next step is Silero VAD, not a smarter threshold.
final class AudioRecorder {

    /// Called on a background thread with 16 kHz mono samples of one utterance.
    var onSegment: (([Float]) -> Void)?

    // Tunables. Units are seconds unless noted.
    private let targetRate: Double = 16_000
    private let silenceToEnd: Double = 0.9        // pause length that ends an utterance
    private let minSpeech: Double = 0.4           // shorter than this is a click, not a word
    private let maxSegment: Double = 28.0         // hard cap; Whisper's window is 30s
    private let preRoll: Double = 0.3             // audio kept from before speech was detected
    private let speechFactor: Float = 3.0         // speech = this many × the noise floor

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let queue = DispatchQueue(label: "cohear.audio", qos: .userInitiated)

    // VAD state — only touched on `queue`.
    private var noiseFloor: Float = 0.005
    private var inSpeech = false
    private var silentFor: Double = 0
    private var speechFor: Double = 0
    private var current: [Float] = []
    private var ring: [Float] = []                // pre-roll buffer

    private(set) var isRunning = false

    // MARK: - Control

    func start() async throws {
        guard !isRunning else { return }

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: targetRate,
                                            channels: 1, interleaved: false),
              let conv = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw RecorderError.formatUnavailable
        }
        converter = conv
        resetState()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            self?.queue.async { self?.ingest(buffer, outFormat: outFormat) }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        queue.async { [weak self] in
            guard let self else { return }
            // Flush whatever was in flight so the last thing said isn't lost.
            if self.inSpeech, self.speechFor >= self.minSpeech {
                self.emit()
            }
            self.resetState()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Pipeline

    private func ingest(_ buffer: AVAudioPCMBuffer, outFormat: AVAudioFormat) {
        guard let converter else { return }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let ch = out.floatChannelData else { return }
        let samples = Array(UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength)))
        process(samples)
    }

    private func process(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        let dur = Double(samples.count) / targetRate
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))

        // Track the noise floor slowly while not speaking so a quiet room and a
        // loud room both work without the user touching anything.
        if !inSpeech {
            noiseFloor = 0.95 * noiseFloor + 0.05 * max(rms, 0.001)
        }
        let isSpeech = rms > noiseFloor * speechFactor

        // Keep a short pre-roll so the first consonant isn't clipped.
        ring.append(contentsOf: samples)
        let ringMax = Int(preRoll * targetRate)
        if ring.count > ringMax { ring.removeFirst(ring.count - ringMax) }

        if inSpeech {
            current.append(contentsOf: samples)
            speechFor += dur
            silentFor = isSpeech ? 0 : silentFor + dur

            if silentFor >= silenceToEnd || speechFor >= maxSegment {
                if speechFor - silentFor >= minSpeech { emit() }
                resetSegment()
            }
        } else if isSpeech {
            inSpeech = true
            current = ring          // start from the pre-roll, not from now
            speechFor = dur
            silentFor = 0
        }
    }

    private func emit() {
        let segment = current
        current = []
        onSegment?(segment)
    }

    private func resetSegment() {
        inSpeech = false
        silentFor = 0
        speechFor = 0
        current = []
    }

    private func resetState() {
        resetSegment()
        ring = []
        noiseFloor = 0.005
    }

    enum RecorderError: LocalizedError {
        case permissionDenied, formatUnavailable
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "CoHear needs the microphone to hear you. Enable it in Settings."
            case .formatUnavailable: return "This device's microphone format isn't supported."
            }
        }
    }
}
