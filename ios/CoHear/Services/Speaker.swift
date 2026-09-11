import AVFoundation
import Foundation

/// Reads the approved text aloud in a clear voice. On-device, via the system
/// synthesizer — no network.
///
/// This only ever speaks text the speaker has already chosen to show. It is
/// the speaker's voice being made audible to a listener who isn't looking at
/// the screen, not the app deciding what to say.
final class Speaker: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        stop()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92   // a touch slower than default
        u.prefersAssistiveTechnologySettings = true          // respect the user's VoiceOver rate/voice
        // Route to the speaker even if a mic session is active.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio,
                                                         options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
