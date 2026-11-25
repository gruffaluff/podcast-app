import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): an open tab, full screen,
// like a web page in Safari. Swipe sideways between the group's tabs. Each
// is one page for its episode: the player and the episode
// (DeckTabEpisodePage, Paul, 16 Nov 2026: "they're all the same tab").
// Pull a page down from its top to go back to the overview: the whole page
// follows the finger and slides away (the cover is see-through, so the
// overview shows behind it). Safari's bar at the bottom is gone (Paul,
// 16 Nov 2026, after build 163: "people swipe out of the player and pick a
// new tab, so get rid of that bar completely").

struct DeckTabsPager: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Query(NewEpisodes.queryForList) private var unplayed: [PodcastEpisode]
    @Query(DeckTabSource.startedQuery) private var started: [PodcastEpisode]

    @State private var current: String?
    /// How far a pull down has moved the page.
    @State private var pull: CGFloat = 0

    var body: some View {
        let tabs: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                        unplayed: unplayed, started: started)
        let ids: [String] = tabs.map(\.episodeID)
        GeometryReader { (geometry: GeometryProxy) in
            ZStack(alignment: .bottom) {
                backdrop(tabs)
                pages(tabs, insets: geometry.safeAreaInsets)
                UndoBar()
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
            }
            .ignoresSafeArea(.container, edges: .vertical)
        }
        .offset(y: pull)
        .onAppear {
            pull = 0
            current = model.start ?? ids.first
            if let id = current { prepareColour(tabs.first { $0.episodeID == id }) }
        }
        .onChange(of: ids) { old, new in idsChanged(old: old, new: new) }
        .onChange(of: model.start) { _, start in
            if let start, ids.contains(start) { current = start }
        }
        .transcribeExplainer()
    }

    private func pages(_ tabs: [PodcastEpisode], insets: EdgeInsets) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.episodeID) { index, episode in
                    DeckTabEpisodePage(episode: episode, index: index, count: tabs.count,
                                       insets: insets, close: close, pulled: pulled)
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
        var colour: Color = DeckPlayerBackground.bottomColour
        if let episode {
            colour = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.showTitle)
        }
        return DeckPlayerBackground(colour: colour, artwork: episode?.artwork)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: current)
    }

    // MARK: Moving between tabs

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

    /// The ⌄ key: back to the overview with the cover's own animation.
    private func close() {
        withAnimation(.spring(duration: 0.35)) { model.pagerOpen = false }
    }

    /// A pull down from the top of a page (`DeckPullDown`): the page follows
    /// the finger; let go far enough (or flick) and it slides away, then the
    /// cover closes with no second animation; otherwise it springs back.
    private func pulled(_ event: DeckPullEvent) {
        switch event {
        case .moved(let down):
            var still = Transaction(animation: nil)
            still.disablesAnimations = true
            withTransaction(still) { pull = down }
        case .ended(let shut):
            if shut {
                slideAwayAndClose()
            } else {
                withAnimation(.spring(duration: 0.3, bounce: 0.1)) { pull = 0 }
            }
        }
    }

    private func slideAwayAndClose() {
        withAnimation(.easeOut(duration: 0.2)) { pull = 1200 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var quiet = Transaction(animation: nil)
            quiet.disablesAnimations = true
            withTransaction(quiet) { model.pagerOpen = false }
        }
    }

    private func prepareColour(_ episode: PodcastEpisode?) {
        guard let url = episode?.artwork else { return }
        Task { await ArtworkColors.shared.load(url) }
    }
}
