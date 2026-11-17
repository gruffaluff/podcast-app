import Foundation
import SwiftData
import SwiftUI
import UIKit
import PodcastCore

// Demo mode, for the Screenshots workflow (.github/workflows/screenshots.yml):
// the app runs in the iPhone Simulator with made-up shows and saves a
// screenshot of each main Deck screen, so a build can be looked at before
// it goes on the phone. Only when the app is launched with `-PoddeckDemo`
// (never on the phone: nothing passes it there). Then:
// - the library is kept in memory only (no iCloud, nothing saved),
// - feeds aren't checked (`LibraryStore.refreshAll` returns at once),
// - settings don't sync and no push registration is made,
// - a handful of invented shows and episodes are filled in, Up next is
//   set, one episode is part-played with chapters and a short transcript,
//   and it's loaded in the player, paused.
// `-PoddeckScreen <name>` picks the screen to open on (`DemoScreen`).
// Every name, title and line here is made up.

/// The screen demo mode opens on (`-PoddeckScreen <name>`).
enum DemoScreen: String {
    /// The Up next tabs overview (the default).
    case tabs
    /// The playing episode's tab: the player.
    case player
    /// The playing episode's tab with Read along open.
    case readalong
    /// Your shows.
    case shows
    /// A show's page.
    case showpage
    /// Find (search + charts; the charts come from Apple's directory).
    case find
    /// Settings.
    case settings
    /// Up next as the card deck instead of tabs.
    case carddeck
}

enum DemoMode {
    /// Launched with `-PoddeckDemo` (the Screenshots workflow).
    static let isOn: Bool = ProcessInfo.processInfo.arguments.contains("-PoddeckDemo")

    /// The screen to open on, read once (nil outside demo mode).
    static let screen: DemoScreen? = {
        guard isOn else { return nil }
        let arguments: [String] = ProcessInfo.processInfo.arguments
        guard let at = arguments.firstIndex(of: "-PoddeckScreen"), at + 1 < arguments.count else { return .tabs }
        return DemoScreen(rawValue: arguments[at + 1].lowercased()) ?? .tabs
    }()
}

@MainActor
enum DemoData {
    /// The show the show-page screenshot opens.
    static let showcaseFeed = feed("paper-lanterns")

    // MARK: Start-up

    /// A library in memory only: no iCloud, nothing left behind.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Podcast.self, PodcastEpisode.self, UpNextEntry.self, Bookmark.self, ListeningLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: configuration)
    }

    /// Settings for a clean run (only in the simulator's own settings).
    static func applyDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "welcomeSeen")  // WelcomeView.seenKey
        defaults.set(ColourScheme.auto, forKey: ColourScheme.key)
        defaults.set(DemoMode.screen == .carddeck ? DeckHome.deck : DeckHome.tabs, forKey: DeckHome.key)
        defaults.set("", forKey: TriedShows.key)
        defaults.set(false, forKey: "deckDialWords")
        defaults.set(Date(), forKey: "lastChecked")
    }

    /// Loads the episode at the top of Up next in the player, paused.
    static func loadPlayer(_ player: PlayerModel, store: LibraryStore) {
        guard let first = store.queue.first, let episode = store.episode(first.episode.id) else { return }
        player.play(episode, autoplay: false)
    }

    // MARK: Made-up library

    private struct ShowSpec {
        let slug: String
        let title: String
        let author: String
        let genre: String
        let summary: String
        let mode: AutoAddMode
        let rank: Int
        let colours: (UInt32, UInt32)
        let episodes: [String]
    }

    private static let shows: [ShowSpec] = [
        ShowSpec(slug: "paper-lanterns", title: "Paper Lanterns", author: "Ivy Marsh & Tom Achterberg",
                 genre: "Comedy", summary: "Two friends, one microphone and a lot of questions nobody asked. New episodes every Tuesday and Friday.",
                 mode: .top, rank: 0, colours: (0xE2603F, 0x7A2318),
                 episodes: ["Lanterns on the river", "The great biscuit debate", "Our worst holiday ever", "Listener letters: owls"]),
        ShowSpec(slug: "tidewater-weekly", title: "Tidewater Weekly", author: "Harbour Audio",
                 genre: "News", summary: "The week's news from the coast, in half an hour.",
                 mode: .top, rank: 1, colours: (0x2F6E9E, 0x112E45),
                 episodes: ["Ferries, fog and the new pier", "A quiet week at sea", "Storm season review", "The lighthouse keepers"]),
        ShowSpec(slug: "allotment-gang", title: "The Allotment Gang", author: "Greenhouse Productions",
                 genre: "Leisure", summary: "Muddy boots, big marrows and gentle arguments about compost.",
                 mode: .bottom, rank: 0, colours: (0x6E9A3C, 0x2C4317),
                 episodes: ["Planting garlic in November", "Slugs: a truce?", "Seed swaps and saving", "The shed tour"]),
        ShowSpec(slug: "static-and-signal", title: "Static & Signal", author: "Night Shift Radio",
                 genre: "Technology", summary: "Old radios, new gadgets and the people who fix them.",
                 mode: .bottom, rank: 0, colours: (0x5A4FB0, 0x221C52),
                 episodes: ["Valves are back", "Building a crystal set", "Inside a pocket radio", "Signals from the attic"]),
        ShowSpec(slug: "long-walks-home", title: "Long Walks Home", author: "Ruth Calder",
                 genre: "Society & Culture", summary: "Conversations recorded on foot, from one end of a town to the other.",
                 mode: .bottom, rank: 0, colours: (0xC8963A, 0x5E3F0F),
                 episodes: ["Across the moor with a baker", "The night bus driver", "A walk with my grandad", "Canal paths"]),
        ShowSpec(slug: "small-print-science", title: "Small Print Science", author: "Footnote Media",
                 genre: "Science", summary: "The surprising details hiding at the bottom of famous experiments.",
                 mode: .off, rank: 0, colours: (0x2E8F86, 0x0F3B37),
                 episodes: ["Why toast lands butter side down", "The bee that counted", "Clouds weigh a lot", "Measuring a sneeze"])
    ]

    private static func feed(_ slug: String) -> String { "https://demo.poddeck.invalid/\(slug)/feed.xml" }

    /// Fills the library: six made-up shows, four episodes each, Up next,
    /// one part-played episode with chapters and a transcript, one started
    /// outside Up next (Carry on), and some played history.
    static func seed(_ context: ModelContext) {
        let now = Date()
        var byShow: [String: [PodcastEpisode]] = [:]
        for (showIndex, spec) in shows.enumerated() {
            let show = Podcast(feedURL: feed(spec.slug), title: spec.title, author: spec.author,
                               summary: spec.summary, artworkURL: artwork(for: spec))
            show.autoAddRaw = spec.mode.rawValue
            show.topRank = spec.rank
            show.genre = spec.genre
            show.notify = spec.mode == .top
            show.followedAt = now.addingTimeInterval(-Double(40 + showIndex * 9) * 86_400)
            show.lastChecked = now
            context.insert(show)
            var made: [PodcastEpisode] = []
            for (index, title) in spec.episodes.enumerated() {
                // Newest first: episode 0 came out most recently.
                let hoursAgo: Double = Double(index) * 72 + Double(showIndex) * 9 + 5
                let guid = "\(spec.slug)-\(spec.episodes.count - index)"
                let episode = PodcastEpisode(
                    episodeID: PodcastEpisode.makeID(feedURL: show.feedURL, guid: guid),
                    guid: guid,
                    title: title,
                    summary: "\(title). A made-up episode of \(spec.title) for the screenshots. Nothing here is real: the people, places and stories are invented so the app has something to show.",
                    published: now.addingTimeInterval(-hoursAgo * 3600),
                    audioURL: URL(string: "https://demo.poddeck.invalid/\(spec.slug)/\(guid).mp3")!
                )
                episode.duration = Double(28 + (index * 17 + showIndex * 11) % 50) * 60
                context.insert(episode)
                episode.podcast = show
                made.append(episode)
            }
            byShow[spec.slug] = made
        }

        // Played history: the oldest episode of each show.
        for spec in shows {
            guard let oldest = byShow[spec.slug]?.last else { continue }
            oldest.played = true
            oldest.playedAt = now.addingTimeInterval(-3 * 86_400)
            oldest.lastPlayedAt = oldest.playedAt
        }

        // Up next, oldest first within each show (the queue rules' order).
        let queued: [PodcastEpisode?] = [
            byShow["paper-lanterns"]?[1],
            byShow["paper-lanterns"]?[0],
            byShow["tidewater-weekly"]?[1],
            byShow["tidewater-weekly"]?[0],
            byShow["allotment-gang"]?[0],
            byShow["static-and-signal"]?[1],
            byShow["long-walks-home"]?[0]
        ]
        for (order, episode) in queued.compactMap({ $0 }).enumerated() {
            context.insert(UpNextEntry(episodeID: episode.episodeID, manual: false, order: order))
        }

        // The one on now: part-played, with chapters and a transcript.
        if let top = byShow["paper-lanterns"]?[1] {
            top.duration = 3720
            top.position = 1245
            top.lastPlayedAt = now
            top.autoChapters = [
                Chapter(start: 0, end: 420, title: "Hello again"),
                Chapter(start: 420, end: 1080, title: "This week's post bag"),
                Chapter(start: 1080, end: 2160, title: "The great biscuit debate"),
                Chapter(start: 2160, end: 3060, title: "Listener questions"),
                Chapter(start: 3060, end: 3720, title: "Goodbye and next time")
            ]
            addTranscript(to: top)
        }
        // Started but not in Up next: shows as Carry on.
        if let started = byShow["small-print-science"]?[0] {
            started.position = 640
            started.lastPlayedAt = now.addingTimeInterval(-26 * 3600)
        }
        // Started and in Up next: shows a progress ring on its tab.
        if let started = byShow["tidewater-weekly"]?[1] {
            started.position = 400
            started.lastPlayedAt = now.addingTimeInterval(-2 * 86_400)
        }
        try? context.save()
    }

    // MARK: Transcript

    private static let lines: [(String, String)] = [
        ("Ivy", "Right, so the question this week is a big one."),
        ("Tom", "Is it the biscuit question? Please say it's the biscuit question."),
        ("Ivy", "It is the biscuit question. Which biscuit holds up best in a cup of tea?"),
        ("Tom", "I've been preparing for this my whole life, honestly."),
        ("Ivy", "We had so many letters about it. Someone sent a chart."),
        ("Tom", "A chart! With axes and everything?"),
        ("Ivy", "Dunk time along the bottom, crumbs up the side."),
        ("Tom", "That's beautiful. That's the most beautiful thing we've been sent."),
        ("Ivy", "The winner, by a long way, was the plain digestive."),
        ("Tom", "No. I refuse. The ginger nut is a much stronger biscuit."),
        ("Ivy", "Stronger, yes, but it doesn't take on any tea at all."),
        ("Tom", "That's the point! It stays itself. It has integrity."),
        ("Ivy", "Integrity. We're talking about a biscuit, Tom."),
        ("Tom", "And yet here we are, twenty minutes in."),
        ("Ivy", "Let's take a question from the post bag before we fall out."),
        ("Tom", "Go on then, read it out."),
        ("Ivy", "It says: dear both, my dog steals one biscuit every morning."),
        ("Tom", "Only one? That's a very polite dog."),
        ("Ivy", "And it's always a custard cream. Never anything else."),
        ("Tom", "A dog with taste. I respect that dog enormously."),
        ("Ivy", "So the question is, should they move the tin?"),
        ("Tom", "Absolutely not. That's a tradition now. Leave the tin."),
        ("Ivy", "There you go, from two people with no training at all."),
        ("Tom", "Which is exactly the kind of advice people come here for."),
        ("Ivy", "After this, the holiday stories. You've been warned."),
        ("Tom", "I've been warned, and I'm already dreading it.")
    ]

    /// A short made-up transcript around the play point, saved like a real
    /// one (TranscriptFiles), so Read along has words to show.
    private static func addTranscript(to episode: PodcastEpisode) {
        var segments: [TranscriptSegment] = []
        var start: TimeInterval = 1180
        for (speaker, text) in lines {
            let length: TimeInterval = 3 + Double(text.count) / 14
            segments.append(TranscriptSegment(start: start, end: start + length, speaker: speaker, text: text))
            start += length + 0.6
        }
        let name = TranscriptFiles.name(for: episode.episodeID)
        guard (try? TranscriptFiles.save(Transcript(source: .publisher, segments: segments), as: name)) != nil else { return }
        episode.transcriptFile = name
        episode.transcriptState = .ready
    }

    // MARK: Artwork

    /// A square picture for each show (a two-colour gradient with its
    /// initials), drawn once into Caches and used through a file link, so
    /// the app's artwork and colour code runs as it does with real shows.
    private static func artwork(for spec: ShowSpec) -> URL? {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DemoArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(spec.slug + ".png")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let size = CGSize(width: 600, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colours: [CGColor] = [uiColour(spec.colours.0).cgColor, uiColour(spec.colours.1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let initials: String = spec.title.split(separator: " ")
                .filter { $0.first?.isLetter == true }
                .prefix(2)
                .compactMap { (word: Substring) -> String? in word.first.map { String($0) } }
                .joined()
            let font = UIFont.systemFont(ofSize: 220, weight: .heavy)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.92)]
            let text = NSAttributedString(string: initials, attributes: attributes)
            let bounds = text.size()
            text.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2))
        }
        guard let data = image.pngData(), (try? data.write(to: file, options: .atomic)) != nil else { return nil }
        return file
    }

    private static func uiColour(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}
