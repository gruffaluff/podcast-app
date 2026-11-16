import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs, like Safari (Paul, 15 Nov 2026: tabs; mock-up
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7, "2 · Episodes as
// tabs"). Up next is a grid of open tabs in queue order (the episode
// playing first). Close one with × or a swipe left and it's marked played,
// with Undo. Tab groups switch between Up next, New and Started (Paul,
// 16 Nov 2026: "get rid of saved and have up next, new and started as
// chips above the bar"; `DeckTabGroupPill`). Tapping a tab opens it
// full screen, and you swipe between tabs there (`DeckTabsPager`). The
// bottom bar is Safari's: what's on, swipe along it for the next tab, swipe
// up (or tap the count) for the overview (`DeckTabsBar`). Settings → Look →
// "Up next as" switches back to the card deck.

/// "Up next as": Tabs (default) or Card deck, kept on this iPhone.
enum DeckHome {
    static let key = "deckHome"
    static let tabs = "tabs"
    static let deck = "deck"

    static var isTabs: Bool {
        (UserDefaults.standard.string(forKey: key) ?? tabs) != deck
    }
}

/// The tab groups: Up next and Started. New went (Paul, 16 Nov 2026:
/// "everything new adds to up next in the relevant place … we drop the
/// new pill"): new episodes go into Up next by their show's rule and their
/// tab is flagged New (`DeckTabSource.isFresh`). Saved for later went
/// earlier; an old saved choice of either falls back to Up next.
enum DeckTabGroup: String, CaseIterable {
    case upNext, started

    var name: String {
        switch self {
        case .upNext: return "Up next"
        case .started: return "Started"
        }
    }
}

/// Shared by the overview, the pager and the bottom bar (owned by DeckRoot).
@MainActor
@Observable
final class DeckTabsModel {
    static let groupKey = "deckTabGroup"

    /// The chosen group, remembered on this iPhone.
    private(set) var group: DeckTabGroup
    /// The full-screen pager is open.
    var pagerOpen = false
    /// The page (0 Tabs, 1 Your shows, 2 Find) to go back to when the
    /// pager closes: where it was opened from (Paul, 16 Nov 2026: pulling
    /// the player down on Your shows or Find "snaps me back to tabs").
    var returnTab = 0
    /// The tab the pager opens on (an episode ID).
    var start: String?
    /// A tab is lifted and being dragged in the grid: the overview
    /// doesn't scroll and the cards' swipes are off meanwhile.
    var reordering = false

    init() {
        // Always Up next now: the group pill went (Paul, 16 Nov 2026).
        group = .upNext
    }

    func choose(_ next: DeckTabGroup) {
        group = next
        UserDefaults.standard.set(next.rawValue, forKey: Self.groupKey)
    }

    func open(_ episodeID: String) {
        start = episodeID
        pagerOpen = true
    }

    /// From the bottom bar's sideways swipe: the tab after (or before) the
    /// one playing, else the first tab.
    func openNeighbour(of tabs: [PodcastEpisode], playingID: String?, forward: Bool) {
        guard !tabs.isEmpty else { return }
        let ids: [String] = tabs.map(\.episodeID)
        var index: Int = 0
        if let playingID, let at = ids.firstIndex(of: playingID) {
            index = min(ids.count - 1, max(0, at + (forward ? 1 : -1)))
        }
        open(ids[index])
    }
}

/// The tabs in each group, in their own order.
@MainActor
enum DeckTabSource {
    /// The episode playing first, then Up next in order.
    static func upNext(store: LibraryStore, player: PlayerModel) -> [PodcastEpisode] {
        let ids: [String] = store.queue.map(\.episode.id)
        let found: [String: PodcastEpisode] = store.episodes(ids)
        var list: [PodcastEpisode] = ids.compactMap { found[$0] }
        if let playing = player.nowPlaying?.episodeID {
            if let at = list.firstIndex(where: { $0.episodeID == playing }) {
                let on: PodcastEpisode = list.remove(at: at)
                list.insert(on, at: 0)
            } else if let on = store.episode(playing) {
                list.insert(on, at: 0)
            }
        }
        return list
    }

    /// Flagged New on its Up next tab: came out in the last 48 hours, not
    /// played and not started yet (Paul, 16 Nov 2026: "an indicator … to
    /// let you know it's come in … in the last 48 hours").
    static let freshFor: TimeInterval = 48 * 3600

    static func isFresh(_ episode: PodcastEpisode, now: Date = Date()) -> Bool {
        !episode.played && episode.position <= 30 && episode.published > now.addingTimeInterval(-freshFor)
    }

    /// Every unfinished episode with some listening (Paul, 16 Nov 2026:
    /// "Started should be anything started"), Up next ones included. Fed
    /// to `started(_:store:player:)` through a `@Query`.
    static var startedQuery: FetchDescriptor<PodcastEpisode> {
        let least: TimeInterval = 30
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false && $0.position > least },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        return descriptor
    }

    /// Started: the episode playing first, then most recently played
    /// (episodes with no play date go last, furthest through first).
    static func started(_ found: [PodcastEpisode], store: LibraryStore, player: PlayerModel) -> [PodcastEpisode] {
        var list: [PodcastEpisode] = found.sorted(by: startedOrder)
        if let playing = player.nowPlaying?.episodeID {
            if let at = list.firstIndex(where: { $0.episodeID == playing }) {
                let on: PodcastEpisode = list.remove(at: at)
                list.insert(on, at: 0)
            } else if let on = store.episode(playing), !on.played {
                list.insert(on, at: 0)
            }
        }
        return list
    }

    private static func startedOrder(_ a: PodcastEpisode, _ b: PodcastEpisode) -> Bool {
        switch (a.lastPlayedAt, b.lastPlayedAt) {
        case let (x?, y?): return x > y
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return a.position > b.position
        }
    }

    static func tabs(_ group: DeckTabGroup, store: LibraryStore, player: PlayerModel,
                     unplayed: [PodcastEpisode], triaged: String, started: [PodcastEpisode]) -> [PodcastEpisode] {
        switch group {
        case .upNext: return upNext(store: store, player: player)
        case .started: return Self.started(started, store: store, player: player)
        }
    }
}

/// What closing a tab and its menu do, per group. Every change offers Undo.
@MainActor
struct DeckTabActions {
    let store: LibraryStore
    let player: PlayerModel
    let group: DeckTabGroup

    private var moves: DeckQueueMoves { DeckQueueMoves(store: store, player: player) }

    /// × or a swipe left: marks it played (every group), with Undo.
    func close(_ episode: PodcastEpisode) {
        moves.played(episode)
    }

    func playNow(_ episode: PodcastEpisode) { moves.playNow(episode) }

    func playNext(_ episode: PodcastEpisode) { moves.playNext(episode) }

    // MARK: Swipe right (Paul, 16 Nov 2026: "Right gives us next or last
    // (but keeps it first in a show group if it's the oldest)")

    /// Play next, after the episode playing; with "Keep each show in
    /// order" never ahead of an older episode of the same show.
    func playNextInOrder(_ episode: PodcastEpisode) {
        store.undoable("Playing next", episodes: []) { store.playNext(episode) }
        explain(episode, toEnd: false)
    }

    /// To the end of Up next (even if it's already in it); with "Keep each
    /// show in order" never behind a newer episode of the same show.
    func addToEnd(_ episode: PodcastEpisode) {
        store.undoable("Added to the end", episodes: []) { commitAtEnd(episode) }
        explain(episode, toEnd: true)
    }

    /// `QueueEngine.playLast` with the episode playing kept where it is
    /// (it could be a newer episode of the same show).
    private func commitAtEnd(_ episode: PodcastEpisode) {
        var queue: [QueueItem] = store.queue
        var playingItem: QueueItem?
        var playingAt: Int = 0
        if let playing = player.nowPlaying?.episodeID, playing != episode.episodeID,
           let at = queue.firstIndex(where: { $0.episode.id == playing }) {
            playingItem = queue.remove(at: at)
            playingAt = at
        }
        queue = QueueEngine.playLast(episode.queueEpisode, in: queue, settings: store.queueSettings)
        if let playingItem { queue.insert(playingItem, at: min(playingAt, queue.count)) }
        store.commit(queue)
    }

    /// The Undo bar says where it went ("Playing next · 3rd"), and why when
    /// show order moved it ("After “Lanterns on the river…” to keep Paper
    /// Lanterns in order"). Episodes have no numbers here, so a short title.
    private func explain(_ episode: PodcastEpisode, toEnd: Bool) {
        guard let undo = store.undoAction else { return }
        let playing: String? = player.nowPlaying?.episodeID
        let ids: [String] = store.queue.map(\.episode.id).filter { $0 != playing }
        guard let at = ids.firstIndex(of: episode.episodeID) else { return }
        let base: String = toEnd ? "Added to the end" : "Playing next"
        let plain: Int = toEnd ? ids.count - 1 : 0
        var note: String?
        if at != plain {
            let neighbour: Int = toEnd ? at + 1 : at - 1
            if ids.indices.contains(neighbour), let other = store.episode(ids[neighbour]) {
                let words: String = (toEnd ? "Before " : "After ") + "“" + Self.short(other.title) + "”"
                note = words + " to keep " + episode.showTitle + " in order"
            }
        }
        var told = UndoAction(label: base + " · " + Self.ordinal(at + 1), restore: undo.restore)
        told.note = note
        store.undoAction = told
    }

    static func ordinal(_ number: Int) -> String {
        let tens: Int = number % 100
        if (11...13).contains(tens) { return "\(number)th" }
        switch number % 10 {
        case 1: return "\(number)st"
        case 2: return "\(number)nd"
        case 3: return "\(number)rd"
        default: return "\(number)th"
        }
    }

    static func short(_ title: String) -> String {
        let trimmed: String = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 26 else { return trimmed }
        return String(trimmed.prefix(24)).trimmingCharacters(in: .whitespaces) + "…"
    }

    func isQueued(_ episode: PodcastEpisode) -> Bool {
        store.queue.contains { $0.episode.id == episode.episodeID }
    }

    /// Out of Up next but left unplayed.
    func removeFromUpNext(_ episode: PodcastEpisode) {
        store.undoable("Removed from Up next", episodes: []) { store.removeFromQueue(episode.episodeID) }
    }

    /// Drag to reorder in the Up next group (`DeckTabsGrid`'s hand-made
    /// drag): `dragged` takes `target`'s place. Nothing moves above (or is) the episode playing.
    func move(_ dragged: String, onto target: String) -> Bool {
        guard group == .upNext, dragged != target else { return false }
        let playing: String? = player.nowPlaying?.episodeID
        guard dragged != playing, target != playing else { return false }
        let ids: [String] = store.queue.map(\.episode.id)
        guard let from = ids.firstIndex(of: dragged), let to = ids.firstIndex(of: target) else { return false }
        let destination: Int = to > from ? to + 1 : to
        withAnimation(LibraryStore.listChange) {
            store.moveQueue(from: IndexSet(integer: from), to: destination)
        }
        return true
    }
}

extension Notification.Name {
    /// Find's search box should take the keyboard (the pinned Find tab).
    static let deckFocusFind = Notification.Name("deckFocusFind")
    /// The bottom bar's word for the page already showing was tapped again
    /// (object: the page's index, 1 Your shows, 2 Find): go back to that
    /// page's first screen, like tapping an iPhone tab twice.
    static let deckPageToStart = Notification.Name("deckPageToStart")
}

// MARK: - The overview

struct DeckTabsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.deckSelectTab) private var selectTab
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @Query(DeckTabSource.startedQuery) private var started: [PodcastEpisode]
    @State private var showingSettings = false
    @State private var suggestions: [PodcastEpisode] = []

    var body: some View {
        // The groups are chips above the bottom bar now (`DeckTabGroupPill`).
        let shown: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                         unplayed: unplayed, triaged: triaged, started: started)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DeckTabsHeader(settings: { showingSettings = true })
                if shown.isEmpty {
                    empty
                } else {
                    DeckTabsGrid(tabs: shown)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                // Started but not in Up next (picked from Find, or a show
                // on Nowhere): slim Carry on cards under the tabs.
                DeckCarryOnSection(outsideUpNext: true)
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(model.reordering)
        .deckPage()
        .refreshable { await store.refreshAll() }
        .sheet(isPresented: $showingSettings) { DeckSettingsView() }
        .onChange(of: suggestionKey, initial: true) { _, _ in reloadSuggestions() }
        // "In Up next · 2nd" on an episode page: show the Up next tabs.
        .onChange(of: store.revealInUpNext, initial: true) { _, id in
            guard id != nil else { return }
            model.choose(.upNext)
            store.revealInUpNext = nil
        }
    }

    @ViewBuilder private var empty: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(Theme.outfit(20, .heavy))
                    .foregroundStyle(Theme.ink)
                Text(emptyWords)
                    .font(Theme.outfit(14, .medium))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 36)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .deckPlainCard(radius: 22)
            if model.group == .upNext && !suggestions.isEmpty {
                DeckSuggestionsSection(episodes: suggestions)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var emptyTitle: String {
        model.group == .started ? "Nothing started" : "No open tabs"
    }

    private var emptyWords: String {
        switch model.group {
        case .upNext: return "New episodes open as tabs when they arrive."
        case .started: return "Episodes you've started and not finished open here as tabs."
        }
    }

    private var suggestionKey: [String] {
        store.queue.map(\.episode.id) + [player.nowPlaying?.episodeID ?? ""]
    }

    private func reloadSuggestions() {
        let playing: String? = player.nowPlaying?.episodeID
        let left: Int = store.queue.filter { $0.episode.id != playing }.count
        guard left == 0 && playing == nil else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }
        suggestions = store.deckSuggestions(excluding: playing)
    }
}

/// The deck mark and "Poddeck"; "n · done by" and the gear on the right.
private struct DeckTabsHeader: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let settings: () -> Void

    var body: some View {
        let plan: DeckQueuePlan = DeckQueuePlan(store: store, player: player, playhead: nil)
        HStack(spacing: 8) {
            DeckMark(size: 30)
            Text("Poddeck")
                .font(Theme.outfit(26, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if plan.count > 0 {
                Text("\(plan.count) · done by " + UpNextTimes.clock(plan.end))
                    .font(Theme.outfit(13, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Button(action: settings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .padding(.top, 8)
        .frame(height: 52)
    }
}
