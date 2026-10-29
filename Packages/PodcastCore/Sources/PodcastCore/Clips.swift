import Foundation

/// The maths behind "Share a clip".
public enum Clips {
    public static let lengths: ClosedRange<TimeInterval> = 5...30
    public static let step: TimeInterval = 5

    /// A clip's default length: the selected line's length rounded up to the
    /// next 5 seconds, within 5–30 seconds.
    public static func defaultLength(lineStart: TimeInterval, lineEnd: TimeInterval) -> TimeInterval {
        let raw = max(0, lineEnd - lineStart)
        return clamp((raw / step).rounded(.up) * step)
    }

    public static func clamp(_ length: TimeInterval) -> TimeInterval {
        min(lengths.upperBound, max(lengths.lowerBound, length))
    }

    /// Start and end of the clip, kept inside the episode.
    public static func range(start: TimeInterval, length: TimeInterval, duration: TimeInterval?) -> ClosedRange<TimeInterval> {
        let length = clamp(length)
        guard let duration, duration > 0 else { return max(0, start)...(max(0, start) + length) }
        let begin = max(0, min(start, duration - length))
        return begin...min(duration, begin + length)
    }

    /// Text shared with a clip: the quote, where it's from, and (when the
    /// show has a web page for the episode) a link with the time.
    public static func shareText(quote: String, show: String, episode: String, at time: TimeInterval, link: URL?) -> String {
        var text = "“\(quote)”\n— \(show), \(episode) (\(TimeFormat.clock(time)))"
        if let link { text += "\nListen from \(TimeFormat.clock(time)): \(link.absoluteString)" }
        return text
    }

    /// Bars for a waveform: the loudness of `count` equal slices of
    /// `samples`, scaled so the loudest is 1.
    public static func waveform(_ samples: [Float], count: Int) -> [Double] {
        guard count > 0, !samples.isEmpty else { return Array(repeating: 0.3, count: max(0, count)) }
        let size = max(1, samples.count / count)
        var bars: [Double] = []
        for index in 0..<count {
            let lower = min(samples.count, index * size)
            let upper = min(samples.count, lower + size)
            guard lower < upper else { bars.append(0); continue }
            var sum: Float = 0
            for sample in samples[lower..<upper] { sum += sample * sample }
            bars.append(Double((sum / Float(upper - lower)).squareRoot()))
        }
        let loudest = bars.max() ?? 0
        return loudest > 0 ? bars.map { max(0.08, $0 / loudest) } : bars.map { _ in 0.3 }
    }
}
