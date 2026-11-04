import Foundation

/// A point where the show's transcript and the audio actually playing are
/// known to line up: audio time = transcript time + offset from here on.
public struct SyncAnchor: Codable, Equatable, Sendable {
    public var transcriptTime: TimeInterval
    public var offset: TimeInterval

    public init(transcriptTime: TimeInterval, offset: TimeInterval) {
        self.transcriptTime = transcriptTime
        self.offset = offset
    }
}

/// Lines a publisher's transcript up with Paul's copy of the audio. Shows
/// insert ads into the audio (different ones per download), which the
/// transcript doesn't have, so everything after an ad drifts. Short bits of
/// the audio transcribed on the iPhone are matched word for word against
/// the transcript to find how far off it is at that point.
public enum TranscriptAlign {

    /// How far the transcript is from the audio around some heard words.
    /// `heard` are on-device words in audio time. Nil when they can't be
    /// placed with confidence (e.g. they're an ad, or too few words).
    public static func anchor(heard: [TranscriptSegment], transcript: [TranscriptSegment], minimumMatches: Int = 3) -> SyncAnchor? {
        let said = timedWords(transcript)
        let spoken = timedWords(heard)
        guard said.count >= 3, spoken.count >= 3 else { return nil }

        // Where each three-word phrase appears in the transcript.
        var places: [String: [TimeInterval]] = [:]
        for i in 0..<(said.count - 2) {
            places[said[i].word + " " + said[i + 1].word + " " + said[i + 2].word, default: []].append(said[i].time)
        }
        var candidates: [(offset: TimeInterval, transcriptTime: TimeInterval)] = []
        for i in 0..<(spoken.count - 2) {
            let phrase = spoken[i].word + " " + spoken[i + 1].word + " " + spoken[i + 2].word
            guard let times = places[phrase], times.count <= 3 else { continue }  // too common to tell
            for time in times { candidates.append((spoken[i].time - time, time)) }
        }
        guard candidates.count >= minimumMatches else { return nil }

        // The offset most matches agree on (within 4 seconds).
        let sorted = candidates.sorted { $0.offset < $1.offset }
        var best = (start: 0, count: 0)
        var start = 0
        for end in sorted.indices {
            while sorted[end].offset - sorted[start].offset > 4 { start += 1 }
            if end - start + 1 > best.count { best = (start, end - start + 1) }
        }
        guard best.count >= minimumMatches, Double(best.count) >= Double(candidates.count) * 0.4 else { return nil }
        let cluster = sorted[best.start..<(best.start + best.count)]
        return SyncAnchor(transcriptTime: median(cluster.map(\.transcriptTime)), offset: median(cluster.map(\.offset)))
    }

    /// Anchors for a whole episode from an on-device transcript of the same
    /// audio, one per ~2 minutes where the words match.
    public static func anchors(heard: [TranscriptSegment], transcript: [TranscriptSegment], window: TimeInterval = 120) -> [SyncAnchor] {
        guard let end = heard.map(\.end).max() else { return [] }
        var result: [SyncAnchor] = []
        var from: TimeInterval = 0
        while from < end {
            let slice = heard.filter { $0.start >= from && $0.start < from + window }
            if let anchor = anchor(heard: slice, transcript: transcript) { result = adding(anchor, to: result) }
            from += window
        }
        return result
    }

    /// Adds an anchor, replacing any within 20 seconds of it.
    public static func adding(_ anchor: SyncAnchor, to anchors: [SyncAnchor]) -> [SyncAnchor] {
        (anchors.filter { abs($0.transcriptTime - anchor.transcriptTime) > 20 } + [anchor]).sorted { $0.transcriptTime < $1.transcriptTime }
    }

    /// The offset in force at a transcript time: the last anchor at or
    /// before it, or the first anchor for anything earlier.
    public static func offset(at transcriptTime: TimeInterval, anchors: [SyncAnchor]) -> TimeInterval {
        guard let first = anchors.first else { return 0 }
        return (anchors.last { $0.transcriptTime <= transcriptTime + 0.01 } ?? first).offset
    }

    /// The transcript time of something shown at `audioTime` in an aligned transcript.
    public static func transcriptTime(forAudio audioTime: TimeInterval, anchors: [SyncAnchor]) -> TimeInterval {
        for anchor in anchors.reversed() where audioTime - anchor.offset >= anchor.transcriptTime - 0.01 {
            let t = audioTime - anchor.offset
            if offset(at: t, anchors: anchors) == anchor.offset { return t }
        }
        return audioTime - offset(at: audioTime, anchors: anchors)
    }

    /// The transcript moved onto the audio's clock.
    public static func aligned(_ transcript: Transcript, anchors: [SyncAnchor]) -> Transcript {
        guard !anchors.isEmpty else { return transcript }
        var copy = transcript
        copy.segments = transcript.segments.map { segment in
            let shift = offset(at: segment.start, anchors: anchors)
            var moved = segment
            moved.start = max(0, segment.start + shift)
            moved.end = max(moved.start, segment.end + shift)
            return moved
        }
        return copy
    }

    // MARK: Helpers

    private struct TimedWord { var word: String; var time: TimeInterval }

    /// Words with an estimated time each (spread evenly across their segment).
    private static func timedWords(_ segments: [TranscriptSegment]) -> [TimedWord] {
        var words: [TimedWord] = []
        for segment in segments {
            let parts = segment.text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }
            let step = max(0, segment.end - segment.start) / Double(parts.count)
            for (i, part) in parts.enumerated() {
                words.append(TimedWord(word: part, time: segment.start + step * Double(i)))
            }
        }
        return words
    }

    private static func median(_ values: [TimeInterval]) -> TimeInterval {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }
}
