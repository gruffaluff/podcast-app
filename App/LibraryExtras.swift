import Foundation
import SwiftData
import PodcastCore

/// Something Paul just did that an Undo bar can reverse.
struct UndoAction: Identifiable {
    let id = UUID()
    let label: String
    let restore: @MainActor () -> Void
}

// MARK: - Undo

extension LibraryStore {
    /// Runs a change to some episodes (and maybe Up Next) and offers Undo:
    /// their played state, position and Up Next go back as they were.
    func undoable(_ label: String, episodes: [PodcastEpisode], _ change: () -> Void) {
        let queueBefore = queue
        let before = episodes.map { ($0.episodeID, $0.played, $0.playedAt, $0.position) }
        change()
        undoAction = UndoAction(label: label) { [weak self] in
            guard let self else { return }
            let saved = self.episodes(before.map(\.0))
            for (id, played, playedAt, position) in before {
                guard let episode = saved[id] else { continue }
                episode.played = played
                episode.playedAt = playedAt
                episode.position = position
            }
            let present = self.episodes(queueBefore.map(\.episode.id))
            self.commit(queueBefore.filter { present[$0.episode.id] != nil })
            self.undoAction = nil
        }
    }
}

// MARK: - Listening history, continue listening, stats

extension LibraryStore {
    /// Episodes Paul has listened to, most recent first.
    func listeningHistory(limit: Int = 200) -> [PodcastEpisode] {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Started but not finished, most recently played first.
    func continueListening(excluding playingID: String?, limit: Int = 10) -> [PodcastEpisode] {
        listeningHistory(limit: 60)
            .filter { !$0.played && $0.position > 30 && $0.episodeID != playingID }
            .prefix(limit)
            .map { $0 }
    }

    /// Adds listening time to today's total for a show.
    func logListening(_ seconds: Double, feedURL: String, showTitle: String) {
        guard seconds > 0, !feedURL.isEmpty else { return }
        let day = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ListeningLog>(predicate: #Predicate { $0.day == day && $0.feedURL == feedURL })
        let log = (try? context.fetch(descriptor).first) ?? {
            let new = ListeningLog(day: day, feedURL: feedURL, showTitle: showTitle)
            context.insert(new)
            return new
        }()
        log.seconds += seconds
        log.showTitle = showTitle
        save()
    }

    struct ListeningStats {
        var week: TimeInterval = 0
        var month: TimeInterval = 0
        var allTime: TimeInterval = 0
        var finishedThisMonth = 0
        var topShows: [(title: String, seconds: TimeInterval)] = []
        /// Minutes listened on each of the last 7 days, oldest first.
        var lastSevenDays: [(day: Date, seconds: TimeInterval)] = []
    }

    func listeningStats() -> ListeningStats {
        let logs = (try? context.fetch(FetchDescriptor<ListeningLog>())) ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let monthStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        var stats = ListeningStats()
        var byShow: [String: (title: String, seconds: TimeInterval)] = [:]
        var byDay: [Date: TimeInterval] = [:]
        for log in logs {
            stats.allTime += log.seconds
            if log.day >= weekStart { stats.week += log.seconds }
            if log.day >= monthStart { stats.month += log.seconds }
            byDay[log.day, default: 0] += log.seconds
            let entry = byShow[log.feedURL] ?? (title: log.showTitle, seconds: 0)
            byShow[log.feedURL] = (title: log.showTitle.isEmpty ? entry.title : log.showTitle, seconds: entry.seconds + log.seconds)
        }
        stats.topShows = byShow.values.sorted { $0.seconds > $1.seconds }.prefix(5).map { $0 }
        stats.lastSevenDays = (0..<7).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { (day: $0, seconds: byDay[$0] ?? 0) }
        }
        let finished = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == true && $0.playedAt != nil })
        stats.finishedThisMonth = ((try? context.fetch(finished)) ?? []).filter { ($0.playedAt ?? .distantPast) >= monthStart }.count
        return stats
    }
}

// MARK: - Shows

extension LibraryStore {
    /// Every followed show, A–Z.
    var allShows: [Podcast] {
        ((try? context.fetch(FetchDescriptor<Podcast>())) ?? [])
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

// MARK: - Downloads: per-show limit and storage

extension LibraryStore {
    /// Keeps only the show's newest `downloadLimit` downloads (never the one playing).
    func applyDownloadLimit(to show: Podcast) {
        guard show.downloadLimit > 0 else { return }
        let downloaded = show.episodes
            .filter { $0.downloadFile != nil }
            .sorted { $0.published > $1.published }
        for episode in downloaded.dropFirst(show.downloadLimit) where episode.episodeID != playingEpisodeID {
            removeDownloadFile(of: episode)
        }
    }

    static let downloadCapKey = "downloadCapGB"

    /// "Keep downloads under" (Shows screen): deletes the oldest downloads
    /// until the total fits: played ones first, then ones not in Up Next,
    /// then from the end of Up Next. Never the episode playing.
    func applyStorageCap() {
        let gigabytes = UserDefaults.standard.integer(forKey: Self.downloadCapKey)
        guard gigabytes > 0 else { return }
        let cap = Int64(gigabytes) * 1_000_000_000
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.downloadFile != nil })
        let downloaded = ((try? context.fetch(descriptor)) ?? []).filter { $0.episodeID != playingEpisodeID }
        var sizes: [String: Int64] = [:]
        var total: Int64 = 0
        for episode in downloaded {
            guard let name = episode.downloadFile else { continue }
            let size = Self.fileSize(DownloadFiles.url(for: name))
            sizes[episode.episodeID] = size
            total += size
        }
        if let playing = playingEpisodeID, let episode = self.episode(playing), let name = episode.downloadFile {
            total += Self.fileSize(DownloadFiles.url(for: name))
        }
        guard total > cap else { return }

        let queuePosition = Dictionary(queue.enumerated().map { ($0.element.episode.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let played = downloaded.filter(\.played).sorted { ($0.playedAt ?? .distantPast) < ($1.playedAt ?? .distantPast) }
        let loose = downloaded.filter { !$0.played && queuePosition[$0.episodeID] == nil }.sorted { $0.published < $1.published }
        let queued = downloaded.filter { !$0.played && queuePosition[$0.episodeID] != nil }
            .sorted { (queuePosition[$0.episodeID] ?? 0) > (queuePosition[$1.episodeID] ?? 0) }
        for episode in played + loose + queued {
            guard total > cap else { break }
            total -= sizes[episode.episodeID] ?? 0
            removeDownloadFile(of: episode)
        }
        save()
    }

    func setDownloadLimit(_ limit: Int, for show: Podcast) {
        show.downloadLimit = max(0, limit)
        applyDownloadLimit(to: show)
        save()
    }

    struct ShowStorage: Identifiable {
        var id: String { show.feedURL }
        let show: Podcast
        let count: Int
        let bytes: Int64
    }

    /// Downloads per show, biggest first.
    func storageByShow() -> [ShowStorage] {
        let shows = (try? context.fetch(FetchDescriptor<Podcast>())) ?? []
        return shows.compactMap { show in
            let files = show.episodes.compactMap(\.downloadFile)
            guard !files.isEmpty else { return nil }
            let bytes = files.reduce(Int64(0)) { $0 + Self.fileSize(DownloadFiles.url(for: $1)) }
            return ShowStorage(show: show, count: files.count, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
    }

    /// Size of transcripts saved on the phone.
    func transcriptBytes() -> Int64 {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: TranscriptFiles.directory.path)) ?? []
        return names.reduce(Int64(0)) { $0 + Self.fileSize(TranscriptFiles.directory.appendingPathComponent($1)) }
    }

    func removeDownloads(of show: Podcast) {
        for episode in show.episodes where episode.downloadFile != nil && episode.episodeID != playingEpisodeID {
            removeDownloadFile(of: episode)
        }
        save()
    }

    func removeAllDownloads() {
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.downloadFile != nil })
        for episode in (try? context.fetch(descriptor)) ?? [] where episode.episodeID != playingEpisodeID {
            removeDownloadFile(of: episode)
        }
        save()
    }

    static func fileSize(_ url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
