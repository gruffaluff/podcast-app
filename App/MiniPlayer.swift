import SwiftUI
import UIKit
import Combine
import PodcastCore

extension View {
    /// The bottom of every tab: the "now playing" bar (while something is
    /// loaded) joined to the app's own tab bar, in one printed block.
    func miniPlayer(_ showingPlayer: Binding<Bool>, tab: Binding<Int>) -> some View {
        modifier(MiniPlayerInset(showingPlayer: showingPlayer, tab: tab))
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(PlayerModel.self) private var player
    @Binding var showingPlayer: Bool
    @Binding var tab: Int
    /// The bar steps aside while typing, so search results and their play
    /// keys are never hidden under it.
    @State private var keyboardUp = false

    private var playing: Bool { player.nowPlaying != nil }

    func body(content: Content) -> some View {
        // The bar floats over the page. Lists get extra room at the bottom
        // (content margins reach every list inside), so their last rows
        // scroll clear of it.
        content
            .contentMargins(.bottom, keyboardUp ? 0 : (playing ? MiniPlayer.height : 0) + PosterTabBar.height + 8, for: .scrollContent)
            // iOS's own tab bar (a floating white capsule on iOS 26) is
            // hidden; ours sits under the mini player (Paul, 11 Nov 2026).
            .toolbarVisibility(.hidden, for: .tabBar)
            .overlay(alignment: .bottom) {
                VStack(spacing: 6) {
                    OfflineBar()
                        .padding(.horizontal, 12)
                    UndoBar()
                        .padding(.horizontal, 12)
                    if !keyboardUp {
                        dock
                    }
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
    }

    /// The mini player and the tab bar in one block with curved top
    /// corners, running down to the bottom edge: printed in the colour of
    /// what's playing, or the dark display colour when nothing is.
    private var dock: some View {
        VStack(spacing: 0) {
            if playing {
                MiniPlayer { showingPlayer = true }
            }
            PosterTabBar(tab: $tab)
        }
        .padding(.top, playing ? 0 : 6)
        .background {
            DockBackground(url: player.nowPlaying?.artworkURL)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
        }
    }
}

private struct DockBackground: View {
    let url: URL?

    var body: some View {
        if let url {
            PrintedArtwork(url: url, colour: ArtworkColors.shared.background(for: url) ?? Theme.display, strength: 0.45)
        } else {
            Theme.display.overlay { Halftone() }
        }
    }
}

/// The app's own tab bar: four flat icons with small DM Mono labels on the
/// printed dock; the one you're on full strength, the others faded.
struct PosterTabBar: View {
    @Binding var tab: Int
    static let height: CGFloat = 52

    private static let tabs: [(title: String, icon: String)] = [
        ("Up Next", "list.bullet"), ("Library", "square.grid.2x2"), ("Discover", "safari"), ("Search", "magnifyingglass"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs.indices, id: \.self) { index in
                let item = Self.tabs[index]
                let selected = tab == index
                Button { tab = index } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: selected ? .semibold : .regular))
                        Text(item.title.uppercased())
                            .font(.custom("DMMono-Medium", fixedSize: 9))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Theme.displayText.opacity(selected ? 1 : 0.6))
                    .frame(maxWidth: .infinity, minHeight: Self.height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 8)
    }
}

/// The "now playing" bar: the top of the player card peeking up above the
/// tabs, full width with curved top corners, in the colour of the
/// episode's artwork. Tap (or swipe up) to open the player.
struct MiniPlayer: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void
    /// The bar's height above the tab bar.
    static let height: CGFloat = 76

    var body: some View {
        if let item = player.nowPlaying {
            let tint = ArtworkColors.shared.background(for: item.artworkURL) ?? Theme.display
            VStack(spacing: 6) {
                Capsule().fill(Theme.displayText.opacity(0.45)).frame(width: 34, height: 4)
                HStack(spacing: 10) {
                    Button(action: open) {
                        HStack(spacing: 10) {
                            // The poster look: the artwork as a square stamp,
                            // a small time / chapter line and the title in
                            // big capitals.
                            Stamp(url: item.artworkURL, title: item.showTitle, size: 38)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(miniLabel.uppercased())
                                    .font(.custom("DMMono-Regular", fixedSize: 9.5))
                                    .tracking(0.8)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.displayDim)
                                    .lineLimit(1)
                                Text(item.title)
                                    .font(.custom("BarlowCondensed-Medium", fixedSize: 19))
                                    .foregroundStyle(Theme.displayText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the player")

                    if player.currentAd != nil {
                        Button { player.skipCurrentAd() } label: {
                            Text("SKIP AD")
                                .font(Theme.mono(11, .bold))
                                .foregroundStyle(Theme.adText)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 32)
                                .background(Theme.highlight, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip ad")
                    }
                    // Skip back, play, skip forward (Paul); chapter keys are in
                    // the full player and the chapter list.
                    SkipButton(direction: .back, iconSize: 16, frame: 40)
                        .foregroundStyle(Theme.displayText)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(tint)
                            .frame(width: 40, height: 40)
                            .background(Theme.displayText, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    SkipButton(direction: .forward, iconSize: 16, frame: 40)
                        .foregroundStyle(Theme.displayText)
                }
                GeometryReader { geometry in
                    Capsule().fill(Theme.displayText.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.displayText).frame(width: geometry.size.width * progress)
                        }
                }
                .frame(height: 3)
            }
            .tint(Theme.displayText)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(height: MiniPlayer.height, alignment: .top)
            // Its printed background is drawn by the dock it sits in, which
            // runs on down behind the tab bar.
            .contentShape(Rectangle())
            // Alongside the keys' taps, not instead of them.
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -20 { open() }
            })
            .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
        }
    }

    /// "16:45 · CH 4 · 32M LEFT", or the show while nothing has loaded.
    private var miniLabel: String {
        guard let item = player.nowPlaying else { return "" }
        guard player.duration > 0 else { return item.showTitle }
        var parts = [TimeFormat.clock(player.currentTime)]
        if let chapter = player.chapters.lastIndex(where: { $0.start <= player.currentTime }) {
            parts.append("CH \(chapter + 1)")
        }
        parts.append("\(TimeFormat.clock(max(0, player.duration - player.currentTime))) left")
        return parts.joined(separator: " · ")
    }

    private var progress: Double {
        player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }
}
