import SwiftUI
import UIKit
import PodcastCore

// Deck (Paul, 14 Nov 2026: "I love it"). Up next is a grid of episode
// tabs (Paul, 15 Nov 2026: tabs; the card deck went, 25 Nov 2026), Your
// shows is every show as tiles. Option C (27 Nov 2026): a switch at the
// top of both moves between them (DeckPageTop.swift); Find is the search,
// opened by pulling either page down or tapping its search box. The bottom
// bar (DeckTabsBar.swift) is just the mini player. An
// open tab is the player, the episode page and its show's settings in one
// (`DeckTabsPager`); there's no separate full-screen player.

/// Opens the playing episode's tab from anywhere in Deck.
private struct DeckOpenPlayerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// Go to Find (the Tabs page's dashed "Find something" tile).
private struct DeckOpenFindKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var deckOpenFind: () -> Void {
        get { self[DeckOpenFindKey.self] }
        set { self[DeckOpenFindKey.self] = newValue }
    }
}

extension EnvironmentValues {
    var deckOpenPlayer: () -> Void {
        get { self[DeckOpenPlayerKey.self] }
        set { self[DeckOpenPlayerKey.self] = newValue }
    }
}

/// Whether this Deck page (Up next, Shows, Find) is the one on screen.
/// The others are kept alive but hidden.
private struct DeckPageShownKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var deckPageShown: Bool {
        get { self[DeckPageShownKey.self] }
        set { self[DeckPageShownKey.self] = newValue }
    }
}

struct DeckRoot: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    /// 0 Up next, 1 Shows, 2 Find (kept by `SchemedRoot`).
    @Binding var tab: Int
    @Binding var showingPlayer: Bool
    @State private var made: Set<Int> = [0]
    @State private var tabsModel = DeckTabsModel()
    /// Up next or Your shows, whichever the search was opened from.
    @State private var searchFrom: Int = 0

    var body: some View {
        ZStack {
            page(0) { DeckTabsView() }
            page(1) { DeckShowsView() }
            page(2) { DeckFindView() }
        }
        .overlay(alignment: .bottom) { bottomFade }
        .overlay(alignment: .bottom) { bottom }
        .environment(\.deckOpenPlayer, openPlayingTab)
        .environment(\.deckOpenFind, openSearch)
        .environment(\.deckOpenSearch, openSearch)
        .environment(\.deckCloseSearch, closeSearch)
        .environment(\.deckSelectTab, { tab = $0 })
        .environment(tabsModel)
        .onChange(of: tab, initial: true) { _, new in made.insert(new) }
        // Tabs: an open tab, full screen; closing it goes to the overview.
        .fullScreenCover(isPresented: pagerShown) {
            DeckTabsPager()
                .environment(tabsModel)
                .presentationBackground(.clear)
        }
        // Closing it goes back to the page it was opened from (Your shows /
        // Find when opened from the bar there), else the overview.
        .onChange(of: tabsModel.pagerOpen) { _, open in
            if open {
                tabsModel.returnTab = tab
            } else {
                tab = tabsModel.returnTab
                tabsModel.returnTab = 0
            }
        }
        // There's no separate player (Paul, 16 Nov 2026: one tab = player +
        // episode page + show settings). Anything that asks for the player
        // (a quick action) opens the playing episode's tab instead.
        .onChange(of: showingPlayer, initial: true) { _, open in
            guard open else { return }
            showingPlayer = false
            openPlayingTab()
        }
        // Demo mode only (Screenshots workflow): open the screen asked for.
        .task { await openDemoScreen() }
    }

    /// Demo mode (`-PoddeckScreen`, DemoData.swift): opens the screen the
    /// Screenshots workflow asked for. Does nothing otherwise.
    private func openDemoScreen() async {
        guard let screen = DemoMode.screen else { return }
        try? await Task.sleep(for: .milliseconds(600))
        switch screen {
        case .player, .readalong:
            openPlayingTab()
        case .shows:
            tab = 1
        case .find:
            tab = 2
        case .showpage:
            tab = 1
            try? await Task.sleep(for: .milliseconds(400))
            store.revealShow = store.podcast(feedURL: DemoData.showcaseFeed)
        case .tabs, .settings:
            break
        }
    }

    /// Option C (Paul, 27 Nov 2026): the search (Find) drops in over the
    /// page it was opened from, keyboard up; Cancel goes back there.
    private func openSearch() {
        if tab != 2 { searchFrom = tab }
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { tab = 2 }
        // A beat later, so a search page made just now is listening.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            NotificationCenter.default.post(name: .deckFocusFind, object: nil)
        }
    }

    private func closeSearch() {
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { tab = searchFrom }
    }

    /// Up next and Started always have the episode playing as their first
    /// tab; from New the overview switches to Up next.
    private func openPlayingTab() {
        guard let id = player.nowPlaying?.episodeID else { return }
        let keep: Bool = tabsModel.group == .upNext || tabsModel.group == .started
        if !keep { tabsModel.choose(.upNext) }
        tabsModel.open(id)
    }

    private var pagerShown: Binding<Bool> {
        Binding(get: { tabsModel.pagerOpen },
                set: { tabsModel.pagerOpen = $0 })
    }

    /// Each page is made the first time it's shown, then kept (so it keeps
    /// its place); only the current one is on screen and touchable.
    @ViewBuilder private func page<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        if made.contains(index) {
            content()
                // Smoother scrolling (Paul, 15 Nov 2026): hidden pages are
                // told so, and stop following the player's clock.
                .environment(\.deckPageShown, tab == index)
                .contentMargins(.bottom, room(for: index), for: .scrollContent)
                .opacity(tab == index ? 1 : 0)
                .allowsHitTesting(tab == index)
                .accessibilityHidden(tab != index)
        }
    }

    private func room(for index: Int) -> CGFloat {
        // The bottom bar is the mini player too.
        DeckTabsBar.room + (index == 0 ? DeckTabsBar.pillRoom : 0)
    }

    /// Behind the bar: the page colour, solid from the mini player's
    /// middle down to the very bottom of the screen, with a short fade
    /// above, so nothing scrolling underneath shows through the Tabs ·
    /// Shows · Find icons (Paul, 27 Nov 2026: "menu see through and not
    /// going to bottom").
    private var bottomFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            Theme.background
                .frame(height: DeckTabsBar.height - DeckTabsBar.cardHeight / 2 + 8)
                // Carries on under the home indicator to the screen's edge.
                .background(Theme.background.ignoresSafeArea(edges: .bottom))
        }
        .allowsHitTesting(false)
    }

    private var bottom: some View {
        DeckTabsBar()
            .padding(.bottom, 8)
    }
}

extension View {
    /// A Deck card: white, a fine warm edge, rounded, with a soft shadow
    /// (stronger when `lifted`).
    func deckPlainCard(radius: CGFloat = 22, lifted: Bool = false) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            // Smoother scrolling (Paul, 15 Nov 2026): the shadow comes from
            // the plain shape and the edge is drawn on top, so the shadow
            // isn't worked out from the shape and edge together on every
            // card in a scrolling list. Looks the same.
            shape.fill(Theme.surface)
                .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(lifted ? 0.16 : 0.07),
                        radius: lifted ? 20 : 8, y: lifted ? 18 : 4)
                .overlay(shape.strokeBorder(Theme.cardEdge, lineWidth: 1))
        }
    }

    /// The Deck page: the warm off-white, filling under the bars.
    func deckPage() -> some View {
        background { Theme.background.ignoresSafeArea() }
    }
}
