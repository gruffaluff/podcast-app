import SwiftUI
import UIKit
import Combine
import PodcastCore

extension View {
    /// Shows the "now playing" bar at the bottom of a tab while something is loaded.
    func miniPlayer(_ showingPlayer: Binding<Bool>, showsPlayer: Bool = true) -> some View {
        modifier(MiniPlayerInset(showingPlayer: showingPlayer, showsPlayer: showsPlayer))
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(PlayerModel.self) private var player
    @Binding var showingPlayer: Bool
    var showsPlayer = true
    /// The mini player steps aside while typing, so search results and
    /// their play keys are never hidden under it.
    @State private var keyboardUp = false

    private var showing: Bool { showsPlayer && player.nowPlaying != nil && !keyboardUp }

    func body(content: Content) -> some View {
        // The bar floats over the page and its colour runs down behind the
        // tab bar. Lists get extra room at the bottom (content margins reach
        // every list inside), so their last rows scroll clear of it.
        content
            .contentMargins(.bottom, showing ? MiniPlayer.height + 8 : 0, for: .scrollContent)
            .overlay(alignment: .bottom) {
                VStack(spacing: 6) {
                    UndoBar()
                        .padding(.horizontal, 12)
                    if showing {
                        MiniPlayer { showingPlayer = true }
                    }
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
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
                            ArtworkView(url: item.artworkURL, title: item.showTitle, size: 38, radius: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.displayText)
                                    .lineLimit(1)
                                Text(player.duration > 0 ? "\(item.showTitle) · \(TimeFormat.clock(max(0, player.duration - player.currentTime))) left" : item.showTitle)
                                    .font(.system(size: 12))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.displayDim)
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
            // The card runs down behind the tab bar, like the player card
            // peeking up from below.
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                    .fill(tint)
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
            }
            .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -20 { open() }
            })
            .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
        }
    }

    private var progress: Double {
        player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }
}
