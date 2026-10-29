import Foundation

/// The Up Next ordering rules (see CLAUDE.md, "Up Next queue").
///
/// Core rule: every show's episodes stay in chronological order, oldest first.
/// - A new episode from a Top show goes directly after that show's queued
///   episodes if it has any; otherwise above every episode from lower-ranked
///   Top shows (and below higher-ranked ones).
/// - A new episode from a Bottom show goes to the end, never before an older
///   episode of the same show.
/// - Play next / Play last respect show order when `keepShowOrder` is on.
/// - Finished episodes are removed.
///
/// All functions are pure: they take a queue and return a new one.
public enum QueueEngine {

    // MARK: New episodes (auto-add)

    /// Adds newly published episodes according to each show's auto-add mode.
    /// Several episodes are added oldest first. Episodes already queued, and
    /// episodes from shows set to Off, are ignored.
    public static func addNewEpisodes(_ episodes: [Episode], to queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        var result = queue
        for episode in episodes.sorted(by: chronological) {
            result = addNewEpisode(episode, to: result, settings: settings)
        }
        return result
    }

    /// Adds one newly published episode according to its show's auto-add mode.
    public static func addNewEpisode(_ episode: Episode, to queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        guard !contains(episode, in: queue) else { return queue }
        let mode = settings.mode(for: episode.showID)
        guard mode != .off else { return queue }

        let item = QueueItem(episode: episode, source: .auto)
        var result = queue

        // The show already has episodes queued: slot in chronologically among them.
        if let index = chronologicalSlotAmongSiblings(of: episode, in: queue) {
            result.insert(item, at: index)
            return result
        }

        switch mode {
        case .top:
            result.insert(item, at: topInsertionIndex(forRank: settings.rank(of: episode.showID), in: queue, settings: settings))
        case .bottom:
            result.append(item)
        case .off:
            break
        }
        return result
    }

    // MARK: Manual adds

    /// Play next: goes to the very top, unless show order is kept and the
    /// show has older episodes queued, in which case it goes straight after them.
    public static func playNext(_ episode: Episode, in queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        var result = queue.filter { $0.episode.id != episode.id }
        let item = QueueItem(episode: episode, source: .manual)
        var index = 0
        if settings.keepShowOrder, let lastOlder = result.lastIndex(where: { isSameShowAndOlder($0.episode, than: episode) }) {
            index = lastOlder + 1
        }
        result.insert(item, at: index)
        return result
    }

    /// Play last: goes to the very end, unless show order is kept and the show
    /// has newer episodes queued, in which case it goes just before them.
    public static func playLast(_ episode: Episode, in queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        var result = queue.filter { $0.episode.id != episode.id }
        let item = QueueItem(episode: episode, source: .manual)
        if settings.keepShowOrder, let firstNewer = result.firstIndex(where: { isSameShowAndNewer($0.episode, than: episode) }) {
            result.insert(item, at: firstNewer)
        } else {
            result.append(item)
        }
        return result
    }

    /// Adds several episodes with Play next, keeping them oldest first at the top.
    public static func playNext(_ episodes: [Episode], in queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        var result = queue
        // Insert newest first so the oldest ends up first.
        for episode in episodes.sorted(by: chronological).reversed() {
            result = playNext(episode, in: result, settings: settings)
        }
        return result
    }

    /// Adds several episodes with Play last, oldest first.
    public static func playLast(_ episodes: [Episode], in queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        var result = queue
        for episode in episodes.sorted(by: chronological) {
            result = playLast(episode, in: result, settings: settings)
        }
        return result
    }

    // MARK: Completion and re-ranking

    /// Removes a finished episode from Up Next.
    public static func complete(_ episodeID: String, in queue: [QueueItem]) -> [QueueItem] {
        queue.filter { $0.episode.id != episodeID }
    }

    /// Re-sorts auto-added Top-show episodes after the ranking changes.
    /// They move between the slots Top-show episodes already occupy, ordered
    /// by show rank and then oldest first. Manual and Bottom items keep their place.
    public static func applyRanking(to queue: [QueueItem], settings: QueueSettings) -> [QueueItem] {
        let slots = queue.indices.filter { isAutoTop(queue[$0], settings: settings) }
        let sorted = slots.map { queue[$0] }.sorted { a, b in
            let ra = settings.rank(of: a.episode.showID)
            let rb = settings.rank(of: b.episode.showID)
            if ra != rb { return ra < rb }
            if a.episode.showID != b.episode.showID { return a.episode.showID < b.episode.showID }
            return chronological(a.episode, b.episode)
        }
        var result = queue
        for (slot, item) in zip(slots, sorted) {
            result[slot] = item
        }
        return result
    }

    // MARK: Helpers

    static func chronological(_ a: Episode, _ b: Episode) -> Bool {
        if a.published != b.published { return a.published < b.published }
        return a.id < b.id
    }

    static func contains(_ episode: Episode, in queue: [QueueItem]) -> Bool {
        queue.contains { $0.episode.id == episode.id }
    }

    static func isSameShowAndOlder(_ candidate: Episode, than episode: Episode) -> Bool {
        candidate.showID == episode.showID && chronological(candidate, episode)
    }

    static func isSameShowAndNewer(_ candidate: Episode, than episode: Episode) -> Bool {
        candidate.showID == episode.showID && chronological(episode, candidate)
    }

    /// Where the episode belongs among queued episodes of its own show, or nil
    /// if the show has nothing queued. After the last older sibling; if every
    /// sibling is newer, just before the first of them.
    static func chronologicalSlotAmongSiblings(of episode: Episode, in queue: [QueueItem]) -> Int? {
        guard queue.contains(where: { $0.episode.showID == episode.showID }) else { return nil }
        if let lastOlder = queue.lastIndex(where: { isSameShowAndOlder($0.episode, than: episode) }) {
            return lastOlder + 1
        }
        return queue.firstIndex(where: { $0.episode.showID == episode.showID })
    }

    static func isAutoTop(_ item: QueueItem, settings: QueueSettings) -> Bool {
        item.source == .auto && settings.mode(for: item.episode.showID) == .top
    }

    /// Walks down from the top past manual items and Top-show episodes of equal
    /// or higher priority; stops at the first lower-priority Top episode or any
    /// other auto-added episode.
    static func topInsertionIndex(forRank rank: Int, in queue: [QueueItem], settings: QueueSettings) -> Int {
        for (index, item) in queue.enumerated() {
            if item.source == .manual { continue }
            if isAutoTop(item, settings: settings), settings.rank(of: item.episode.showID) <= rank { continue }
            return index
        }
        return queue.count
    }
}
