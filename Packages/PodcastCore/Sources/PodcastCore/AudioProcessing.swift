import Foundation

/// "Boost voices": a gentle compressor that lifts quiet speech and evens out
/// loud passages, then makes up the level, with a soft limiter so nothing
/// clips. One instance per audio channel; it keeps state between buffers.
public struct VoiceBoost: Sendable {
    public var thresholdDB: Float = -28
    public var ratio: Float = 3.5
    public var makeupDB: Float = 9
    public var attack: Double = 0.005
    public var release: Double = 0.15

    private var envelope: Float = 0

    public init() {}

    public mutating func process(_ samples: UnsafeMutableBufferPointer<Float>, sampleRate: Double) {
        guard sampleRate > 0 else { return }
        let attackCoef = Float(exp(-1 / (attack * sampleRate)))
        let releaseCoef = Float(exp(-1 / (release * sampleRate)))
        let makeup = Self.linear(makeupDB)
        for i in samples.indices {
            let x = samples[i]
            let level = abs(x)
            let coef = level > envelope ? attackCoef : releaseCoef
            envelope = coef * (envelope - level) + level
            let gain = makeup * compressionGain(for: envelope)
            samples[i] = Self.softLimit(x * gain)
        }
    }

    /// Gain (linear) the compressor applies at a given signal level.
    func compressionGain(for level: Float) -> Float {
        guard level > 1e-6 else { return 1 }
        let levelDB = 20 * log10(level)
        guard levelDB > thresholdDB else { return 1 }
        let outDB = thresholdDB + (levelDB - thresholdDB) / ratio
        return Self.linear(outDB - levelDB)
    }

    static func linear(_ db: Float) -> Float { pow(10, db / 20) }

    /// Smoothly limits to just under full scale.
    static func softLimit(_ x: Float) -> Float {
        let knee: Float = 0.8
        let a = abs(x)
        guard a > knee else { return x }
        let over = (a - knee) / (1 - knee)
        let limited = knee + (1 - knee) * (over / (1 + over))
        return x < 0 ? -limited : limited
    }
}

/// "Trim silences": decides when playback is in a pause long enough to speed
/// through. Fed the loudness of each audio buffer as it plays.
public struct SilenceDetector: Sendable {
    /// RMS below this counts as silence (about -42 dBFS).
    public var threshold: Float = 0.008
    /// How long a pause lasts before it's sped through; short natural
    /// pauses between words are left alone.
    public var minimumSilence: Double = 0.3

    public private(set) var silentFor: Double = 0

    public init() {}

    /// Returns true while playback should hurry through a pause.
    public mutating func feed(rms: Float, duration: Double) -> Bool {
        silentFor = rms < threshold ? silentFor + duration : 0
        return silentFor >= minimumSilence
    }

    public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Speed while hurrying through a pause.
    public static func trimRate(forSpeed speed: Double) -> Double {
        min(4, max(2.5, speed * 2.5))
    }
}
