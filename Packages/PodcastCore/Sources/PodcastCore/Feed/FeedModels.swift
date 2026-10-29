import Foundation

/// A podcast feed as read from its RSS file.
public struct ParsedFeed: Equatable, Sendable {
    public var title: String
    public var author: String?
    public var summary: String?
    public var artworkURL: URL?
    public var link: URL?
    /// In the order the feed lists them (usually newest first).
    public var episodes: [ParsedEpisode]

    public init(title: String, author: String? = nil, summary: String? = nil, artworkURL: URL? = nil, link: URL? = nil, episodes: [ParsedEpisode] = []) {
        self.title = title
        self.author = author
        self.summary = summary
        self.artworkURL = artworkURL
        self.link = link
        self.episodes = episodes
    }
}

/// One `<item>` from a feed. Items without an audio enclosure are skipped.
public struct ParsedEpisode: Equatable, Sendable {
    /// The feed's `<guid>`, or the audio URL when the feed has none.
    public var guid: String
    public var title: String
    public var summary: String?
    public var published: Date?
    public var audioURL: URL
    public var audioType: String?
    public var audioBytes: Int64?
    /// Length in seconds from `<itunes:duration>`, if given.
    public var duration: TimeInterval?
    public var artworkURL: URL?
    public var link: URL?
    /// Podcasting 2.0 `<podcast:transcript>` links.
    public var transcripts: [TranscriptLink]
    /// Podcasting 2.0 `<podcast:chapters>` JSON link.
    public var chaptersURL: URL?

    public init(guid: String, title: String, summary: String? = nil, published: Date? = nil, audioURL: URL, audioType: String? = nil, audioBytes: Int64? = nil, duration: TimeInterval? = nil, artworkURL: URL? = nil, link: URL? = nil, transcripts: [TranscriptLink] = [], chaptersURL: URL? = nil) {
        self.guid = guid
        self.title = title
        self.summary = summary
        self.published = published
        self.audioURL = audioURL
        self.audioType = audioType
        self.audioBytes = audioBytes
        self.duration = duration
        self.artworkURL = artworkURL
        self.link = link
        self.transcripts = transcripts
        self.chaptersURL = chaptersURL
    }
}

public struct TranscriptLink: Equatable, Sendable {
    public var url: URL
    /// MIME type, e.g. `text/vtt`, `application/x-subrip`, `application/json`.
    public var type: String?
    public var language: String?

    public init(url: URL, type: String? = nil, language: String? = nil) {
        self.url = url
        self.type = type
        self.language = language
    }
}

public enum FeedError: Error, Equatable {
    /// The file isn't an RSS podcast feed (for example a web page).
    case notAFeed
}
