import Foundation

/// A transcript as the app stores it (one JSON file per episode).
public struct Transcript: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// From the show's feed (`<podcast:transcript>`).
        case publisher
        /// Made on the iPhone.
        case onDevice
    }

    public var source: Source
    public var segments: [TranscriptSegment]
    public var music: [MusicSpan]

    public init(source: Source, segments: [TranscriptSegment], music: [MusicSpan] = []) {
        self.source = source
        self.segments = segments
        self.music = music
    }

    /// Distinct speaker labels, in order of first appearance.
    public var speakers: [String] {
        var seen: [String] = []
        for case let speaker? in segments.map(\.speaker) where !seen.contains(speaker) {
            seen.append(speaker)
        }
        return seen
    }
}

/// A stretch of speech: a cue, a sentence or (in some JSON files) a word.
public struct TranscriptSegment: Codable, Equatable, Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval
    /// A real name from the publisher, "Speaker 1" from speaker separation, or nil.
    public var speaker: String?
    public var text: String

    public init(start: TimeInterval, end: TimeInterval, speaker: String? = nil, text: String) {
        self.start = start
        self.end = end
        self.speaker = speaker
        self.text = text
    }
}

/// A stretch of music found in the audio.
public struct MusicSpan: Codable, Equatable, Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    public var length: TimeInterval { end - start }
}
