import Foundation

/// Finds words in transcripts, ignoring case and accents.
public enum TranscriptSearch {
    public struct Match: Equatable, Sendable {
        /// Where to play from.
        public var time: TimeInterval
        /// The line around the match, shortened with "…" if long.
        public var snippet: String
        /// The matched words within `snippet`.
        public var highlight: Range<String.Index>
    }

    public static func matches(of query: String, in lines: [TranscriptLayout.Line], limit: Int = 3) -> [Match] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }
        var found: [Match] = []
        for line in lines {
            guard let range = line.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            found.append(snippet(line.text, around: range, time: line.start))
            if found.count >= limit { break }
        }
        return found
    }

    /// Keeps about `radius` characters each side of the match.
    static func snippet(_ text: String, around range: Range<String.Index>, time: TimeInterval, radius: Int = 70) -> Match {
        let lower = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        let prefix = lower > text.startIndex ? "…" : ""
        let suffix = upper < text.endIndex ? "…" : ""
        let snippet = prefix + String(text[lower..<upper]) + suffix
        let start = snippet.index(snippet.startIndex, offsetBy: prefix.count + text.distance(from: lower, to: range.lowerBound))
        let end = snippet.index(start, offsetBy: text.distance(from: range.lowerBound, to: range.upperBound))
        return Match(time: time, snippet: snippet, highlight: start..<end)
    }
}
