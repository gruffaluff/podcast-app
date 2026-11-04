import Foundation
import SwiftData
import PodcastCore

// iCloud sync rules (SwiftData + CloudKit): no unique attributes, every
// property optional or with a default, every relationship optional.
// CloudKit can't enforce uniqueness, so `LibraryStore.mergeDuplicates()`
// tidies up after a sync.

/// A show Paul follows.
@Model
final class Podcast {
    var feedURL: String = ""
    var title: String = ""
    var author: String = ""
    var summary: String = ""
    var artworkURL: URL?
    /// Off, Top or Bottom (see `AutoAddMode`).
    var autoAddRaw: String = AutoAddMode.off.rawValue
    /// Position among Top shows; lower is higher priority.
    var topRank: Int = 0
    /// Download new episodes automatically (takes effect once downloads are built).
    var autoDownload: Bool = true
    /// Alert when a new episode arrives (takes effect with notifications, step 7).
    var notify: Bool = false
    /// Names Paul gave the speakers in this show's transcripts
    /// (label in the transcript → name), stored as JSON.
    var speakerNamesData: Data?
    /// Apple's category for the show (e.g. "History"), for Discover suggestions.
    var genre: String?
    /// The show's website, from its feed.
    var website: URL?
    var followedAt: Date = Date()
    var lastChecked: Date?
    /// Per-show playback: a speed for this show (0 = use the global speed),
    /// and seconds to skip at the start (intro) and end (outro) of episodes.
    var speedOverride: Double = 0
    var skipIntro: Double = 0
    var skipOutro: Double = 0
    /// Keep only this many of the show's newest downloads (0 = no limit).
    var downloadLimit: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \PodcastEpisode.podcast)
    var storedEpisodes: [PodcastEpisode]? = []

    var episodes: [PodcastEpisode] { storedEpisodes ?? [] }

    init(feedURL: String, title: String, author: String, summary: String, artworkURL: URL?) {
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.summary = summary
        self.artworkURL = artworkURL
    }

    var autoAdd: AutoAddMode {
        AutoAddMode(rawValue: autoAddRaw) ?? .off
    }

    var speakerNames: [String: String] {
        get { speakerNamesData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:] }
        set { speakerNamesData = try? JSONEncoder().encode(newValue) }
    }
}

@Model
final class PodcastEpisode {
    /// "<feed URL>|<guid>", unique across all shows.
    var episodeID: String = ""
    var guid: String = ""
    var title: String = ""
    var summary: String = ""
    var published: Date = Date.distantPast
    var audioURL: URL = URL(fileURLWithPath: "/")
    var duration: TimeInterval?
    var artworkURL: URL?
    /// The episode's web page, from its feed (used for "link to the moment").
    var webLink: URL?
    var transcriptURL: URL?
    /// MIME type of `transcriptURL`, from the feed.
    var transcriptType: String?
    /// See `TranscriptState`.
    var transcriptStateRaw: String = TranscriptState.none.rawValue
    /// File name in `TranscriptFiles.directory` once there is a transcript.
    var transcriptFile: String?
    /// Ad breaks found in Paul's own download (JSON `[AdBreak]`).
    var adBreaksData: Data?
    /// Starts of breaks Paul marked "Not an ad", so they aren't found again.
    var dismissedAdsData: Data?
    /// True once ads were looked for in an on-device transcript of the download.
    var adsChecked: Bool = false
    /// Parts of the download already checked for ads while listening (JSON).
    var adScannedData: Data?
    /// Chapters made from the transcript (JSON `[Chapter]`).
    var autoChaptersData: Data?
    /// Where the show's transcript lines up with Paul's audio (JSON
    /// `[SyncAnchor]`): inserted ads shift everything after them.
    var syncAnchorsData: Data?
    var chaptersURL: URL?
    /// Where playback stopped, in seconds.
    var position: TimeInterval = 0
    var played: Bool = false
    var playedAt: Date?
    /// Last time Paul listened to it (listening history, continue listening).
    var lastPlayedAt: Date?
    /// File name in `DownloadFiles.directory` once downloaded. Synced, but
    /// the file itself stays on this iPhone (see `reconcileLocalFiles`).
    var downloadFile: String?
    var podcast: Podcast?

    init(episodeID: String, guid: String, title: String, summary: String, published: Date, audioURL: URL) {
        self.episodeID = episodeID
        self.guid = guid
        self.title = title
        self.summary = summary
        self.published = published
        self.audioURL = audioURL
    }

    static func makeID(feedURL: String, guid: String) -> String {
        "\(feedURL)|\(guid)"
    }

    /// The episode as the queue rules see it.
    var queueEpisode: Episode {
        Episode(id: episodeID, showID: podcast?.feedURL ?? "", title: title, published: published)
    }

    var artwork: URL? { artworkURL ?? podcast?.artworkURL }

    var adBreaks: [AdBreak] {
        get { adBreaksData.flatMap { try? JSONDecoder().decode([AdBreak].self, from: $0) } ?? [] }
        set { adBreaksData = try? JSONEncoder().encode(newValue) }
    }

    var adScanned: [ClosedRange<TimeInterval>] {
        get { adScannedData.flatMap { try? JSONDecoder().decode([ClosedRange<TimeInterval>].self, from: $0) } ?? [] }
        set { adScannedData = try? JSONEncoder().encode(newValue) }
    }

    var dismissedAds: [TimeInterval] {
        get { dismissedAdsData.flatMap { try? JSONDecoder().decode([TimeInterval].self, from: $0) } ?? [] }
        set { dismissedAdsData = try? JSONEncoder().encode(newValue) }
    }

    var syncAnchors: [SyncAnchor] {
        get { syncAnchorsData.flatMap { try? JSONDecoder().decode([SyncAnchor].self, from: $0) } ?? [] }
        set { syncAnchorsData = try? JSONEncoder().encode(newValue) }
    }

    var autoChapters: [Chapter] {
        get { autoChaptersData.flatMap { try? JSONDecoder().decode([Chapter].self, from: $0) } ?? [] }
        set { autoChaptersData = try? JSONEncoder().encode(newValue) }
    }

    var transcriptState: TranscriptState {
        get { TranscriptState(rawValue: transcriptStateRaw) ?? .none }
        set { transcriptStateRaw = newValue.rawValue }
    }

    var timeLeft: TimeInterval? {
        guard let duration else { return nil }
        return max(0, duration - position)
    }
}

enum TranscriptState: String {
    /// Nothing done yet.
    case none
    /// Waiting for the audio to download (or for its turn).
    case waiting
    case transcribing
    case ready
    case failed
}

/// A moment Paul bookmarked from a transcript line.
@Model
final class Bookmark {
    var episodeID: String = ""
    var time: TimeInterval = 0
    var text: String = ""
    var created: Date = Date()
    /// Set when it was saved by sharing a clip of this length.
    var length: TimeInterval?

    init(episodeID: String, time: TimeInterval, text: String) {
        self.episodeID = episodeID
        self.time = time
        self.text = text
    }
}

/// Time listened, per show per day (listening stats).
@Model
final class ListeningLog {
    /// Start of the day (local time).
    var day: Date = Date.distantPast
    var feedURL: String = ""
    var showTitle: String = ""
    var seconds: Double = 0

    init(day: Date, feedURL: String, showTitle: String) {
        self.day = day
        self.feedURL = feedURL
        self.showTitle = showTitle
    }
}

/// One row of Up Next, saved so the queue survives restarts.
@Model
final class UpNextEntry {
    var episodeID: String = ""
    var manual: Bool = false
    var order: Int = 0

    init(episodeID: String, manual: Bool, order: Int) {
        self.episodeID = episodeID
        self.manual = manual
        self.order = order
    }
}
