import Foundation
import SwiftUI
import PodcastCore

/// Placeholder shows and episodes until real feeds are wired up (build step 2).
enum SampleData {
    struct Show {
        let id: String
        let name: String
        let initials: String
        let color: Color
    }

    static let shows: [String: Show] = [
        "LS": Show(id: "LS", name: "The Long Signal", initials: "LS", color: Color(hex: 0x4A5D73)),
        "TW": Show(id: "TW", name: "Tidewater Weekly", initials: "TW", color: Color(hex: 0x4F6B5A)),
        "SM": Show(id: "SM", name: "Small Machines", initials: "SM", color: Color(hex: 0x7A5368)),
        "FN": Show(id: "FN", name: "Field Notes FM", initials: "FN", color: Color(hex: 0x8A6A3F))
    ]

    static let settings = QueueSettings(
        modes: ["LS": .top, "TW": .top, "FN": .bottom, "SM": .off],
        topRank: ["LS", "TW"],
        keepShowOrder: true
    )

    static func episode(_ id: String, _ show: String, _ title: String, daysAgo: Int) -> Episode {
        Episode(id: id, showID: show, title: title, published: Date().addingTimeInterval(TimeInterval(-daysAgo * 86_400)))
    }

    /// Builds the starting queue by running the real ordering rules.
    static func initialQueue() -> [QueueItem] {
        var queue: [QueueItem] = []
        queue = QueueEngine.addNewEpisodes([
            episode("tw1", "TW", "Low tide, high stakes", daysAgo: 6),
            episode("fn1", "FN", "The quiet economics of birdsong", daysAgo: 5),
            episode("tw2", "TW", "Harbour lights", daysAgo: 3)
        ], to: queue, settings: settings)
        queue = QueueEngine.playLast(episode("sm1", "SM", "Inside the tiny chips in everything", daysAgo: 4), in: queue, settings: settings)
        return queue
    }

    /// Episodes the "Check now" button pretends to find.
    static let arrivals: [Episode] = [
        episode("tw3", "TW", "The salt road", daysAgo: 0),
        episode("ls1", "LS", "How radio learned to listen", daysAgo: 0)
    ]
}
