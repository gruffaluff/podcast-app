import SwiftUI
import PodcastCore

/// The mini player (Native warm, Paul 11 Nov 2026): iOS's own bar above the
/// tab bar (the tab view's bottom accessory), like Apple Music. Artwork,
/// the episode and time left, then play / pause and skip forward. Tap it,
/// or swipe it up, for the player. With nothing playing it shows the top
/// of Up Next ready to play: its artwork and title, "Up next · Show · 26m"
/// (or "Carry on · 12m left" once started) and a play key in a progress ring.
struct NowPlayingBar: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openOrStart) {
                HStack(spacing: 10) {
                    ArtworkView(url: player.nowPlaying?.artworkURL ?? upcoming?.artwork,
                                title: player.nowPlaying?.showTitle ?? upcoming?.showTitle ?? "Poddeck", size: 34, radius: 7)
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
            } else if let upcoming {
                // Ready to play (Paul's B, 12 Nov 2026): the ring shows how
                // far through it is when it's been started.
                Button { player.play(upcoming) } label: {
                    ZStack {
                        Circle().stroke(Theme.ink.opacity(0.18), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: Self.fraction(upcoming))
                            .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .offset(x: 1)
                    }
                    .frame(width: 32, height: 32)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play \(upcoming.title)")
            }
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .padding(.horizontal, 12)
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
            if value.translation.height < -20, player.nowPlaying != nil { open() }
        })
    }

    /// With nothing playing: the top of Up Next, shown ready to play.
    private var upcoming: PodcastEpisode? {
        guard player.nowPlaying == nil, let first = store.queue.first else { return nil }
        return store.episode(first.episode.id)
    }

    /// How far through it is (0 when not started).
    private static func fraction(_ episode: PodcastEpisode) -> CGFloat {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, episode.position / duration)))
    }

    private var title: String {
        player.nowPlaying?.title ?? upcoming?.title ?? "Nothing playing"
    }

    private var detail: String {
        guard let item = player.nowPlaying else {
            guard let upcoming else { return "Up Next is empty" }
            // "Carry on · 12m left" once started, else "Up next · Show · 26m".
            if upcoming.position > 5, let left = upcoming.timeLeft, left > 0 {
                return "Carry on · \(TimeFormat.length(left)) left"
            }
            let length = upcoming.duration.map { TimeFormat.length($0) } ?? ""
            return ["Up next", upcoming.showTitle, length].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        guard player.duration > 0 else { return item.showTitle }
        let left = max(0, player.duration - player.currentTime)
        return "\(item.showTitle) · \(TimeFormat.clock(left)) left"
    }

    private func openOrStart() {
        if player.nowPlaying != nil {
            open()
        } else if let upcoming {
            player.play(upcoming)
        }
    }
}
