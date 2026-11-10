import Accelerate

/// Splits the playing sound into pitch bands for the player's level bars
/// (Paul, 10 Nov 2026: "more sensitive and more animated"). Before, every bar
/// followed one loudness number, so they rose and fell together.
///
/// Runs on the audio thread: everything is allocated up front, so analysing
/// a buffer allocates nothing.
final class BandMeter {
    static let bandCount = 24
    private static let log2n: vDSP_Length = 10
    private static let size = 1 << 10

    private let setup: FFTSetup
    private let window: UnsafeMutablePointer<Float>
    private let frame: UnsafeMutablePointer<Float>
    private let real: UnsafeMutablePointer<Float>
    private let imag: UnsafeMutablePointer<Float>
    private let power: UnsafeMutablePointer<Float>
    /// FFT bin where each band starts (bandCount + 1 entries, rising).
    private let edges: [Int]

    init?(sampleRate: Double) {
        guard sampleRate > 0, let setup = vDSP_create_fftsetup(Self.log2n, FFTRadix(kFFTRadix2)) else { return nil }
        let n = Self.size
        self.setup = setup
        window = .allocate(capacity: n)
        vDSP_hann_window(window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        frame = .allocate(capacity: n)
        real = .allocate(capacity: n / 2)
        imag = .allocate(capacity: n / 2)
        power = .allocate(capacity: n / 2)

        // Log-spaced from a deep voice up to the top of speech.
        let low = 90.0
        let high = min(9_000, sampleRate / 2 * 0.95)
        var edges: [Int] = []
        for k in 0...Self.bandCount {
            let frequency = low * pow(high / low, Double(k) / Double(Self.bandCount))
            var bin = Int((frequency * Double(n) / sampleRate).rounded())
            if let last = edges.last { bin = max(bin, last + 1) }
            edges.append(min(bin, n / 2))
        }
        self.edges = edges
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        window.deallocate()
        frame.deallocate()
        real.deallocate()
        imag.deallocate()
        power.deallocate()
    }

    /// Writes the power in each band (low to high) for the newest samples.
    func analyse(_ samples: UnsafeBufferPointer<Float>, into out: UnsafeMutablePointer<Float>) {
        let n = Self.size
        guard let base = samples.baseAddress, !samples.isEmpty else { return }
        let count = min(n, samples.count)
        frame.update(repeating: 0, count: n)
        (frame + (n - count)).update(from: base + (samples.count - count), count: count)
        vDSP_vmul(frame, 1, window, 1, frame, 1, vDSP_Length(n))

        var split = DSPSplitComplex(realp: real, imagp: imag)
        frame.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complex in
            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(n / 2))
        }
        vDSP_fft_zrip(setup, &split, 1, Self.log2n, FFTDirection(kFFTDirection_Forward))
        vDSP_zvmags(&split, 1, power, 1, vDSP_Length(n / 2))

        for band in 0..<Self.bandCount {
            let start = edges[band], end = edges[band + 1]
            guard end > start else { out[band] = 0; continue }
            var sum: Float = 0
            vDSP_sve(power + start, 1, &sum, vDSP_Length(end - start))
            out[band] = sum / Float(end - start)
        }
    }
}
