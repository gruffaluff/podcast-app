import Foundation
import SwiftData
import PodcastCore

/// A show Paul follows.
@Model
final class Podcast {
    @Attribute(.unique) var feedURL: String
    var title: String
    var author: String
    var summary: String
    var artworkURL: URL?
    /// Off, Top or Bottom (see `AutoAddMode`).
    var autoAddRaw: String = AutoAddMode.off.rawValue
    /// Position among Top shows; lower is higher priority.
    var topRank: Int = 0
    /// Download new episodes automatically (takes effect once downloads are built).
    var autoDownload: Bool = true
    /// Alert when a new episode arrives (takes effect with notifications, step 7).
    var notify: Bool = false
    var followedAt: Date = Date()
    var lastChecked: Date?
    @Relationship(deleteRule: .cascade, inverse: \PodcastEpisode.podcast)
    var episodes: [PodcastEpisode] = []

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
}

@Model
final class PodcastEpisode {
    /// "<feed URL>|<guid>", unique across all shows.
    @Attribute(.unique) var episodeID: String
    var guid: String
    var title: String
    var summary: String
    var published: Date
    var audioURL: URL
    var duration: TimeInterval?
    var artworkURL: URL?
    var transcriptURL: URL?
    var chaptersURL: URL?
    /// Where playback stopped, in seconds.
    var position: TimeInterval = 0
    var played: Bool = false
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

    var timeLeft: TimeInterval? {
        guard let duration else { return nil }
        return max(0, duration - position)
    }
}

/// One row of Up Next, saved so the queue survives restarts.
@Model
final class UpNextEntry {
    var episodeID: String
    var manual: Bool
    var order: Int

    init(episodeID: String, manual: Bool, order: Int) {
        self.episodeID = episodeID
        self.manual = manual
        self.order = order
    }
}
