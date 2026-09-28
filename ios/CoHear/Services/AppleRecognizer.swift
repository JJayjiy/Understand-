import Foundation
import Speech
import AVFoundation

/// Apple's built-in on-device recognizer (the one behind iOS dictation),
/// wrapped to take the same 16 kHz float buffers the rest of the pipeline uses.
///
/// This is the baseline. Every family that tries CoHear has already tried
/// dictation. If we can't beat it for a given speaker, we need to know.
///
/// `requiresOnDeviceRecognition = true` so nothing leaves the phone — same
/// promise as the Whisper path. Apple's confidence is per-segment 0...1; we map
/// it onto the same log-prob scale the Whisper path uses so the UI's
/// uncertainty flags mean the same thing regardless of model.
actor AppleRecognizer {

    private let recognizer: SFSpeechRecognizer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    var isAvailable: Bool {
        guard let r = recognizer else { return false }
        return r.isAvailable && r.supportsOnDeviceRecognition
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(_ samples: [Float]) async throws -> Transcriber.Result {
        guard let recognizer, recognizer.isAvailable else { throw Error.unavailable }
        guard await requestAuthorization() else { throw Error.notAuthorized }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.append(buffer)
        request.endAudio()

        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error {
                    finished = true
                    cont.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                let text = result.bestTranscription.formattedString
                let segs = result.bestTranscription.segments
                // Apple gives 0...1 confidence per segment (0 = unknown).
                // Map onto Whisper's log-prob scale: 1.0 -> 0, 0.5 -> -0.69, 0.2 -> -1.6.
                let confs = segs.map { max(Double($0.confidence), 0.05) }
                let avg = confs.isEmpty ? 0.3 : confs.reduce(0, +) / Double(confs.count)
                let logprob = Float(log(avg))
                print(String(format: "[CoHear] apple  %.1fs  conf %.2f -> logprob %.2f  \"%@\"",
                             Float(samples.count) / 16000, avg, logprob, text))
                cont.resume(returning: Transcriber.Result(text: text, avgLogprob: logprob,
                                                          compressionRatio: 0, noSpeechProb: text.isEmpty ? 1 : 0))
            }
        }
    }

    enum Error: LocalizedError {
        case unavailable, notAuthorized
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Apple's on-device recognizer isn't available on this phone."
            case .notAuthorized: return "Speech recognition permission was denied. Enable it in iPhone Settings → CoHear."
            }
        }
    }
}
