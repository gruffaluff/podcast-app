import SwiftUI
import UIKit
import PodcastCore

// Deck (Paul, 14 Nov 2026: "I love it"). Spec: the clickable prototype
// https://claude.ai/artifact/CC3pxxR1XwBGtnp13xAdbB (its file is in
// design/deck/poddeck-prototype.html) and design/deck/HANDOVER.md.
// Up next is a deck of episode cards (the top card is the one playing),
// Shows is a deck of show cards, Find is search + charts. A floating white
// pill at the bottom switches between them; a mini player sits above it on
// Shows and Find (Up next IS the player). The full player opens over
// everything (RootView's full-screen cover).

/// Opens the full-screen player from anywhere in Deck.
private struct DeckOpenPlayerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
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
    /// 0 Up next, 1 Shows, 2 Find (kept by `SchemedRoot`).
    @Binding var tab: Int
    @Binding var showingPlayer: Bool
    @State private var made: Set<Int> = [0]
    /// "Up next as" Tabs or Card deck (Paul, 15 Nov 2026: tabs).
    @AppStorage(DeckHome.key) private var home: String = DeckHome.tabs
    @State private var tabsModel = DeckTabsModel()

    private var tabsMode: Bool { home != DeckHome.deck }

    /// Room under every list's last row: the pill, and the mini player on
    /// Shows and Find while something is on.
    static let pillRoom: CGFloat = 84
    static let miniRoom: CGFloat = DeckMiniPlayer.height + 10

    var body: some View {
        ZStack {
            page(0) {
                if tabsMode { DeckTabsView() } else { DeckUpNextView() }
            }
            page(1) { DeckShowsView() }
            page(2) { DeckFindView() }
        }
        .overlay(alignment: .bottom) { bottomFade }
        .overlay(alignment: .bottom) { bottom }
        .environment(\.deckOpenPlayer, openPlayer)
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
        // Tabs: there's no separate player (Paul, 16 Nov 2026: one tab =
        // player + episode page + show settings). Anything that asks for
        // the player (a quick action, Up next's "Play") opens the playing
        // episode's tab instead; RootView's cover stays shut in tabs mode.
        .onChange(of: showingPlayer, initial: true) { _, open in
            guard open, tabsMode else { return }
            showingPlayer = false
            openPlayingTab()
        }
    }

    /// The player in card deck mode; the playing episode's tab in tabs mode.
    private func openPlayer() {
        if tabsMode {
            openPlayingTab()
        } else {
            showingPlayer = true
        }
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
        Binding(get: { tabsMode && tabsModel.pagerOpen },
                set: { tabsModel.pagerOpen = $0 })
    }

    /// Each page is made the first time it's shown, then kept (so it keeps
    /// its place); only the current one is on screen and touchable.
    @ViewBuilder private func page<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        if made.contains(index) {
            content()
                // Smoother scrolling (Paul, 15 Nov 2026): hidden pages are
                // told so, and stop following the player's clock (Up next's
                // top card redrew twice a second behind Shows and Find).
                .environment(\.deckPageShown, tab == index)
                .contentMargins(.bottom, room(for: index), for: .scrollContent)
                .opacity(tab == index ? 1 : 0)
                .allowsHitTesting(tab == index)
                .accessibilityHidden(tab != index)
        }
    }

    private func room(for index: Int) -> CGFloat {
        // Tabs: Safari's bar is the mini player too.
        // The Tabs page also has the Up next · New · Started pill above it.
        if tabsMode { return DeckTabsBar.room + (index == 0 ? DeckTabsBar.pillRoom : 0) }
        return Self.pillRoom + (index != 0 && player.nowPlaying != nil ? Self.miniRoom : 0)
    }

    /// A soft fade of the page colour behind the pill, so cards scrolling
    /// under it fade away instead of meeting it edge to edge.
    private var bottomFade: some View {
        LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.92)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: tabsMode ? (tab == 0 ? 140 + DeckTabsBar.pillRoom : 140) : 96)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var bottom: some View {
        if tabsMode {
            DeckTabsBar(tab: $tab)
                .padding(.bottom, 8)
        } else {
            pillAndMini
        }
    }

    private var pillAndMini: some View {
        VStack(spacing: 10) {
            if tab != 0 && player.nowPlaying != nil {
                DeckMiniPlayer { showingPlayer = true }
                    .padding(.horizontal, 16)
            }
            DeckTabPill(tab: $tab)
        }
        .padding(.bottom, 8)
    }
}

/// The floating white pill: Up next · Shows · Find, the current one an
/// ink capsule. Switching is instant.
struct DeckTabPill: View {
    @Binding var tab: Int
    private static let names = ["Up next", "Shows", "Find"]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                item(index)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
        .background(Capsule().fill(Theme.surface))
        // A clear edge and a deeper shadow so it stands off white cards
        // scrolling under it (Paul, 14 Nov 2026: "menu gets lost").
        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
    }

    private func item(_ index: Int) -> some View {
        let on: Bool = tab == index
        // Instant: no animation carries the ink capsule across (Paul: slow).
        return Button {
            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true
            if tab == index && index != 0 {
                NotificationCenter.default.post(name: .deckPageToStart, object: index)
                return
            }
            withTransaction(instant) { tab = index }
        } label: {
            Text(Self.names[index])
                .font(Theme.outfit(15, on ? .bold : .semibold))
                .foregroundStyle(on ? Theme.background : Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 17)
                .frame(height: 40)
                .background(Capsule().fill(on ? Theme.ink : Color.clear))
                .contentShape(Capsule())
                .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

/// The mini player on Shows and Find: artwork, title, "show · 34m left"
/// and a round ink play / pause. Tap it to open the player.
struct DeckMiniPlayer: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    static let height: CGFloat = 62

    var body: some View {
        if let item = player.nowPlaying {
            HStack(spacing: 10) {
                Button(action: open) {
                    HStack(spacing: 10) {
                        DeckMiniRingArtwork(item: item)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(Theme.outfit(14, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            // Smoother scrolling (Paul, 16 Nov 2026): only
                            // this line and the ring follow the clock, not
                            // the whole bar floating over the page.
                            DeckMiniTimeLeft(item: item)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the player")
                playButton
            }
            .padding(.leading, 9)
            .padding(.trailing, 8)
            .frame(height: Self.height)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.14), radius: 12, y: 10)
        }
    }

    private func artwork(_ item: PlayerModel.NowPlaying) -> some View {
        Color.clear
            .frame(width: 44, height: 44)
            .overlay {
                CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private var playButton: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17))
                .foregroundStyle(Theme.background)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.ink))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

/// "Show · 34m left" under the mini player's title. Follows the player's
/// clock (twice a second), so it's its own small view.
struct DeckMiniTimeLeft: View {
    @Environment(PlayerModel.self) private var player
    let item: PlayerModel.NowPlaying

    var body: some View {
        Text(subtitle)
            .font(Theme.outfit(12, .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
    }

    private var subtitle: String {
        guard player.duration > 0 else { return item.showTitle }
        let left: TimeInterval = max(0, player.duration - player.currentTime)
        let minutes = Int((left / 60).rounded(.up))
        return item.showTitle + " · \(minutes)m left"
    }
}

extension View {
    /// A Deck card: white, a fine warm edge, rounded, with a soft shadow
    /// (stronger on the top card of a deck).
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
