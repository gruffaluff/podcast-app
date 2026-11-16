import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): Safari's bottom bar, in place
// of the pill and mini player. It shows what's on (tap for the player);
// on Your shows / Find it also has the tab count square, back to the
// overview. Safari's gestures (Paul: "Swipe up to get to tabs etc"): swipe
// up on the bar for the overview, along it for the next / previous tab.

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

/// The tab count, in a rounded square like Safari's.
struct DeckTabCountSquare: View {
    let count: Int
    var colour: Color = Theme.ink

    var body: some View {
        Text("\(min(count, 99))")
            .font(Theme.outfit(12, .bold))
            .monospacedDigit()
            .foregroundStyle(colour)
            .frame(minWidth: 26, minHeight: 24)
            .padding(.horizontal, 2)
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(colour, lineWidth: 2))
    }
}

struct DeckTabsBar: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.deckOpenPlayer) private var openPlayer
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""
    @Binding var tab: Int

    static let height: CGFloat = 60
    /// Room under every list's last row: the bar, its gap below, the fade
    /// and 16 pt to spare.
    static let room: CGFloat = height + 8 + 16 + 20

    var body: some View {
        let tabs: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                        unplayed: unplayed, triaged: triaged, saved: savedRaw)
        HStack(spacing: 8) {
            DeckTabsBarNow(count: tabs.count, open: openPlayer)
            if tab != 0 {
                Button(action: overview) {
                    DeckTabCountSquare(count: tabs.count)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tabs, \(tabs.count) open")
                .accessibilityHint("Back to the tab overview")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .frame(height: Self.height)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.2), radius: 16, y: 8)
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
        .padding(.horizontal, 16)
        .simultaneousGesture(DeckBarSwipe.gesture.onEnded { value in swiped(value, tabs: tabs) })
    }

    private func overview() {
        withAnimation(.spring(duration: 0.35)) {
            model.pagerOpen = false
            tab = 0
        }
    }

    private func swiped(_ value: DragGesture.Value, tabs: [PodcastEpisode]) {
        guard let swipe = DeckBarSwipe.resolve(value) else { return }
        switch swipe {
        case .up:
            overview()
        case .next, .previous:
            model.openNeighbour(of: tabs, playingID: player.nowPlaying?.episodeID, forward: swipe == .next)
        }
    }
}

/// The bar's "what's on" part: ring artwork, title, show · time left and
/// play / pause. Follows the player's clock (only this small view does).
private struct DeckTabsBarNow: View {
    @Environment(PlayerModel.self) private var player
    let count: Int
    let open: () -> Void

    var body: some View {
        if let item = player.nowPlaying {
            HStack(spacing: 8) {
                Button(action: open) {
                    HStack(spacing: 10) {
                        // Smoother scrolling (Paul, 16 Nov 2026): only the
                        // ring and the time-left line follow the clock (twice
                        // a second), not the whole bar over the page.
                        DeckTabsBarRing(item: item)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(Theme.outfit(14, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            DeckMiniTimeLeft(item: item)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the player")
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.background)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.ink))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nothing playing")
                        .font(Theme.outfit(14, .bold))
                        .foregroundStyle(Theme.ink)
                    Text(count == 1 ? "1 tab open" : "\(count) tabs open")
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// The bar's ring artwork, following the player's clock.
private struct DeckTabsBarRing: View {
    @Environment(PlayerModel.self) private var player
    let item: PlayerModel.NowPlaying

    var body: some View {
        DeckRingArtwork(url: item.artworkURL, showTitle: item.showTitle, size: 44,
                        progress: progress, lineWidth: 3, gap: 2)
    }

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(1, max(0, player.currentTime / player.duration))
    }
}
