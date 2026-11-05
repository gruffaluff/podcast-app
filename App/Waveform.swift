import AVFoundation

/// The real shape of a downloaded episode for the player's progress line:
/// how loud each stretch is, as bar heights (0.3...1). Made by listening to
/// a few short samples in each stretch (not decoding the whole hour), and
/// remembered for the session.
enum Waveform {
    private static let cache = Cache()

    static func levels(for file: URL, count: Int) async -> [CGFloat]? {
        let key = "\(file.lastPathComponent)#\(count)"
        if let known = await cache.get(key) { return known }
        let made = await Task.detached(priority: .utility) { measure(file, count: count) }.value
        if let made { await cache.set(key, made) }
        return made
    }

    private static func measure(_ url: URL, count: Int) -> [CGFloat]? {
        guard count > 0, let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let total = file.length
        guard total > 0, format.sampleRate > 0 else { return nil }
        let window = AVAudioFrameCount(format.sampleRate / 4)  // a quarter second
        let samplesPerBar = 6
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: window) else { return nil }

        var loudness: [Float] = []
        loudness.reserveCapacity(count)
        for bar in 0..<count {
            var sum: Float = 0
            var taken = 0
            for sample in 0..<samplesPerBar {
                let fraction = (Double(bar) + (Double(sample) + 0.5) / Double(samplesPerBar)) / Double(count)
                let position = AVAudioFramePosition(fraction * Double(total))
                guard position < total else { continue }
                file.framePosition = position
                buffer.frameLength = 0
                guard (try? file.read(into: buffer, frameCount: window)) != nil,
                      buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { continue }
                var squares: Float = 0
                let frames = Int(buffer.frameLength)
                for index in 0..<frames { squares += channel[index] * channel[index] }
                sum += (squares / Float(frames)).squareRoot()
                taken += 1
            }
            loudness.append(taken > 0 ? sum / Float(taken) : 0)
        }

        // Loudness in decibels, scaled between the quietest and loudest bars.
        let decibels = loudness.map { 20 * log10(max($0, 0.000_01)) }
        guard let low = decibels.min(), let high = decibels.max(), high > low else {
            return Array(repeating: 0.7, count: count)
        }
        return decibels.map { CGFloat(0.3 + 0.7 * ($0 - low) / (high - low)) }
    }

    private actor Cache {
        private var stored: [String: [CGFloat]] = [:]
        func get(_ key: String) -> [CGFloat]? { stored[key] }
        func set(_ key: String, _ value: [CGFloat]) { stored[key] = value }
    }
}
