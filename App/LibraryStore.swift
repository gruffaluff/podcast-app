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
    /// The episode whose notes are open (any screen's menu can set it).
    var notesEpisode: PodcastEpisode?
    /// The last change that can be undone (shown as an Undo bar for a few seconds).
    var undoAction: UndoAction?
    /// The episode playing now (set by PlayerModel), so its download is never trimmed.
    @ObservationIgnored var playingEpisodeID: String?
    private(set) var lastChecked: Date? = nil {
        didSet { UserDefaults.standard.set(lastChecked, forKey: "lastChecked") }
    }

    /// "Keep each show in order" for Play next / Play last (default on).
    var keepShowOrder: Bool = true {
        didSet { UserDefaults.standard.set(keepShowOrder, forKey: "keepShowOrder") }
    }

    /// When Up Next runs out, carry on with new episodes from auto-add shows.
    var keepPlayingNew: Bool = true {
        didSet { UserDefaults.standard.set(keepPlayingNew, forKey: "keepPlayingNew") }
    }

    /// Keep played downloads for 24 hours instead of deleting them straight away.
    var keepPlayedDownloads: Bool = false {
        didSet {
            UserDefaults.standard.set(keepPlayedDownloads, forKey: "keepPlayedDownloads")
            cleanUpPlayedDownloads()
        }
    }

    /// Set by `DownloadManager` so new episodes can be auto-downloaded.
    @ObservationIgnored weak var downloads: DownloadManager?
    /// Set by `TranscriptService` so new and downloaded episodes get transcripts.
    @ObservationIgnored weak var transcripts: TranscriptService?
    /// Pending tidy-up after changes arrive from iCloud (see CloudSync.swift).
    @ObservationIgnored var cloudTidyTask: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
        self.lastChecked = UserDefaults.standard.object(forKey: "lastChecked") as? Date
        self.keepShowOrder = UserDefaults.standard.object(forKey: "keepShowOrder") as? Bool ?? true
        self.keepPlayingNew = UserDefaults.standard.object(forKey: "keepPlayingNew") as? Bool ?? true
        self.keepPlayedDownloads = UserDefaults.standard.bool(forKey: "keepPlayedDownloads")
        loadQueue()
        observeCloudChanges()
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
        let topRank = topShows.map(\.feedURL)
        return QueueSettings(modes: modes, topRank: topRank, keepShowOrder: keepShowOrder)
    }

    func isQueued(_ episode: PodcastEpisode) -> Bool {
        queue.contains { $0.episode.id == episode.episodeID }
    }

    // MARK: Following shows

    /// Follows the show at `feedURL` (or returns it if already followed).
    @discardableResult
    func follow(feedURL: URL, downloadLatest: Bool = true) async throws -> Podcast {
        let key = feedURL.absoluteString
        if let existing = podcast(feedURL: key) { return existing }
        let feed = try await FeedClient.fetchFeed(feedURL)
        if let existing = podcast(feedURL: key) { return existing }

        let show = Podcast(
            feedURL: key,
            title: feed.title,
            author: feed.author ?? "",
            summary: PlainText.notesFromHTML(feed.summary ?? ""),
            artworkURL: feed.artworkURL
        )
        // New shows start on Bottom; Paul picks settings right after following.
        show.autoAddRaw = AutoAddMode.bottom.rawValue
        show.website = feed.link
        context.insert(show)
        _ = apply(feed, to: show)
        // Only the newest episode downloads (following the Wi-Fi only setting).
        // Older ones stay unplayed; Paul can select them and mark them played.
        if downloadLatest, let latest = latestEpisode(of: show) { downloads?.download(latest, automatic: true) }
        save()
        return show
    }

    /// For testing: on a fresh install, follow Elis James and John Robins
    /// (Paul's pick) so there's something to play straight away.
    func followStarterShowIfNeeded() async {
        let key = "starterShowFollowed"
        guard !UserDefaults.standard.bool(forKey: key), !SettingsSync.starterShowFollowedInCloud, allPodcasts.isEmpty else { return }
        guard let feedURL = try? await FeedClient.lookup(appleID: "1465290044")?.feedURL,
              (try? await follow(feedURL: feedURL)) != nil else { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Follows every show in an OPML file from another app. Shows already
    /// followed are skipped; nothing downloads (that could be dozens of
    /// episodes at once), and nothing is added to Up Next until new
    /// episodes arrive, by the usual rules (new shows start on Bottom).
    func importShows(_ shows: [OPML.Show], progress: @MainActor (Int) -> Void) async -> ImportResult {
        var result = ImportResult()
        for (index, show) in shows.enumerated() {
            progress(index)
            if podcast(feedURL: show.feedURL.absoluteString) != nil {
                result.alreadyFollowed += 1
            } else if (try? await follow(feedURL: show.feedURL, downloadLatest: false)) != nil {
                result.added += 1
            } else {
                result.failed.append(show.title)
            }
        }
        progress(shows.count)
        return result
    }

    struct ImportResult {
        var added = 0
        var alreadyFollowed = 0
        var failed: [String] = []
    }

    /// Every followed show, for exporting to another app.
    var showListOPML: String {
        let shows = allPodcasts.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return OPML.make(shows.compactMap { show in
            URL(string: show.feedURL).map { OPML.Show(title: show.title, feedURL: $0) }
        })
    }

    func latestEpisode(of show: Podcast) -> PodcastEpisode? {
        show.episodes.max { $0.published < $1.published }
    }

    func unfollow(_ show: Podcast) {
        let feedURL = show.feedURL
        for episode in show.episodes {
            removeDownloadFile(of: episode)
            if let name = episode.transcriptFile { TranscriptFiles.delete(name) }
        }
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

    /// Top shows in priority order, favourite first.
    var topShows: [Podcast] {
        allPodcasts
            .filter { $0.autoAdd == .top }
            .sorted { ($0.topRank, $0.title) < ($1.topRank, $1.title) }
    }

    /// Saves a new Top priority order and re-sorts the Top block of Up Next
    /// (each show still oldest first; manually added episodes stay put).
    func setTopOrder(_ shows: [Podcast]) {
        for (index, show) in shows.enumerated() {
            show.topRank = index
        }
        save()
        commit(QueueEngine.applyRanking(to: queue, settings: queueSettings))
    }

    // MARK: Checking for new episodes

    /// Checks every followed show and adds fresh episodes to Up Next by the queue rules.
    /// Checks every feed. `postAlerts: false` when an iCloud push already
    /// showed the alert (see RealtimeAlerts).
    func refreshAll(postAlerts: Bool = true) async {
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
            show.website = feed.link ?? show.website
            let showNotes = PlainText.notesFromHTML(feed.summary ?? "")
            if !showNotes.isEmpty, showNotes != show.summary { show.summary = showNotes }
            fresh += apply(feed, to: show)
        }
        save()
        commit(QueueEngine.addNewEpisodes(fresh, to: queue, settings: queueSettings))
        lastChecked = Date()

        let freshEpisodes = episodes(fresh.map(\.id))
        let freshModels = fresh.compactMap { freshEpisodes[$0.id] }
        downloads?.autoDownload(freshModels)
        if postAlerts { NewEpisodeAlerts.post(for: freshModels, queue: queue) }
        cleanUpPlayedDownloads()
        await RealtimeAlerts.publishFollows(store: self)
        transcripts?.prepareUpNext()
    }

    /// Saves episodes not seen before; returns the fresh releases among them.
    private func apply(_ feed: ParsedFeed, to show: Podcast) -> [Episode] {
        let known = Set(show.episodes.map(\.guid))
        let newestKnown = show.episodes.map(\.published).max()
        let diff = FeedDiff.compare(feed.episodes, knownGUIDs: known, newestKnown: newestKnown)
        let freshGUIDs = Set(diff.fresh.map(\.guid))
        // Notes for episodes already saved are tidied too (and kept current).
        let saved = Dictionary(show.episodes.map { ($0.guid, $0) }, uniquingKeysWith: { first, _ in first })
        for parsed in feed.episodes {
            guard let episode = saved[parsed.guid] else { continue }
            let notes = PlainText.notesFromHTML(parsed.summary ?? "")
            if !notes.isEmpty, notes != episode.summary { episode.summary = notes }
        }
        var fresh: [Episode] = []

        for parsed in diff.added {
            let episode = PodcastEpisode(
                episodeID: PodcastEpisode.makeID(feedURL: show.feedURL, guid: parsed.guid),
                guid: parsed.guid,
                title: parsed.title,
                summary: PlainText.notesFromHTML(parsed.summary ?? ""),
                published: parsed.published ?? .distantPast,
                audioURL: parsed.audioURL
            )
            episode.duration = parsed.duration
            episode.artworkURL = parsed.artworkURL
            let transcript = TranscriptParser.preferred(parsed.transcripts)
            episode.transcriptURL = transcript?.url
            episode.transcriptType = transcript?.type
            episode.chaptersURL = parsed.chaptersURL
            episode.webLink = parsed.link
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

    /// Marks an episode played, takes it out of Up Next and deletes its
    /// download (or keeps it for 24 hours, if that setting is on).
    func markPlayed(_ episodeID: String) {
        if let episode = self.episode(episodeID) {
            episode.played = true
            episode.playedAt = Date()
            episode.position = 0
            if DownloadCleanup.shouldDelete(played: true, playedAt: episode.playedAt, keepFor24Hours: keepPlayedDownloads) {
                removeDownloadFile(of: episode)
            }
        }
        commit(QueueEngine.complete(episodeID, in: queue))
    }

    func markUnplayed(_ episode: PodcastEpisode) {
        markUnplayed([episode])
    }

    /// Marks many episodes played at once (e.g. a show's back catalogue).
    func markPlayed(_ episodes: [PodcastEpisode]) {
        var ids = Set<String>()
        for episode in episodes where !episode.played {
            episode.played = true
            episode.playedAt = Date()
            episode.position = 0
            ids.insert(episode.episodeID)
            if DownloadCleanup.shouldDelete(played: true, playedAt: episode.playedAt, keepFor24Hours: keepPlayedDownloads) {
                removeDownloadFile(of: episode)
            }
        }
        if queue.contains(where: { ids.contains($0.episode.id) }) {
            commit(queue.filter { !ids.contains($0.episode.id) })
        } else {
            save()
        }
    }

    func markUnplayed(_ episodes: [PodcastEpisode]) {
        for episode in episodes where episode.played {
            episode.played = false
            episode.playedAt = nil
            episode.position = 0
        }
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

    /// For "Keep playing new episodes": the next new episode to play when
    /// Up Next is empty, chosen by the queue rules from the last week's
    /// unplayed episodes of auto-add shows.
    func nextNewEpisode(excluding episodeID: String?) -> PodcastEpisode? {
        guard keepPlayingNew else { return nil }
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == false && $0.published > cutoff })
        let recent = ((try? context.fetch(descriptor)) ?? []).filter {
            $0.episodeID != episodeID && ($0.podcast?.autoAdd ?? .off) != .off
        }
        guard let next = QueueEngine.continuation(from: recent.map(\.queueEpisode), settings: queueSettings) else { return nil }
        return recent.first { $0.episodeID == next.id }
    }

    // MARK: Ads

    /// Saves ad breaks found while listening (merged with any already known,
    /// minus ones Paul said aren't ads) and the slice that was checked.
    @discardableResult
    func addAdBreaks(_ found: [AdBreak], scanned slice: ClosedRange<TimeInterval>, to episodeID: String) -> [AdBreak] {
        guard let episode = self.episode(episodeID) else { return [] }
        let dismissed = episode.dismissedAds
        let fresh = found.filter { ad in !dismissed.contains { abs($0 - ad.start) < 5 } }
        episode.adBreaks = AdDetection.merge(episode.adBreaks, fresh)
        episode.adScanned = AdScanPlan.adding(slice, to: episode.adScanned)
        save()
        return episode.adBreaks
    }

    // MARK: Downloads

    /// Deletes downloads of played episodes that are due to go.
    func cleanUpPlayedDownloads() {
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == true && $0.downloadFile != nil })
        let played = (try? context.fetch(descriptor)) ?? []
        for episode in played where DownloadCleanup.shouldDelete(played: true, playedAt: episode.playedAt, keepFor24Hours: keepPlayedDownloads) {
            removeDownloadFile(of: episode)
        }
        save()
    }

    /// The downloaded file, if there is one and it's still on the phone.
    func localAudioURL(for episode: PodcastEpisode) -> URL? {
        guard let name = episode.downloadFile else { return nil }
        let url = DownloadFiles.url(for: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func setDownloaded(_ episodeID: String, fileName: String) {
        guard let episode = self.episode(episodeID) else {
            DownloadFiles.delete(fileName)  // Show was unfollowed meanwhile.
            return
        }
        episode.downloadFile = fileName
        if let show = episode.podcast { applyDownloadLimit(to: show) }
        save()
        transcripts?.prepare(episode)
    }

    /// Deletes an episode's download (or stops it downloading).
    func removeDownload(_ episode: PodcastEpisode) {
        removeDownloadFile(of: episode)
        save()
    }

    func removeDownloadFile(of episode: PodcastEpisode) {
        downloads?.cancel(episode.episodeID)
        if let name = episode.downloadFile {
            DownloadFiles.delete(name)
            episode.downloadFile = nil
        }
    }

    // MARK: Saving

    func commit(_ newQueue: [QueueItem]) {
        queue = newQueue
        let existing = (try? context.fetch(FetchDescriptor<UpNextEntry>())) ?? []
        // Rows for episodes not on this iPhone yet (still arriving from
        // iCloud) are kept, so a sync in progress never loses them.
        let here = episodes(existing.map(\.episodeID))
        for entry in existing where here[entry.episodeID] != nil { context.delete(entry) }
        for (index, item) in newQueue.enumerated() {
            context.insert(UpNextEntry(episodeID: item.episode.id, manual: item.source == .manual, order: index))
        }
        save()
    }

    /// Re-reads Up Next after iCloud changed it (only if it differs).
    func reloadQueueFromSaved() {
        let before = queue.map(\.episode.id)
        loadQueue()
        if queue.map(\.episode.id) != before { transcripts?.prepareUpNext() }
    }

    private func loadQueue() {
        let descriptor = FetchDescriptor<UpNextEntry>(sortBy: [SortDescriptor(\.order)])
        let entries = (try? context.fetch(descriptor)) ?? []
        let found = episodes(entries.map(\.episodeID))
        var seen = Set<String>()
        queue = entries.compactMap { entry in
            guard seen.insert(entry.episodeID).inserted else { return nil }
            return found[entry.episodeID].map { QueueItem(episode: $0.queueEpisode, source: entry.manual ? .manual : .auto) }
        }
    }

    func save() {
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

    static func lookup(appleID: String) async throws -> DirectoryShow? {
        try Directory.decodeSearch(try await get(Directory.lookupURL(appleID: appleID))).first
    }

    static func topChart() async throws -> [DirectoryItem] {
        try Directory.decodeTopChart(try await get(Directory.topChartURL()))
    }

    /// Top shows in a category; falls back to a directory search for the
    /// category name if Apple's older chart feed isn't answering.
    static func genreChart(_ genre: PodcastGenre) async throws -> [DirectoryItem] {
        if let items = try? Directory.decodeGenreChart(try await get(Directory.genreChartURL(genreID: genre.id))), !items.isEmpty {
            return items
        }
        return try await searchDirectory(genre.name).map(DirectoryItem.init)
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
