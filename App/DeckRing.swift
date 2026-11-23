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
        // Full colour always (Paul, 23 Nov 2026: "remove the artwork
        // colouring progress as I like seeing the artwork in its full
        // glory"). `progress` / `round` are kept so callers don't change;
        // the soft creep (`DeckSoftWipe` / `DeckSoftSweep`) is unused.
        CachedImage(url: url) { Theme.placeholderColor(for: showTitle) }
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


// MARK: - Soft colour creep

/// The colour's mask on square artwork: fully in up to a little before how
/// far you've got, then fading out over a wide, slightly tilted edge, so
/// there's no line (Paul, 22 Nov 2026, G3 on
/// https://claude.ai/artifact/NN8buzwaa8vmcJAntVSsZq). Nothing at 0, all
/// of it at 1.
struct DeckSoftWipe: View {
    var progress: Double
    /// How wide the fade is, as a share of the width.
    static let feather: Double = 0.38

    var body: some View {
        let p: Double = min(1, max(0, progress))
        let f: Double = Self.feather
        // The fade's leading edge runs from 0 to 1 + f, so it starts
        // invisible and ends fully in.
        let lead: Double = p * (1 + f)
        return LinearGradient(stops: [.init(color: .white, location: 0),
                                      .init(color: .white.opacity(0.75), location: 0.3),
                                      .init(color: .white.opacity(0.3), location: 0.68),
                                      .init(color: .white.opacity(0), location: 1)],
                              startPoint: UnitPoint(x: lead - f, y: 0.38),
                              endPoint: UnitPoint(x: lead, y: 0.62))
    }
}

/// The same on round artwork: from twelve o'clock round as far as you've
/// got, fading out over the last part of the turn.
struct DeckSoftSweep: View {
    var progress: Double
    static let feather: Double = 0.16

    var body: some View {
        let p: Double = min(1, max(0, progress))
        let f: Double = Self.feather
        let lead: Double = p * (1 + f)
        if lead - f >= 1 {
            return AnyView(Color.white)
        }
        let full: Double = max(0.001, lead - f)
        let end: Double = min(1, max(full + 0.001, lead))
        let fadeAtEnd: Double = lead > 1 ? (lead - 1) / f : 0
        return AnyView(AngularGradient(stops: [.init(color: .white.opacity(max(0.55, fadeAtEnd)), location: 0),
                                               .init(color: .white, location: min(full, 0.04)),
                                               .init(color: .white, location: full),
                                               .init(color: .white.opacity(fadeAtEnd * 0.9), location: end),
                                               .init(color: .white.opacity(fadeAtEnd * 0.9), location: 1)],
                                       center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)))
    }
}
