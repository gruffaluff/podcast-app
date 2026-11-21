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

    static let height: CGFloat = 318

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var playing: Bool { isOn && player.isPlaying }
    private var colour: Color { DeckRings.showColour(episode) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            colour
            artwork
            fade
            words
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .clipShape(shape)
        .overlay(alignment: .topLeading) { label }
        .overlay(alignment: .topTrailing) { playedButton }
        .background {
            shape.fill(colour)
                .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.18), radius: 14, y: 8)
        }
        .contentShape(shape)
        .onTapGesture { model.open(episode.episodeID) }
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open") { model.open(episode.episodeID) }
    }

    private var artwork: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.height * 0.73)
                .overlay {
                    CachedImage(url: episode.artwork) { Theme.placeholderColor(for: episode.showTitle) }
                        .scaledToFill()
                }
                .clipped()
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var fade: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: colour.opacity(0), location: 0.32),
                .init(color: colour.opacity(0.85), location: 0.6),
                .init(color: colour, location: 0.74),
            ], startPoint: .top, endPoint: .bottom)
            LinearGradient(stops: [
                .init(color: Color.black.opacity(0), location: 0.5),
                .init(color: Color.black.opacity(0.2), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }

    private var label: some View {
        Text(isOn ? (player.isPlaying ? "PLAYING NOW" : "PAUSED") : "UP FIRST")
            .font(Theme.outfit(11, .heavy))
            .tracking(0.8)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .padding(14)
            .allowsHitTesting(false)
    }

    private var playedButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(LibraryStore.listChange) { actions.close(episode) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                Text("Played")
                    .font(Theme.outfit(12, .bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel("Mark played")
    }

    private var words: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(episode.showTitle.uppercased())
                    .font(Theme.outfit(10, .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                Text(episode.title)
                    .font(Theme.outfit(22, .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Color.white)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
                DeckTabsHeroProgress(episode: episode, isOn: isOn)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            playButton
                .padding(.bottom, 22)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var playButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isOn { player.togglePlayPause() } else { actions.playNow(episode) }
        } label: {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
                .foregroundStyle(colour)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.white))
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
            .font(Theme.outfit(12, .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.9))
        }
        .accessibilityElement(children: .combine)
    }
}
