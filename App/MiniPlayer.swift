import SwiftUI
import PodcastCore

extension View {
    /// Shows the "now playing" bar at the bottom of a tab while something is loaded.
    func miniPlayer(_ showingPlayer: Binding<Bool>) -> some View {
        modifier(MiniPlayerInset(showingPlayer: showingPlayer))
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(PlayerModel.self) private var player
    @Binding var showingPlayer: Bool

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if player.nowPlaying != nil {
                MiniPlayer { showingPlayer = true }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }
}

/// The "now playing" strip: a small deck display above the tabs.
struct MiniPlayer: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    var body: some View {
        if let item = player.nowPlaying {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: open) {
                        HStack(spacing: 10) {
                            ArtworkView(url: item.artworkURL, title: item.showTitle, size: 38, radius: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.uppercased())
                                    .font(Theme.mono(12, .semibold))
                                    .foregroundStyle(Theme.displayText)
                                    .lineLimit(1)
                                Text("\(TimeFormat.clock(player.currentTime)) / \(TimeFormat.clock(player.duration))")
                                    .font(Theme.mono(11))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.displayDim)
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
                                .padding(.horizontal, 10)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.accentKey)
                        .accessibilityLabel("Skip ad")
                    }
                    SkipButton(direction: .back)
                        .foregroundStyle(Theme.displayText)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body)
                            .frame(width: 44, height: 40)
                    }
                    .buttonStyle(.key)
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    SkipButton(direction: .forward)
                        .foregroundStyle(Theme.displayText)
                }
                SegmentBar(progress: progress, ads: adFractions, count: 32, height: 4)
            }
            .tint(Theme.displayText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.display, in: RoundedRectangle(cornerRadius: 14))
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
