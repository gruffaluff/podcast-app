import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): an open tab, full screen,
// like a web page in Safari. Swipe sideways between the group's tabs. Each
// is one page for its episode: the player, the episode and the show's
// settings (DeckTabEpisodePage, Paul, 16 Nov 2026: "they're all the same
// tab"). Safari's bar at the bottom: ‹ title › and the tab count; swipe
// along it for the next tab, up (or tap the count) for the overview. Pull
// a page down from its top to close it too.

struct DeckTabsPager: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""

    @State private var current: String?

    var body: some View {
        let tabs: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                        unplayed: unplayed, triaged: triaged, saved: savedRaw)
        let ids: [String] = tabs.map(\.episodeID)
        ZStack(alignment: .bottom) {
            backdrop(tabs)
            pages(tabs)
            VStack(spacing: 10) {
                UndoBar()
                    .padding(.horizontal, 4)
                DeckTabsPagerBar(tabs: tabs, current: current, step: { step(by: $0, ids: ids) }, close: close)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        // Pull down from the top of a page closes it (DeckTabEpisodePage
        // watches its own scroll, so the dial and scrolling up never do).
        .onAppear {
            current = model.start ?? ids.first
            if let id = current { prepareColour(tabs.first { $0.episodeID == id }) }
        }
        .onChange(of: ids) { old, new in idsChanged(old: old, new: new) }
        .onChange(of: model.start) { _, start in
            if let start, ids.contains(start) { current = start }
        }
        .transcribeExplainer()
    }

    private func pages(_ tabs: [PodcastEpisode]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.episodeID) { index, episode in
                    DeckTabEpisodePage(episode: episode, index: index, count: tabs.count, close: close)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(episode.episodeID)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
    }

    /// The current tab's show colour behind every page, changing as you
    /// settle on another tab.
    private func backdrop(_ tabs: [PodcastEpisode]) -> some View {
        let episode: PodcastEpisode? = tabs.first { $0.episodeID == current }
        var colour: Color = DeckPlayerView.bottomColour
        if let episode {
            colour = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.showTitle)
        }
        return DeckPlayerBackground(colour: colour)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: current)
    }

    // MARK: Moving between tabs

    private func step(by delta: Int, ids: [String]) {
        guard !ids.isEmpty else { return }
        let at: Int = current.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next: Int = min(ids.count - 1, max(0, at + delta))
        guard next != at else { return }
        withAnimation(.snappy(duration: 0.3)) { current = ids[next] }
    }

    /// A tab closed (marked played, removed): show the one now in its
    /// place, or go back to the overview when none are left.
    private func idsChanged(old: [String], new: [String]) {
        guard let id = current, !new.contains(id) else { return }
        guard !new.isEmpty else {
            close()
            return
        }
        let at: Int = old.firstIndex(of: id) ?? 0
        current = new[min(at, new.count - 1)]
    }

    private func close() {
        withAnimation(.spring(duration: 0.35)) { model.pagerOpen = false }
    }

    private func prepareColour(_ episode: PodcastEpisode?) {
        guard let url = episode?.artwork else { return }
        Task { await ArtworkColors.shared.load(url) }
    }
}

// MARK: - Safari's bar

private struct DeckTabsPagerBar: View {
    let tabs: [PodcastEpisode]
    let current: String?
    let step: (Int) -> Void
    let close: () -> Void

    var body: some View {
        let at: Int = current.flatMap { id in tabs.firstIndex { $0.episodeID == id } } ?? 0
        let episode: PodcastEpisode? = tabs.indices.contains(at) ? tabs[at] : nil
        HStack(spacing: 4) {
            arrow("chevron.left", label: "Previous tab", enabled: at > 0) { step(-1) }
            VStack(spacing: 1) {
                Text(episode?.title ?? "")
                    .font(Theme.outfit(13, .bold))
                    .lineLimit(1)
                Text(episode?.showTitle ?? "")
                    .font(Theme.outfit(11, .medium))
                    .foregroundStyle(Color(hex: 0x6B675F))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            arrow("chevron.right", label: "Next tab", enabled: at < tabs.count - 1) { step(1) }
            Button(action: close) {
                DeckTabCountSquare(count: tabs.count, colour: Color(hex: 0x1C1B1A))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs, \(tabs.count) open")
            .accessibilityHint("Back to the tab overview")
        }
        .foregroundStyle(Color(hex: 0x1C1B1A))
        .padding(.horizontal, 6)
        .frame(height: DeckTabsBar.height)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .highPriorityGesture(DeckBarSwipe.gesture.onEnded { value in swiped(value) })
    }

    private func swiped(_ value: DragGesture.Value) {
        guard let swipe = DeckBarSwipe.resolve(value) else { return }
        switch swipe {
        case .up: close()
        case .next: step(1)
        case .previous: step(-1)
        }
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}
