import SwiftUI
import PodcastCore

/// The mini player (Native warm, Paul 11 Nov 2026): iOS's own bar above the
/// tab bar (the tab view's bottom accessory), like Apple Music. Artwork,
/// the episode and time left, then play / pause and skip forward. Tap it,
/// or swipe it up, for the player. With nothing playing it offers the top
/// of Up Next.
struct NowPlayingBar: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openOrStart) {
                HStack(spacing: 10) {
                    ArtworkView(url: player.nowPlaying?.artworkURL, title: player.nowPlaying?.showTitle ?? "Poddeck", size: 34, radius: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(player.nowPlaying == nil ? "Plays the top of Up Next" : "Opens the player")

            if player.currentAd != nil {
                Button { player.skipCurrentAd() } label: {
                    Text("Skip ad")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.adText)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Theme.highlight, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            if player.nowPlaying != nil {
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                SkipButton(direction: .forward, iconSize: 18, frame: 36)
            }
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .padding(.horizontal, 12)
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
            if value.translation.height < -20, player.nowPlaying != nil { open() }
        })
    }

    private var title: String {
        player.nowPlaying?.title ?? "Nothing playing"
    }

    private var detail: String {
        guard let item = player.nowPlaying else {
            return store.queue.isEmpty ? "Up Next is empty" : "Tap to play Up Next"
        }
        guard player.duration > 0 else { return item.showTitle }
        let left = max(0, player.duration - player.currentTime)
        return "\(item.showTitle) · \(TimeFormat.clock(left)) left"
    }

    private func openOrStart() {
        if player.nowPlaying != nil {
            open()
        } else if let first = store.queue.first, let episode = store.episode(first.episode.id) {
            player.play(episode)
        }
    }
}
