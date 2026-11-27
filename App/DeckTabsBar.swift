import SwiftUI
import SwiftData
import PodcastCore

// The bottom bar, B1 (Paul, 27 Nov 2026, from
// https://claude.ai/artifact/94LKhvKijV5iefrskQ6zUV): a white mini player
// card (the R2 player in small) floating over a strip of three icon tabs,
// Tabs · n / Shows / Find. Swipe up on the strip for the tab overview,
// along it for the page before / after; tap or swipe up the card for the
// player.

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
    @Environment(\.deckOpenPlayer) private var openPlayer
    @Environment(\.deckOpenSearch) private var openSearch

    /// Just the mini player card now (option C, 27 Nov 2026: no tab strip;
    /// the pages switch at their top).
    static let cardHeight: CGFloat = 58
    static let height: CGFloat = cardHeight
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
        DeckMiniCard(first: firstTab, open: openPlayer, find: openSearch)
            .frame(height: Self.height)
            .padding(.horizontal, 12)
    }

    /// The top of Up next, so the card can start it when nothing's on.
    private var firstTab: PodcastEpisode? {
        DeckTabSource.upNext(store: store, player: player).first
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


/// The mini player card (B1): artwork, title, show · time left, skip
/// back, play / pause and skip forward, a thin progress line along its foot. Tap it (or
/// swipe it up) for the player. With nothing on it offers the top of Up
/// next, ready to play; with Up next empty, Find something.
private struct DeckMiniCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let first: PodcastEpisode?
    let open: () -> Void
    let find: () -> Void

    private static let radius: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        ZStack(alignment: .bottom) {
            HStack(spacing: 10) {
                artwork
                words
                Spacer(minLength: 0)
                keys
            }
            .padding(.leading, 9)
            .padding(.trailing, 6)
            .frame(maxHeight: .infinity)
            line
        }
        .background(shape.fill(Theme.surface))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.16), radius: 11, y: 8)
        .contentShape(shape)
        .onTapGesture { tapped() }
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            guard value.translation.height < -30, abs(value.translation.width) < abs(value.translation.height),
                  player.nowPlaying != nil else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            open()
        })
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open player") { if player.nowPlaying != nil { open() } }
    }

    // MARK: Parts

    private var artURL: URL? { player.nowPlaying?.artworkURL ?? first?.artwork }
    private var showName: String { player.nowPlaying?.showTitle ?? first?.showTitle ?? "" }

    @ViewBuilder private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if player.nowPlaying != nil || first != nil {
            CachedImage(url: artURL) {
                shape.fill(Theme.placeholderColor(for: showName))
                    .overlay(Text(Theme.initials(for: showName))
                        .font(Theme.outfit(13, .bold))
                        .foregroundStyle(Color.white))
            }
            .frame(width: 40, height: 40)
            .clipShape(shape)
            .accessibilityHidden(true)
        } else {
            shape.fill(Theme.ink.opacity(0.06))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let item = player.nowPlaying {
                title(item.title)
                DeckMiniCardLeft(show: item.showTitle)
            } else if let first {
                title(first.title)
                Text(restingLine(first))
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            } else {
                title("Up next is empty")
                Text("Find something to listen to ›")
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Theme.outfit(15, .bold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
    }

    /// "Up next · Show · 26m", or "Carry on · Show · 12m left" once started.
    private func restingLine(_ episode: PodcastEpisode) -> String {
        let progress: Double = DeckRing.progress(of: episode)
        if progress > 0, let left = episode.timeLeft {
            return "Carry on · \(episode.showTitle) · \(TimeFormat.length(left)) left"
        }
        if let length = episode.duration {
            return "Up next · \(episode.showTitle) · \(TimeFormat.length(length))"
        }
        return "Up next · \(episode.showTitle)"
    }

    @ViewBuilder private var keys: some View {
        if player.nowPlaying != nil || first != nil {
            HStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipBackward()
                } label: {
                    Image(systemName: "gobackward.\(player.skipBackSeconds)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(player.nowPlaying == nil)
                .opacity(player.nowPlaying == nil ? 0.3 : 1)
                .accessibilityLabel("Skip back \(player.skipBackSeconds) seconds")
                Button { playPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipForwardBy()
                } label: {
                    Image(systemName: "goforward.\(player.skipForwardSeconds)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(player.nowPlaying == nil)
                .opacity(player.nowPlaying == nil ? 0.3 : 1)
                .accessibilityLabel("Skip forward \(player.skipForwardSeconds) seconds")
            }
        }
    }

    @ViewBuilder private var line: some View {
        if player.nowPlaying != nil {
            DeckMiniCardLine()
        } else if let first {
            DeckMiniProgressLine(progress: DeckRing.progress(of: first))
        }
    }

    // MARK: Actions

    private func tapped() {
        if player.nowPlaying != nil {
            open()
        } else if first != nil {
            playPause()
        } else {
            find()
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

/// "Show · 54m left" at your speed; only this follows the clock.
private struct DeckMiniCardLeft: View {
    @Environment(PlayerModel.self) private var player
    let show: String

    var body: some View {
        let left: TimeInterval = max(0, player.duration - player.currentTime) / max(player.speed, 0.5)
        // The show's name gives way first, so the time left always shows.
        HStack(spacing: 0) {
            Text(show)
                .lineLimit(1)
            if player.duration > 0 {
                Text(" · \(TimeFormat.length(left)) left")
                    .lineLimit(1)
                    .fixedSize()
                    .layoutPriority(1)
            }
        }
        .font(Theme.outfit(12, .medium))
        .monospacedDigit()
        .foregroundStyle(Theme.muted)
    }
}

/// The live progress line along the card's foot.
private struct DeckMiniCardLine: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        let progress: Double = player.duration > 0 ? player.currentTime / player.duration : 0
        DeckMiniProgressLine(progress: progress)
    }
}

/// A 3 pt line, ink as far as you've got, faint ahead.
private struct DeckMiniProgressLine: View {
    let progress: Double

    var body: some View {
        // Inset from the card's rounded corners so its ends aren't cut.
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.1))
                Capsule().fill(Theme.ink)
                    .frame(width: max(3, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }
}
