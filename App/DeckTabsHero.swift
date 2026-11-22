import SwiftUI
import PodcastCore

// U1 "now playing hero" (Paul, 21 Nov 2026: "Go with U1 and the island";
// mock-up and prototype https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3).
// The first tab on the Tabs page, big: its artwork, fading into the show's
// colour, "PLAYING NOW" / "PAUSED" / "UP FIRST", ✓ Played, the show and
// title, a progress line with the time played and left, and a big play /
// pause button. Tap the card for its tab page, as with any tab.

struct DeckTabsHero: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    /// The same height as the tabs under it (Paul, 22 Nov 2026: "keep it
    /// wide but make it the same height as the other cards").
    let height: CGFloat

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var colour: Color { DeckRings.showColour(episode) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        HStack(spacing: 0) {
            words
            artwork
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(colour)
        .clipShape(shape)
        .background {
            shape.fill(colour)
                .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.16), radius: 12, y: 7)
        }
        .contentShape(shape)
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
    }

    /// Square artwork on the right, fading into the show's colour on its
    /// left edge; black and white until started, filling with colour.
    private var artwork: some View {
        Color.clear
            .frame(width: height, height: height)
            .overlay {
                DeckColourFill(url: episode.artwork, showTitle: episode.showTitle, progress: heard)
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .leading) {
                LinearGradient(colors: [colour, colour.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: height * 0.4)
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }

    /// How far through: live for the one playing, else its saved place.
    private var heard: Double {
        if isOn, player.duration > 0 { return player.currentTime / player.duration }
        return DeckRing.progress(of: episode)
    }

    private var label: some View {
        Text(isOn ? (player.isPlaying ? "PLAYING NOW" : "PAUSED") : "UP FIRST")
            .font(Theme.outfit(9.5, .heavy))
            .tracking(0.8)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.28)))
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
            Text(episode.showTitle.uppercased())
                .font(Theme.outfit(9.5, .bold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .padding(.top, 8)
            Text(episode.title)
                .font(Theme.outfit(16, .heavy))
                .tracking(-0.2)
                .foregroundStyle(Color.white)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 3)
            Spacer(minLength: 6)
            DeckTabsHeroProgress(episode: episode, isOn: isOn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 12)
        .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
    }

    /// Where the play key sits on the card (bottom right, over the artwork).
    static let playInset: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 12)
}

/// The hero's big white play / pause key.
struct DeckTabsHeroPlay: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var playing: Bool { isOn && player.isPlaying }
    private var colour: Color { DeckRings.showColour(episode) }
    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }

    var body: some View {
        playButton
    }

    private var playButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isOn { player.togglePlayPause() } else { actions.playNow(episode) }
        } label: {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 19))
                .foregroundStyle(colour)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white))
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "Pause" : "Play")
    }
}

/// The hero's progress line with the time played and left: follows the
/// player's clock while it's the one on (only this small view does).
private struct DeckTabsHeroProgress: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let isOn: Bool

    private var length: TimeInterval {
        if isOn && player.duration > 0 { return player.duration }
        return episode.duration ?? 0
    }

    private var at: TimeInterval { isOn ? player.currentTime : episode.position }

    private var fraction: Double {
        guard length > 0 else { return 0 }
        return min(1, max(0, at / length))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.28))
                    Capsule().fill(Color.white)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
            HStack {
                Text(at > 0 ? TimeFormat.clock(at) : DeckUpNextTime.length(length))
                Spacer(minLength: 8)
                Text(length > 0 ? DeckUpNextTime.length(max(0, length - at)) + " left" : "")
            }
            .font(Theme.outfit(11, .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.9))
        }
        .accessibilityElement(children: .combine)
    }
}
