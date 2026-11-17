import Foundation
import SwiftData

/// What counts as new: unplayed episodes out in the last week, since Paul
/// followed each show, plus each show's newest one. Used by the Tabs page,
/// the Shows tab's New list and catch-up, and the app icon badge. (These
/// lived on the older looks' Library screen until 17 Nov 2026.)
enum NewEpisodes {
    static var query: FetchDescriptor<PodcastEpisode> {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        // More than are shown: `pickNew` leaves some out.
        descriptor.fetchLimit = 60
        return descriptor
    }

    /// How long an episode stays new (Paul, 12 Nov 2026): one week from
    /// when it came out. After that it's only on its show page (still
    /// unplayed, and still in Up Next if it's there).
    static let newFor: TimeInterval = 7 * 86_400

    /// The query for the full New list.
    static var queryForList: FetchDescriptor<PodcastEpisode> {
        var descriptor = query
        descriptor.fetchLimit = 200
        return descriptor
    }

    /// What came out since Paul followed each show, plus that show's
    /// newest one (following a show with a long back catalogue shouldn't
    /// fill New with its old episodes; Paul, 8 Nov 2026).
    static func pickNew(from newEpisodes: [PodcastEpisode], limit: Int) -> [PodcastEpisode] {
        var seen = Set<String>()
        var cards: [PodcastEpisode] = []
        let cutoff = Date().addingTimeInterval(-Self.newFor)
        for episode in newEpisodes {
            // Newest first, so everything after this is older too.
            if episode.published < cutoff { break }
            guard let show = episode.podcast else { continue }
            let firstForShow = seen.insert(show.feedURL).inserted
            if firstForShow || episode.published >= show.followedAt {
                cards.append(episode)
            }
            if cards.count == limit { break }
        }
        return cards
    }
}
