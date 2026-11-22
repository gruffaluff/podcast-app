import SwiftUI

// The ring (Paul, 15 Nov 2026: "Dials and tabs!", from
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7). One shape means
// "this far through" everywhere: a thin ring round round artwork. Used by
// the player's dial, Up next's top card, the tabs, the mini player and
// Carry on.

/// A thin progress ring, starting at twelve o'clock and going clockwise.
struct DeckRing: View {
    /// 0...1, how far through.
    let progress: Double
    var lineWidth: CGFloat = 4
    var colour: Color = Theme.ink
    var track: Color = Theme.ink.opacity(0.12)

    var body: some View {
        let clamped: Double = min(1, max(0, progress))
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(colour, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }

    /// How far through an episode is, from its saved place (0 when not
    /// started or when its length isn't known).
    static func progress(of episode: PodcastEpisode) -> Double {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        if episode.played { return 1 }
        return min(1, max(0, episode.position / duration))
    }
}

/// Round artwork inside a ring, with a small gap between them.
struct DeckRingArtwork: View {
    let url: URL?
    let showTitle: String
    let size: CGFloat
    let progress: Double
    var lineWidth: CGFloat = 4
    var gap: CGFloat = 4
    var colour: Color = Theme.ink
    var track: Color = Theme.ink.opacity(0.12)
    /// The artwork's colour sweeps in with the ring (the island).
    var sweep: Bool = false

    var body: some View {
        let inner: CGFloat = max(0, size - 2 * (lineWidth + gap))
        ZStack {
            DeckRing(progress: progress, lineWidth: lineWidth, colour: colour, track: track)
            Color.clear
                .frame(width: inner, height: inner)
                .overlay {
                    if sweep {
                        DeckColourFill(url: url, showTitle: showTitle, progress: progress, round: true)
                    } else {
                        CachedImage(url: url) { Theme.placeholderColor(for: showTitle) }
                    }
                }
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension DeckRingArtwork {
    /// An episode's artwork in a ring showing its saved progress.
    init(episode: PodcastEpisode, size: CGFloat, lineWidth: CGFloat = 4, gap: CGFloat = 4,
         colour: Color = Theme.ink, track: Color = Theme.ink.opacity(0.12)) {
        self.init(url: episode.artwork, showTitle: episode.showTitle, size: size,
                  progress: DeckRing.progress(of: episode), lineWidth: lineWidth, gap: gap,
                  colour: colour, track: track)
    }
}


// MARK: - Colour fills in as you listen

/// Artwork in black and white with its colour filled in as far as you've
/// listened (Paul, 22 Nov 2026, I1 from
/// https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3): a wipe from the left
/// on square artwork, a sweep from twelve o'clock on round artwork.
struct DeckColourFill: View {
    let url: URL?
    let showTitle: String
    let progress: Double
    var round: Bool = false

    var body: some View {
        let p: Double = min(1, max(0, progress))
        ZStack {
            CachedImage(url: url) { Theme.placeholderColor(for: showTitle) }
                .grayscale(1)
                .brightness(-0.03)
            if p > 0 {
                CachedImage(url: url) { Theme.placeholderColor(for: showTitle) }
                    .mask {
                        if round { DeckSweepShape(progress: p) } else { DeckWipeShape(progress: p) }
                    }
            }
        }
    }
}

/// The left `progress` of the rectangle.
struct DeckWipeShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let p: Double = min(1, max(0, progress))
        return Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(p), height: rect.height))
    }
}

/// A pie from twelve o'clock round to `progress`.
struct DeckSweepShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p: Double = min(1, max(0, progress))
        guard p > 0 else { return path }
        if p >= 1 {
            path.addRect(rect)
            return path
        }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = max(rect.width, rect.height)
        path.move(to: centre)
        path.addArc(center: centre, radius: radius, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * p), clockwise: false)
        path.closeSubpath()
        return path
    }
}
