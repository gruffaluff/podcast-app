import SwiftUI
import PodcastCore

// Rings across the app (Paul, 15 Nov 2026: rings, "1 · The dial" on
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7). One shape for "this
// far through" everywhere: round artwork inside a thin ring. Up next's top
// card (the circle turns over to the words), the cards under it and the
// full list, Carry on, Saved for later, suggestions, the mini player, and
// a coral ring for new episodes not started yet. Built on `DeckRing` /
// `DeckRingArtwork` (DeckRing.swift).

@MainActor
enum DeckRings {
    /// New and not started yet, like an unread story.
    static let coral = Color(hex: 0xEC6550)

    /// The show's colour (from its artwork), or its placeholder colour
    /// until that's measured.
    static func showColour(_ episode: PodcastEpisode) -> Color {
        let url: URL? = episode.podcast?.artworkURL ?? episode.artwork
        return ArtworkColors.shared.background(for: url) ?? Theme.placeholderColor(for: episode.showTitle)
    }

    /// How far through, but 0 until it has really been started, so lists
    /// only fill the ring for episodes that are on their way. A started
    /// episode always shows a little arc.
    static func startedProgress(of episode: PodcastEpisode) -> Double {
        if episode.played { return 1 }
        guard let duration = episode.duration, duration > 0, episode.position > 5 else { return 0 }
        return min(1, max(0.03, episode.position / duration))
    }
}

/// Round artwork for list rows (Up next's stacked cards and full list,
/// suggestions, Saved for later): the track is always drawn faintly, the
/// fill only once the episode has been started.
struct DeckListRingArtwork: View {
    let episode: PodcastEpisode
    let size: CGFloat
    var lineWidth: CGFloat = 3
    var gap: CGFloat = 3
    var colour: Color = Theme.ink
    var track: Color = Theme.cardLine

    var body: some View {
        let progress: Double = DeckRings.startedProgress(of: episode)
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: size,
                        progress: progress, lineWidth: lineWidth, gap: gap,
                        colour: progress > 0 ? colour : Color.clear, track: track)
    }
}

/// Round artwork for a new episode: a full coral ring while it's not been
/// started; once started, the coral fills as far as you've got.
struct DeckNewRingArtwork: View {
    let episode: PodcastEpisode
    let size: CGFloat
    var lineWidth: CGFloat = 3
    var gap: CGFloat = 3

    var body: some View {
        let progress: Double = DeckRings.startedProgress(of: episode)
        let started: Bool = progress > 0
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: size,
                        progress: started ? progress : 0, lineWidth: lineWidth, gap: gap,
                        colour: started ? DeckRings.coral : Color.clear,
                        track: started ? DeckRings.coral.opacity(0.25) : DeckRings.coral)
    }
}

/// Round artwork in a ring of the show's colour at its saved place (Carry
/// on on the Shows tab).
struct DeckShowRingArtwork: View {
    let episode: PodcastEpisode
    let size: CGFloat
    var lineWidth: CGFloat = 3
    var gap: CGFloat = 2

    var body: some View {
        let progress: Double = max(0.03, DeckRing.progress(of: episode))
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: size,
                        progress: progress, lineWidth: lineWidth, gap: gap,
                        colour: DeckRings.showColour(episode), track: Theme.cardLine)
            .task(id: episode.podcast?.artworkURL) { await ArtworkColors.shared.load(episode.podcast?.artworkURL) }
    }
}

/// The mini player's artwork on Shows / Find: round, in a ring of the
/// show's colour showing live progress. Only this small view follows the
/// player's clock.
struct DeckMiniRingArtwork: View {
    @Environment(PlayerModel.self) private var player
    let item: PlayerModel.NowPlaying
    var size: CGFloat = 46

    var body: some View {
        let duration: TimeInterval = player.duration
        let fraction: Double = duration > 0 ? min(1, max(0, player.currentTime / duration)) : 0
        let colour: Color = ArtworkColors.shared.background(for: item.artworkURL)
            ?? Theme.placeholderColor(for: item.showTitle)
        DeckRingArtwork(url: item.artworkURL, showTitle: item.showTitle, size: size,
                        progress: fraction, lineWidth: 3, gap: 2,
                        colour: colour, track: Theme.cardLine)
            .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
    }
}

/// Up next's top card picture: round artwork in a ~6 pt ring of the show's
/// colour showing how far through (live for the episode playing, while the
/// card is on screen: `info.time` already follows that rule). The words key
/// turns the circle over to the line being said (white on a dark circle of
/// the show's colour) with the ring still round it. Download key at the
/// circle's bottom left, words key bottom right. Only shows progress: no
/// scrubbing here (the card's swipes stay as they are).
struct DeckTopRing: View {
    let info: DeckTopInfo
    let words: DeckTopWords
    let actions: DeckTopActions
    let side: CGFloat

    private static let lineWidth: CGFloat = 6
    private static let gap: CGFloat = 6

    var body: some View {
        let inner: CGFloat = max(0, side - 2 * (Self.lineWidth + Self.gap))
        ZStack {
            DeckRing(progress: info.fraction, lineWidth: Self.lineWidth,
                     colour: info.colour, track: Theme.cardLine)
            faces(inner)
                .frame(width: inner, height: inner)
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 5)
        }
        .frame(width: side, height: side)
        .overlay(alignment: .bottomLeading) {
            DeckTopDownloadKey(state: words.download, action: actions.downloadTapped)
        }
        .overlay(alignment: .bottomTrailing) {
            DeckTopWordsSwitch(showing: words.showing, action: actions.toggleWords)
        }
        .animation(.easeInOut(duration: 0.35), value: words.showing)
    }

    /// The artwork on the front, the words on the back.
    private func faces(_ inner: CGFloat) -> some View {
        let showing: Bool = words.showing
        let axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (x: 0, y: 1, z: 0)
        return ZStack {
            front
                .rotation3DEffect(.degrees(showing ? 180 : 0), axis: axis)
                .opacity(showing ? 0 : 1)
            back(inner)
                .rotation3DEffect(.degrees(showing ? 0 : -180), axis: axis)
                .opacity(showing ? 1 : 0)
                .allowsHitTesting(showing)
        }
    }

    private var front: some View {
        Color.clear
            .overlay {
                CachedImage(url: info.episode.artwork) { Theme.placeholderColor(for: info.episode.showTitle) }
            }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func back(_ inner: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [info.colour, info.dark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            DeckTopWordsView(words: words, transcribe: actions.transcribe,
                             stop: actions.stopTranscribing, circle: inner)
        }
        .clipShape(Circle())
    }
}
