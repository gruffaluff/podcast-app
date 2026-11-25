import SwiftUI
import SwiftData
import PodcastCore

// The bottom bar (Paul, 22 Nov 2026: "disc and pill"): a play disc for
// what's on and a pill of words, Tabs · n / Shows / Find. Swipe up on the
// pill for the tab overview, along it for the page before / after.

/// What a swipe on a Safari-style bar means.
enum DeckBarSwipe {
    case up, next, previous

    /// Measured in the global space; acts past 40 pt or on a flick, and
    /// the main direction must clearly win.
    static func resolve(_ value: DragGesture.Value) -> DeckBarSwipe? {
        let dx: CGFloat = value.translation.width
        let dy: CGFloat = value.translation.height
        let px: CGFloat = value.predictedEndTranslation.width
        let py: CGFloat = value.predictedEndTranslation.height
        if -dy > abs(dx), -dy > 40 || py < -160 { return .up }
        if abs(dx) > abs(dy) * 1.2, abs(dx) > 40 || abs(px) > 200 {
            return dx < 0 ? .next : .previous
        }
        return nil
    }

    static var gesture: DragGesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
    }
}

struct DeckTabsBar: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.deckOpenPlayer) private var openPlayer
    @Query(NewEpisodes.queryForList) private var unplayed: [PodcastEpisode]
    @Query(DeckTabSource.startedQuery) private var started: [PodcastEpisode]
    @Binding var tab: Int

    /// A big play disc and a pill of words (Paul, 22 Nov 2026: "I quite
    /// like disc and pill", M3 from
    /// https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3): the disc is
    /// what's playing (its artwork filling with colour as you listen, a
    /// ring round it); tap to play / pause, touch and hold to open it.
    /// The pill is Tabs · n, Shows and Find.
    static let height: CGFloat = 70
    /// Room under every list's last row: the bar, its gap below, the fade
    /// and 16 pt to spare.
    static let room: CGFloat = height + 8 + 16 + 20
    /// Between the Up next · Started pill and the bar.
    static let pillGap: CGFloat = 10
    /// The Tabs page's extra room for that pill: none now (Paul, 16 Nov
    /// 2026: "we drop the new pill. so the up next tab is simple"); the
    /// Tabs page is always Up next. `DeckTabGroupPill` is kept, unused,
    /// in case the groups come back.
    static let pillRoom: CGFloat = 0

    var body: some View {
        let tabs: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                        unplayed: unplayed, started: started)
        bar(count: tabs.count)
    }

    private func bar(count: Int) -> some View {
        HStack(spacing: 12) {
            DeckBarDisc(first: firstTab, open: openPlayer)
            DeckBarWords(current: tab, count: sectionCount, select: select)
                .simultaneousGesture(DeckBarSwipe.gesture.onEnded { value in swiped(value) })
        }
        .frame(height: Self.height)
        .padding(.horizontal, 16)
    }

    /// The top of Up next, so the ring can start it when nothing's on.
    private var firstTab: PodcastEpisode? {
        DeckTabSource.upNext(store: store, player: player).first
    }

    /// Up next's length, the same count the words row always showed.
    private var sectionCount: Int {
        let playing: String? = player.nowPlaying?.episodeID
        let queued: Int = store.queue.filter { $0.episode.id != playing }.count
        return queued + (playing == nil ? 0 : 1)
    }

    /// Moves to a section at once; Tabs also goes back to the overview.
    private func select(_ index: Int) {
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        // Tapped the page already showing: back to its first screen.
        if tab == index && index != 0 && !model.pagerOpen {
            NotificationCenter.default.post(name: .deckPageToStart, object: index)
            return
        }
        withTransaction(instant) {
            if index == 0 {
                model.returnTab = 0
                model.pagerOpen = false
            }
            tab = index
        }
    }

    /// Swipe up for the tab overview; swipe along the bar for the section
    /// before / after (Paul, 16 Nov 2026: option A).
    private func swiped(_ value: DragGesture.Value) {
        guard let swipe = DeckBarSwipe.resolve(value) else { return }
        switch swipe {
        case .up:
            select(0)
        case .next:
            if tab < 2 { select(tab + 1) }
        case .previous:
            if tab > 0 { select(tab - 1) }
        }
    }
}

/// The tab groups as chips in a small white pill just above the bar, on
/// the Tabs page only (Paul, 16 Nov 2026: "up next, new and started as
/// chips above the bar"). The chosen group is ink with its count; the
/// others are muted words. Tap one, or swipe along the pill for the group
/// before / after. Switching is instant.
struct DeckTabGroupPill: View {
    @Environment(DeckTabsModel.self) private var model
    /// How many tabs the chosen group has.
    let count: Int

    static let chipHeight: CGFloat = 31
    static let height: CGFloat = chipHeight + 8

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DeckTabGroup.allCases, id: \.self) { group in
                chip(group)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.14), radius: 10, y: 8)
        .simultaneousGesture(DeckBarSwipe.gesture.onEnded { value in swiped(value) })
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
    }

    private func chip(_ group: DeckTabGroup) -> some View {
        let on: Bool = model.group == group
        let title: String = on ? group.name + " · \(count)" : group.name
        return Button { choose(group) } label: {
            Text(title)
                .font(Theme.outfit(13, .bold))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(on ? Theme.surface : Theme.muted)
                .padding(.horizontal, 13)
                .frame(height: Self.chipHeight)
                .background(Capsule().fill(on ? Theme.ink : Color.clear))
                .contentShape(Capsule())
                .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? group.name + ", \(count) tabs" : group.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func choose(_ group: DeckTabGroup) {
        guard model.group != group else { return }
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { model.choose(group) }
    }

    private func swiped(_ value: DragGesture.Value) {
        guard let swipe = DeckBarSwipe.resolve(value) else { return }
        let all: [DeckTabGroup] = DeckTabGroup.allCases
        guard let at = all.firstIndex(of: model.group) else { return }
        switch swipe {
        case .up:
            return
        case .next:
            if at + 1 < all.count { choose(all[at + 1]) }
        case .previous:
            if at > 0 { choose(all[at - 1]) }
        }
    }
}


/// The bar's play disc: what's playing (or the top of Up next) as round
/// artwork in a ring, the colour sweeping in as you listen, with play /
/// pause on it. Tap plays or pauses; touch and hold opens its tab.
private struct DeckBarDisc: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let first: PodcastEpisode?
    let open: () -> Void

    private static let size: CGFloat = 70
    private static let ink: Color = Color(red: 28 / 255, green: 27 / 255, blue: 26 / 255)

    var body: some View {
        ZStack {
            Circle()
                .fill(Self.ink)
                .shadow(color: Color.black.opacity(0.28), radius: 12, y: 8)
            art
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: 40, height: 40)
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color.white)
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Circle())
        .onTapGesture { playPause() }
        // G3 (Paul, 22 Nov 2026): swipe the disc up for the player, like
        // Apple Music; a small handle above it says so.
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            guard value.translation.height < -30, abs(value.translation.width) < abs(value.translation.height),
                  player.nowPlaying != nil else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            open()
        })
        .overlay(alignment: .top) {
            Capsule()
                .fill(Theme.ink.opacity(0.3))
                .frame(width: 22, height: 4)
                .offset(y: -12)
                .opacity(player.nowPlaying == nil ? 0 : 1)
                .allowsHitTesting(false)
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard player.nowPlaying != nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            open()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(player.nowPlaying?.title ?? first?.title ?? "Nothing playing")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { playPause() }
        .accessibilityAction(named: "Open player") { if player.nowPlaying != nil { open() } }
    }

    @ViewBuilder private var art: some View {
        if let item = player.nowPlaying {
            DeckBarDiscLive(item: item, size: Self.size - 6)
        } else if let first {
            DeckRingArtwork(url: first.artwork, showTitle: first.showTitle, size: Self.size - 6,
                            progress: DeckRing.progress(of: first), lineWidth: 3.5, gap: 3,
                            colour: Color.white, track: Color.white.opacity(0.2))
        } else {
            Circle().fill(Color.white.opacity(0.12)).frame(width: Self.size - 14, height: Self.size - 14)
        }
    }

    private func playPause() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if player.nowPlaying != nil {
            player.togglePlayPause()
        } else if let first {
            DeckQueueMoves(store: store, player: player).playNow(first)
        }
    }
}

/// The disc's artwork and ring for the one playing; only this follows
/// the clock.
private struct DeckBarDiscLive: View {
    @Environment(PlayerModel.self) private var player
    let item: PlayerModel.NowPlaying
    let size: CGFloat

    var body: some View {
        let progress: Double = player.duration > 0 ? player.currentTime / player.duration : 0
        DeckRingArtwork(url: item.artworkURL, showTitle: item.showTitle, size: size,
                        progress: progress, lineWidth: 3.5, gap: 3,
                        colour: Color.white, track: Color.white.opacity(0.2))
    }
}

/// The bar's pill: Tabs · n, Shows, Find; the page showing in ink.
private struct DeckBarWords: View {
    let current: Int
    let count: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            word(count > 0 ? "Tabs · \(count)" : "Tabs", index: 0)
            word("Shows", index: 1)
            word("Find", index: 2)
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.16), radius: 11, y: 8)
    }

    private func word(_ text: String, index: Int) -> some View {
        let on: Bool = current == index
        return Button { select(index) } label: {
            Text(text)
                .font(Theme.outfit(15, .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(on ? Theme.surface : Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(on ? Theme.ink : Color.clear))
                .contentShape(Capsule())
                .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
