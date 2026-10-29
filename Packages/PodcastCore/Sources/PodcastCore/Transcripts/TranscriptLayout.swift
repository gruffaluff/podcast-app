import Foundation

/// How a transcript is laid out on screen: lines grouped under a timestamp
/// every ~20 seconds or at each pause, with music rows in between.
public enum TranscriptLayout {
    public struct Line: Equatable, Hashable, Sendable {
        public var start: TimeInterval
        public var end: TimeInterval
        public var speaker: String?
        public var text: String
    }

    public enum Row: Equatable, Hashable, Sendable {
        case line(Line)
        case music(MusicSpan)
        /// An ad break, shown as one band; its lines are hidden until Paul taps Show.
        case ad(AdBreak, [Line])

        public var start: TimeInterval {
            switch self {
            case .line(let line): return line.start
            case .music(let span): return span.start
            case .ad(let adBreak, _): return adBreak.start
            }
        }

        var end: TimeInterval {
            switch self {
            case .line(let line): return line.end
            case .music(let span): return span.end
            case .ad(let adBreak, _): return adBreak.end
            }
        }
    }

    public struct Block: Equatable, Hashable, Sendable {
        public var start: TimeInterval
        public var rows: [Row]
    }

    /// A new timestamp heading after this long...
    public static let blockLength: TimeInterval = 20
    /// ...or after a pause at least this long.
    public static let pause: TimeInterval = 2

    /// Joins short pieces (some JSON transcripts are word by word) into
    /// readable lines: same speaker, no real gap, not past a sentence end.
    public static func lines(from segments: [TranscriptSegment]) -> [Line] {
        var lines: [Line] = []
        for segment in segments.sorted(by: { $0.start < $1.start }) {
            if var last = lines.last,
               last.speaker == segment.speaker,
               segment.start - last.end < 1.0,
               !(endsSentence(last.text) && last.text.count >= 60),
               last.text.count + segment.text.count < 280 {
                last.text += needsSpace(last.text, segment.text) ? " " + segment.text : segment.text
                last.end = max(last.end, segment.end)
                lines[lines.count - 1] = last
            } else {
                lines.append(Line(start: segment.start, end: max(segment.end, segment.start), speaker: segment.speaker, text: segment.text))
            }
        }
        return lines
    }

    /// - Parameter ads: ad breaks; lines and music inside them fold into one
    ///   `.ad` row, which always gets a block of its own.
    public static func blocks(for transcript: Transcript, ads: [AdBreak] = []) -> [Block] {
        let allLines = lines(from: transcript.segments)
        let inAd = { (time: TimeInterval) in ads.contains { $0.contains(time) } }
        var rows = allLines.filter { !inAd($0.start) }.map(Row.line)
            + transcript.music.filter { !inAd($0.start) }.map(Row.music)
        for adBreak in ads {
            rows.append(.ad(adBreak, allLines.filter { adBreak.contains($0.start) }))
        }
        rows.sort { $0.start < $1.start }

        var blocks: [Block] = []
        var previousEnd: TimeInterval = -.infinity
        var previousWasAd = false
        for row in rows {
            let gap = row.start - previousEnd
            let isAd: Bool
            if case .ad = row { isAd = true } else { isAd = false }
            if let current = blocks.last, !isAd, !previousWasAd, row.start - current.start < blockLength, gap < pause {
                blocks[blocks.count - 1].rows.append(row)
            } else {
                blocks.append(Block(start: row.start, rows: [row]))
            }
            previousEnd = max(previousEnd, row.end)
            previousWasAd = isAd
        }
        return blocks
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".?!…".contains(last)
    }

    private static func needsSpace(_ a: String, _ b: String) -> Bool {
        guard let first = b.first else { return false }
        return !(a.last?.isWhitespace ?? true) && !",.;:!?'’)".contains(first)
    }
}

/// Turns sound-classifier windows into music spans.
public enum MusicDetection {
    public struct Window: Equatable, Sendable {
        public var start: TimeInterval
        public var duration: TimeInterval
        public var confidence: Double

        public init(start: TimeInterval, duration: TimeInterval, confidence: Double) {
            self.start = start
            self.duration = duration
            self.confidence = confidence
        }
    }

    /// Joins confident, touching windows; drops stings under `minimumLength`.
    public static func spans(from windows: [Window], threshold: Double = 0.6, minimumLength: TimeInterval = 5, maximumGap: TimeInterval = 1.5) -> [MusicSpan] {
        var spans: [MusicSpan] = []
        for window in windows.sorted(by: { $0.start < $1.start }) where window.confidence >= threshold {
            let end = window.start + window.duration
            if let last = spans.last, window.start - last.end <= maximumGap {
                spans[spans.count - 1].end = max(last.end, end)
            } else {
                spans.append(MusicSpan(start: window.start, end: end))
            }
        }
        return spans.filter { $0.length >= minimumLength }
    }
}
