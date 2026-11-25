import SwiftUI
import PodcastCore

// Rings across the app (Paul, 15 Nov 2026: rings, "1 · The dial" on
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7). One shape for "this
// far through" everywhere: round artwork inside a thin ring (Carry on,
// suggestions, the bottom bar). Built on `DeckRing` / `DeckRingArtwork`
// (DeckRing.swift).

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

/// Round artwork for list rows (Up next suggestions): the track is always drawn faintly, the
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
