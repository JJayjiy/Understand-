import Foundation

/// Tells "this was the speaker" from "this was someone else in the room."
///
/// Why not enrollment: your own finding is that enrollment friction is what gets
/// assistive tools abandoned. So there is no setup step. The first few things
/// said after tapping Listen become the reference — the speaker is holding the
/// phone, so that's almost always them — and every line can be corrected with
/// one tap if it guesses wrong.
///
/// Why not neural diarization: proper diarization clusters voices across a whole
/// recording. This app hands Whisper one utterance at a time, so labels wouldn't
/// stay consistent between them without keeping the entire session's audio in
/// memory and re-clustering. That's a much bigger change, another model download,
/// and it contradicts "nothing is stored."
///
/// THE THING THAT MATTERS MOST — read before tuning anything:
///
/// The person this app is for has a voice that varies far more, utterance to
/// utterance, than a typical speaker's. Pitch breaks. Voice quality shifts.
/// Articulation drifts. Any fixed threshold tuned on typical voices will flag
/// the speaker's own words as someone else's, which hides what they said.
///
/// So this profile does not use a fixed threshold. It measures how much the
/// speaker's OWN voice varies across the first several utterances, and only
/// flags a line as someone else when it falls well outside that spread. A
/// highly variable speaker automatically gets a wide tolerance.
///
/// The two errors are not symmetric. Wrongly dimming the speaker's own line
/// hides their words. Wrongly keeping a caretaker's line costs one glance and
/// one tap. Everything here is biased toward the second.

struct VoiceFingerprint: Equatable {

    /// Median fundamental frequency in Hz. 0 when the clip was unvoiced.
    let pitch: Float
    /// Energy across 8 log-spaced bands, normalised to sum to 1. Vocal tract shape.
    let bands: [Float]

    private static let centers: [Float] = [200, 350, 550, 800, 1200, 1800, 2600, 3600]
    private static let window = 1024          // 64 ms at 16 kHz
    private static let hop = 512

    /// Nil when the clip is too short or too quiet to characterise.
    static func extract(from samples: [Float], sampleRate: Float = 16_000) -> VoiceFingerprint? {
        guard samples.count >= window * 2 else { return nil }

        var pitches: [Float] = []
        var bandSums = [Float](repeating: 0, count: centers.count)
        var voicedWindows = 0

        var start = 0
        while start + window <= samples.count {
            let slice = Array(samples[start ..< start + window])
            start += hop

            let rms = sqrt(slice.reduce(0) { $0 + $1 * $1 } / Float(window))
            guard rms > 0.003 else { continue }
            voicedWindows += 1

            if let f0 = estimatePitch(slice, sampleRate: sampleRate) {
                pitches.append(f0)
            }
            for (i, f) in centers.enumerated() {
                bandSums[i] += goertzel(slice, frequency: f, sampleRate: sampleRate)
            }
        }

        guard voicedWindows >= 2 else { return nil }
        let total = bandSums.reduce(0, +)
        guard total > 0 else { return nil }

        return VoiceFingerprint(
            pitch: pitches.isEmpty ? 0 : median(pitches),
            bands: bandSums.map { $0 / total }
        )
    }

    /// 0 = identical, 1 = nothing alike.
    ///
    /// Spectral shape carries most of the weight. Pitch is the least stable
    /// feature of a dysarthric voice, so it gets less say, and octave errors —
    /// the classic pitch-tracker failure on breathy or strained voice — are
    /// folded so that 2× or ½× the reference pitch counts as close, not far.
    func distance(to other: VoiceFingerprint) -> Float {
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0 ..< min(bands.count, other.bands.count) {
            dot += bands[i] * other.bands[i]
            na += bands[i] * bands[i]
            nb += other.bands[i] * other.bands[i]
        }
        let cosine = (na > 0 && nb > 0) ? dot / (sqrt(na) * sqrt(nb)) : 0
        let shape = max(0, 1 - cosine)

        // Unknown pitch on either side: judge on shape alone.
        guard pitch > 0, other.pitch > 0 else { return shape }

        // Compare on a log scale and fold octaves.
        var semitones = abs(12 * log2(pitch / other.pitch))
        while semitones > 6 { semitones = abs(semitones - 12) }   // 0...6
        let pitchTerm = min(semitones / 6, 1)

        return 0.70 * shape + 0.30 * pitchTerm
    }

    // MARK: - Signal helpers

    private static func estimatePitch(_ x: [Float], sampleRate: Float) -> Float? {
        let minLag = Int(sampleRate / 320)
        let maxLag = min(Int(sampleRate / 70), x.count - 1)
        guard maxLag > minLag else { return nil }

        var zeroLagEnergy: Float = 0
        for v in x { zeroLagEnergy += v * v }
        guard zeroLagEnergy > 0 else { return nil }

        var best = minLag
        var bestScore: Float = 0
        for lag in minLag ... maxLag {
            var sum: Float = 0
            var i = 0
            while i + lag < x.count {
                sum += x[i] * x[i + lag]
                i += 1
            }
            let score = sum / zeroLagEnergy
            if score > bestScore { bestScore = score; best = lag }
        }
        guard bestScore > 0.3 else { return nil }
        return sampleRate / Float(best)
    }

    private static func goertzel(_ x: [Float], frequency: Float, sampleRate: Float) -> Float {
        let k = 2 * Float.pi * frequency / sampleRate
        let coeff = 2 * cos(k)
        var s0: Float = 0, s1: Float = 0, s2: Float = 0
        for v in x { s0 = v + coeff * s1 - s2; s2 = s1; s1 = s0 }
        return sqrt(max(0, s1 * s1 + s2 * s2 - coeff * s1 * s2))
    }

    private static func median(_ v: [Float]) -> Float {
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}

/// What the profile concluded about one line.
enum VoiceMatch: String, Codable {
    /// Sounds like the speaker. Shown normally.
    case own
    /// Ambiguous. Shown normally, with a quiet "not sure" tag — never hidden.
    case uncertain
    /// Clearly a different voice. Dimmed and left out of Show and Speak.
    case other
}

/// Holds who "you" sound like, learns how much your voice varies, and adapts
/// as lines are confirmed.
final class VoiceProfile {

    /// How many of the speaker's own lines to collect before judging anyone.
    /// Until this many are in, everything is treated as the speaker.
    private let warmup = 3
    /// Keep the most recent N confirmed lines as the reference set.
    private let maxReference = 10
    /// Floor on the tolerance, so a speaker whose first few lines happen to be
    /// very consistent still isn't flagged the moment they vary a little.
    private let minTolerance: Float = 0.30
    /// "Other" requires the distance to exceed the tolerance by this factor.
    /// Between 1× and this is "uncertain": tagged, not hidden.
    private let clearMargin: Float = 1.6

    private var reference: [VoiceFingerprint] = []

    var isEstablished: Bool { reference.count >= warmup }

    /// Add a line the speaker has said (or confirmed).
    func confirm(_ fp: VoiceFingerprint) {
        reference.append(fp)
        if reference.count > maxReference { reference.removeFirst() }
    }

    /// The speaker corrected us. Restart the reference on this line, because
    /// being wrong usually means we anchored on the wrong person at the start.
    func reanchor(to fp: VoiceFingerprint) {
        reference = [fp]
    }

    func reset() { reference.removeAll() }

    /// Centroid of the reference set.
    private var centroid: VoiceFingerprint? {
        guard let first = reference.first else { return nil }
        var bands = [Float](repeating: 0, count: first.bands.count)
        var pitches: [Float] = []
        for fp in reference {
            for i in bands.indices where i < fp.bands.count { bands[i] += fp.bands[i] }
            if fp.pitch > 0 { pitches.append(fp.pitch) }
        }
        let n = Float(reference.count)
        let pitch: Float = pitches.isEmpty ? 0 : pitches.reduce(0, +) / Float(pitches.count)
        return VoiceFingerprint(pitch: pitch, bands: bands.map { $0 / n })
    }

    /// How far the speaker's own lines typically sit from their own centroid.
    /// This is the number that makes the classifier honest for a variable voice.
    private var spread: Float {
        guard let c = centroid, reference.count >= 2 else { return minTolerance }
        let ds = reference.map { $0.distance(to: c) }
        let mean = ds.reduce(0, +) / Float(ds.count)
        let maxD = ds.max() ?? mean
        // Tolerance is the larger of: twice the mean deviation, or the worst
        // deviation actually observed, or the floor. A line inside anything the
        // speaker has already done is, by definition, plausibly the speaker.
        return max(minTolerance, max(2 * mean, maxD))
    }

    /// Nil during warm-up — the caller should treat that as `.own`.
    func classify(_ fp: VoiceFingerprint) -> VoiceMatch? {
        guard isEstablished, let c = centroid else { return nil }
        let d = fp.distance(to: c)
        let tol = spread
        let verdict: VoiceMatch = d <= tol ? .own : (d <= tol * clearMargin ? .uncertain : .other)
        print("[CoHear] voice d=\(String(format: "%.3f", d)) tol=\(String(format: "%.3f", tol)) "
              + "→ \(verdict.rawValue)  (pitch \(Int(fp.pitch)) vs \(Int(c.pitch)), ref n=\(reference.count))")
        return verdict
    }
}
