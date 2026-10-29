import SwiftUI

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

struct MiniPlayer: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    var body: some View {
        if let item = player.nowPlaying {
            HStack(spacing: 12) {
                Button(action: open) {
                    HStack(spacing: 12) {
                        ArtworkView(url: item.artworkURL, title: item.showTitle, size: 40, radius: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(item.showTitle)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
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
                        Text("Skip ad")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .foregroundStyle(Theme.background)
                            .background(Theme.ink, in: Capsule())
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Skip ad")
                }
                SkipButton(direction: .back)
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                SkipButton(direction: .forward)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .font(.body)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
