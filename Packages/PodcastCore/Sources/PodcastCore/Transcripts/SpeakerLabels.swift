import Foundation

/// Puts speaker labels on a transcript made on the iPhone, using "who spoke
/// when" from on-device speaker separation.
public enum SpeakerLabels {
    /// One stretch of one person talking.
    public struct Turn: Equatable, Sendable {
        public var speaker: String
        public var start: TimeInterval
        public var end: TimeInterval

        public init(speaker: String, start: TimeInterval, end: TimeInterval) {
            self.speaker = speaker
            self.start = start
            self.end = end
        }
    }

    /// Labels each segment with the speaker who overlaps it most (or the
    /// nearest one within a second), naming them "Speaker 1", "Speaker 2"…
    /// in order of first appearance. Segments with nobody near stay unlabelled.
    public static func assign(_ turns: [Turn], to segments: [TranscriptSegment]) -> [TranscriptSegment] {
        guard !turns.isEmpty else { return segments }
        let sorted = turns.sorted { $0.start < $1.start }
        var names: [String: String] = [:]

        return segments.map { segment in
            var labelled = segment
            guard let raw = speaker(for: segment, in: sorted) else { return labelled }
            if names[raw] == nil { names[raw] = "Speaker \(names.count + 1)" }
            labelled.speaker = names[raw]
            return labelled
        }
    }

    static func speaker(for segment: TranscriptSegment, in turns: [Turn]) -> String? {
        let end = max(segment.end, segment.start + 0.05)
        var overlaps: [String: TimeInterval] = [:]
        for turn in turns {
            if turn.start >= end { break }
            let overlap = min(end, turn.end) - max(segment.start, turn.start)
            if overlap > 0 { overlaps[turn.speaker, default: 0] += overlap }
        }
        if let best = overlaps.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) {
            return best.key
        }
        // In a gap between turns: the closest one, if it's within a second.
        let nearest = turns.min { distance(segment, $0) < distance(segment, $1) }
        return nearest.flatMap { distance(segment, $0) <= 1 ? $0.speaker : nil }
    }

    private static func distance(_ segment: TranscriptSegment, _ turn: Turn) -> TimeInterval {
        if turn.end < segment.start { return segment.start - turn.end }
        if turn.start > segment.end { return turn.start - segment.end }
        return 0
    }
}
