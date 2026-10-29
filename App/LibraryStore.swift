import Foundation
import Observation
import SwiftData
import PodcastCore

/// Follows shows, checks their feeds, and keeps Up Next (using the rules in
/// `QueueEngine`). Views read data with `@Query` and call this for changes.
@MainActor
@Observable
final class LibraryStore {
    let context: ModelContext

    /// Up Next, in order.
    private(set) var queue: [QueueItem] = []
    private(set) var isRefreshing = false
    private(set) var lastChecked: Date? = nil {
        didSet { UserDefaults.standard.set(lastChecked, forKey: "lastChecked") }
    }

    /// "Keep each show in order" for Play next / Play last (default on).
    var keepShowOrder: Bool = true {
        didSet { UserDefaults.standard.set(keepShowOrder, forKey: "keepShowOrder") }
    }

    init(context: ModelContext) {
        self.context = context
        self.lastChecked = UserDefaults.standard.object(forKey: "lastChecked") as? Date
        self.keepShowOrder = UserDefaults.standard.object(forKey: "keepShowOrder") as? Bool ?? true
        loadQueue()
    }

    // MARK: Lookups

    func podcast(feedURL: String) -> Podcast? {
        let descriptor = FetchDescriptor<Podcast>(predicate: #Predicate { $0.feedURL == feedURL })
        return try? context.fetch(descriptor).first
    }

    func episode(_ id: String) -> PodcastEpisode? {
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.episodeID == id })
        return try? context.fetch(descriptor).first
    }

    func episodes(_ ids: [String]) -> [String: PodcastEpisode] {
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { ids.contains($0.episodeID) })
        let found = (try? context.fetch(descriptor)) ?? []
        return Dictionary(found.map { ($0.episodeID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var allPodcasts: [Podcast] {
        (try? context.fetch(FetchDescriptor<Podcast>())) ?? []
    }

    var queueSettings: QueueSettings {
        let shows = allPodcasts
        var modes: [String: AutoAddMode] = [:]
        for show in shows { modes[show.feedURL] = show.autoAdd }
        let topRank = shows
            .filter { $0.autoAdd == .top }
            .sorted { ($0.topRank, $0.title) < ($1.topRank, $1.title) }
            .map(\.feedURL)
        return QueueSettings(modes: modes, topRank: topRank, keepShowOrder: keepShowOrder)
    }

    func isQueued(_ episode: PodcastEpisode) -> Bool {
        queue.contains { $0.episode.id == episode.episodeID }
    }

    // MARK: Following shows

    /// Follows the show at `feedURL` (or returns it if already followed).
    @discardableResult
    func follow(feedURL: URL) async throws -> Podcast {
        let key = feedURL.absoluteString
        if let existing = podcast(feedURL: key) { return existing }
        let feed = try await FeedClient.fetchFeed(feedURL)
        if let existing = podcast(feedURL: key) { return existing }

        let show = Podcast(
            feedURL: key,
            title: feed.title,
            author: feed.author ?? "",
            summary: PlainText.fromHTML(feed.summary ?? ""),
            artworkURL: feed.artworkURL
        )
        context.insert(show)
        _ = apply(feed, to: show)
        save()
        return show
    }

    func unfollow(_ show: Podcast) {
        let feedURL = show.feedURL
        commit(queue.filter { $0.episode.showID != feedURL })
        context.delete(show)
        save()
    }

    /// Sets a show to Off, Top or Bottom. A show newly set to Top joins the
    /// end of the Top ranking (re-ordering comes with the Shows screen).
    func setAutoAdd(_ mode: AutoAddMode, for show: Podcast) {
        guard show.autoAdd != mode else { return }
        if mode == .top {
            let lowest = allPodcasts.filter { $0.autoAdd == .top }.map(\.topRank).max() ?? -1
            show.topRank = lowest + 1
        }
        show.autoAddRaw = mode.rawValue
        save()
    }

    // MARK: Checking for new episodes

    /// Checks every followed show and adds fresh episodes to Up Next by the queue rules.
    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let urls = allPodcasts.map(\.feedURL)
        var feeds: [String: ParsedFeed] = [:]
        await withTaskGroup(of: (String, ParsedFeed?).self) { group in
            for url in urls {
                group.addTask {
                    guard let feedURL = URL(string: url) else { return (url, nil) }
                    return (url, try? await FeedClient.fetchFeed(feedURL))
                }
            }
            for await (url, feed) in group {
                if let feed { feeds[url] = feed }
            }
        }

        var fresh: [Episode] = []
        for (url, feed) in feeds {
            guard let show = podcast(feedURL: url) else { continue }
            show.title = feed.title
            show.author = feed.author ?? show.author
            show.artworkURL = feed.artworkURL ?? show.artworkURL
            fresh += apply(feed, to: show)
        }
        save()
        commit(QueueEngine.addNewEpisodes(fresh, to: queue, settings: queueSettings))
        lastChecked = Date()
    }

    /// Saves episodes not seen before; returns the fresh releases among them.
    private func apply(_ feed: ParsedFeed, to show: Podcast) -> [Episode] {
        let known = Set(show.episodes.map(\.guid))
        let newestKnown = show.episodes.map(\.published).max()
        let diff = FeedDiff.compare(feed.episodes, knownGUIDs: known, newestKnown: newestKnown)
        let freshGUIDs = Set(diff.fresh.map(\.guid))
        var fresh: [Episode] = []

        for parsed in diff.added {
            let episode = PodcastEpisode(
                episodeID: PodcastEpisode.makeID(feedURL: show.feedURL, guid: parsed.guid),
                guid: parsed.guid,
                title: parsed.title,
                summary: PlainText.fromHTML(parsed.summary ?? ""),
                published: parsed.published ?? .distantPast,
                audioURL: parsed.audioURL
            )
            episode.duration = parsed.duration
            episode.artworkURL = parsed.artworkURL
            episode.transcriptURL = parsed.transcripts.first?.url
            episode.chaptersURL = parsed.chaptersURL
            context.insert(episode)
            episode.podcast = show
            if freshGUIDs.contains(parsed.guid) {
                fresh.append(episode.queueEpisode)
            }
        }
        show.lastChecked = Date()
        return fresh
    }

    // MARK: Up Next

    func playNext(_ episode: PodcastEpisode) {
        commit(QueueEngine.playNext(episode.queueEpisode, in: queue, settings: queueSettings))
    }

    func playLast(_ episode: PodcastEpisode) {
        commit(QueueEngine.playLast(episode.queueEpisode, in: queue, settings: queueSettings))
    }

    func removeFromQueue(_ episodeID: String) {
        commit(QueueEngine.complete(episodeID, in: queue))
    }

    func moveQueue(from source: IndexSet, to destination: Int) {
        var moved = queue
        moved.move(fromOffsets: source, toOffset: destination)
        commit(moved)
    }

    /// Marks an episode played and takes it out of Up Next.
    func markPlayed(_ episodeID: String) {
        if let episode = self.episode(episodeID) {
            episode.played = true
            episode.position = 0
        }
        commit(QueueEngine.complete(episodeID, in: queue))
    }

    func markUnplayed(_ episode: PodcastEpisode) {
        episode.played = false
        episode.position = 0
        save()
    }

    func savePosition(_ position: TimeInterval, for episodeID: String) {
        guard let episode = self.episode(episodeID) else { return }
        episode.position = position
        save()
    }

    func saveDuration(_ duration: TimeInterval, for episodeID: String) {
        guard let episode = self.episode(episodeID), episode.duration.map({ abs($0 - duration) > 1 }) ?? true else { return }
        episode.duration = duration
        save()
    }

    // MARK: Saving

    private func commit(_ newQueue: [QueueItem]) {
        queue = newQueue
        let existing = (try? context.fetch(FetchDescriptor<UpNextEntry>())) ?? []
        for entry in existing { context.delete(entry) }
        for (index, item) in newQueue.enumerated() {
            context.insert(UpNextEntry(episodeID: item.episode.id, manual: item.source == .manual, order: index))
        }
        save()
    }

    private func loadQueue() {
        let descriptor = FetchDescriptor<UpNextEntry>(sortBy: [SortDescriptor(\.order)])
        let entries = (try? context.fetch(descriptor)) ?? []
        let found = episodes(entries.map(\.episodeID))
        queue = entries.compactMap { entry in
            found[entry.episodeID].map { QueueItem(episode: $0.queueEpisode, source: entry.manual ? .manual : .auto) }
        }
    }

    private func save() {
        try? context.save()
    }
}

/// Network calls. These run off the main thread.
enum FeedClient {
    enum Failure: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(let code): return "The server answered with error \(code)."
            }
        }
    }

    static func fetchFeed(_ url: URL) async throws -> ParsedFeed {
        try FeedParser.parse(try await get(url))
    }

    static func searchDirectory(_ term: String) async throws -> [DirectoryShow] {
        try Directory.decodeSearch(try await get(Directory.searchURL(term: term)))
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Podcasts/0.1 (personal iOS app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure.http(http.statusCode)
        }
        return data
    }
}
