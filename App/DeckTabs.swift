import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs, like Safari (Paul, 15 Nov 2026: tabs; mock-up
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7, "2 · Episodes as
// tabs"). Up next is a grid of open tabs in queue order (the episode
// playing first). Close one with × or a swipe left and it's marked played,
// with Undo. Pinned tabs at the top go to Find and Your shows; tab groups
// switch between Up next, New and Saved for later. Tapping a tab opens it
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

/// The tab groups: Up next, New, Saved for later.
enum DeckTabGroup: String, CaseIterable {
    case upNext, new, saved

    var name: String {
        switch self {
        case .upNext: return "Up next"
        case .new: return "New"
        case .saved: return "Saved"
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
    /// The tab the pager opens on (an episode ID).
    var start: String?

    init() {
        let saved: String = UserDefaults.standard.string(forKey: Self.groupKey) ?? ""
        group = DeckTabGroup(rawValue: saved) ?? .upNext
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

    /// The Shows tab's "New since you last looked": out this week, unplayed,
    /// not looked at in the catch-up yet, oldest first.
    static func new(_ unplayed: [PodcastEpisode], triaged: String) -> [PodcastEpisode] {
        let cutoff: Date = Date().addingTimeInterval(-LibraryView.newFor)
        let seen: Set<String> = DeckTriage.seen(triaged)
        return unplayed
            .filter { $0.podcast != nil && DeckShowOrder.isNew($0, cutoff: cutoff) && !seen.contains($0.episodeID) }
            .sorted { $0.published < $1.published }
    }

    /// Saved for later, newest saved first, played ones left out.
    static func saved(store: LibraryStore, raw: String) -> [PodcastEpisode] {
        let ids: [String] = SaveForLater.ids(raw)
        let found: [String: PodcastEpisode] = store.episodes(ids)
        return ids.compactMap { found[$0] }.filter { !$0.played }
    }

    static func tabs(_ group: DeckTabGroup, store: LibraryStore, player: PlayerModel,
                     unplayed: [PodcastEpisode], triaged: String, saved raw: String) -> [PodcastEpisode] {
        switch group {
        case .upNext: return upNext(store: store, player: player)
        case .new: return new(unplayed, triaged: triaged)
        case .saved: return saved(store: store, raw: raw)
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

    /// × or a swipe left: Up next and New mark it played; Saved takes it
    /// off the Saved list.
    func close(_ episode: PodcastEpisode) {
        switch group {
        case .upNext, .new:
            moves.played(episode)
        case .saved:
            let before: String = UserDefaults.standard.string(forKey: SaveForLater.key) ?? ""
            withAnimation(LibraryStore.listChange) { SaveForLater.remove(episode.episodeID) }
            store.undoAction = UndoAction(label: "Removed from Saved") {
                withAnimation(LibraryStore.listChange) {
                    UserDefaults.standard.set(before, forKey: SaveForLater.key)
                }
            }
        }
    }

    func playNow(_ episode: PodcastEpisode) { moves.playNow(episode) }

    func playNext(_ episode: PodcastEpisode) { moves.playNext(episode) }

    func isQueued(_ episode: PodcastEpisode) -> Bool {
        store.queue.contains { $0.episode.id == episode.episodeID }
    }

    /// Out of Up next but left unplayed.
    func removeFromUpNext(_ episode: PodcastEpisode) {
        store.undoable("Removed from Up next", episodes: []) { store.removeFromQueue(episode.episodeID) }
    }

    /// Drag to reorder in the Up next group: `dragged` takes `target`'s
    /// place. Nothing moves above (or is) the episode playing.
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
}

// MARK: - The overview

struct DeckTabsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.deckSelectTab) private var selectTab
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""
    @State private var showingSettings = false
    @State private var suggestions: [PodcastEpisode] = []

    var body: some View {
        let upNext: [PodcastEpisode] = DeckTabSource.upNext(store: store, player: player)
        let fresh: [PodcastEpisode] = DeckTabSource.new(unplayed, triaged: triaged)
        let saved: [PodcastEpisode] = DeckTabSource.saved(store: store, raw: savedRaw)
        let shown: [PodcastEpisode] = list(model.group, upNext: upNext, fresh: fresh, saved: saved)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DeckTabsHeader(settings: { showingSettings = true })
                DeckTabsGroups(counts: [upNext.count, fresh.count, saved.count])
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                if shown.isEmpty {
                    empty
                } else {
                    DeckTabsGrid(tabs: shown)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .deckPage()
        // Tabs · Your shows · Find and the edge swipes replace the pinned
        // tabs (Paul, 15 Nov 2026: Discover is part of Find now).
        .deckSections(current: 0)
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

    private func list(_ group: DeckTabGroup, upNext: [PodcastEpisode], fresh: [PodcastEpisode],
                      saved: [PodcastEpisode]) -> [PodcastEpisode] {
        switch group {
        case .upNext: return upNext
        case .new: return fresh
        case .saved: return saved
        }
    }

    @ViewBuilder private var empty: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Text("No open tabs")
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

    private var emptyWords: String {
        switch model.group {
        case .upNext: return "New episodes open as tabs when they arrive."
        case .new: return "Nothing new since you last looked."
        case .saved: return "Save an episode for later and it opens here as a tab."
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

/// "Up next · 6" / "New · 3" / "Saved · 4".
private struct DeckTabsGroups: View {
    @Environment(DeckTabsModel.self) private var model
    /// In `DeckTabGroup.allCases` order.
    let counts: [Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(DeckTabGroup.allCases.enumerated()), id: \.element) { index, group in
                chip(group, count: index < counts.count ? counts[index] : 0)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ group: DeckTabGroup, count: Int) -> some View {
        let on: Bool = model.group == group
        return Button {
            model.choose(group)
        } label: {
            Text(group.name + " · \(count)")
                .font(Theme.outfit(13, .bold))
                .monospacedDigit()
                .foregroundStyle(on ? Theme.background : Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(on ? Theme.ink : Theme.cardEdge.opacity(0.6)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}
