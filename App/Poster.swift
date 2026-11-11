import SwiftUI
import UIKit

// The poster look (Paul, 11 Nov 2026: "let's rebuild it all"; mock-ups
// https://claude.ai/artifact/KbVas33x1ccwvAFM9YoccR, his pick A + B with
// square stamps). The page stays sand; every row gets a strip of its show's
// colour, a big Big Shoulders title and the artwork as a small square
// "stamp" (A); the big colour areas (playing block, player, show and
// episode pages, mini player) are the artwork "printed" in one ink of the
// show's colour with a halftone dot screen (B).

enum Poster {
    /// Text on a printed colour area.
    static let paper = Color(hex: 0xF6F2E9)
    /// Full-row swipe colours: add (green) and played (red).
    static let swipeAdd = Color(hex: 0x45543A)
    static let swipePlayed = Color(hex: 0xB4472E)
    /// The strip down the left of every row.
    static let stripWidth: CGFloat = 8

    /// A show's colour: measured from its artwork (dark enough for paper
    /// text), or a steady placeholder colour until that's done.
    @MainActor
    static func colour(_ url: URL?, title: String) -> Color {
        ArtworkColors.shared.background(for: url) ?? Theme.placeholderColor(for: title)
    }
}

/// The halftone dot screen printed over colour areas.
struct Halftone: View {
    var spacing: CGFloat = 4
    var radius: CGFloat = 0.95
    var opacity: Double = 0.22

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(.black.opacity(opacity)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Artwork "screen-printed" in one ink of the show's colour (idea B): the
/// picture in greys multiplied onto the colour, with the dot screen on top.
/// Fills whatever space it's given.
struct PrintedArtwork: View {
    let url: URL?
    let colour: Color
    /// How strongly the picture shows through (0 = flat colour).
    var strength: Double = 0.6
    var dots = true

    var body: some View {
        colour
            .overlay {
                CachedImage(url: url) { Color.clear }
                    .grayscale(1)
                    .contrast(1.15)
                    .blendMode(.multiply)
                    .opacity(strength)
            }
            .overlay { if dots { Halftone() } }
            .compositingGroup()
            .clipped()
            .accessibilityHidden(true)
    }
}

/// The artwork as a small square "stamp" (idea A): square, a thin paper
/// edge and a soft shadow, like a label stuck on.
struct Stamp: View {
    let url: URL?
    let title: String
    var size: CGFloat = 40

    var body: some View {
        ArtworkView(url: url, title: title, size: size, radius: size * 0.16)
            .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Poster.paper.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }
}

/// The text of a poster row: a small DM Mono label line, then the title in
/// big Big Shoulders capitals.
struct PosterRowText: View {
    let label: String
    let title: String
    var titleSize: CGFloat = 19
    var lines = 2
    var dim = false
    var onColour = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(Theme.mono(9.5))
                    .tracking(0.8)
                    .foregroundStyle(onColour ? Poster.paper.opacity(0.8) : Theme.muted)
                    .lineLimit(1)
            }
            Text(title.uppercased())
                .font(Theme.big(titleSize))
                .foregroundStyle(onColour ? Poster.paper : (dim ? Theme.muted : Theme.ink))
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A poster row card: paper with a strip of the show's colour down the
    /// left, rounded, on a soft shadow (the app's card look).
    func posterCard(_ strip: Color, fill: Color = Theme.surface) -> some View {
        self
            .padding(.leading, Poster.stripWidth + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(fill)
                    .overlay(alignment: .leading) {
                        strip.frame(width: Poster.stripWidth)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .shadow(color: Theme.shadowSoft, radius: 0.5, y: 1)
                    .shadow(color: Theme.shadowWide, radius: 3, y: 1.5)
            }
    }

    /// A poster row in a list: the card plus the list settings around it.
    func posterRow(_ strip: Color, fill: Color = Theme.surface) -> some View {
        posterCard(strip, fill: fill).deckCardRow()
    }

    /// Full-row swipes (Paul, poster look): the action fills the whole row,
    /// its own height and corners. Swipe right for `leading`, left for
    /// `trailing`; let go past the line to do it.
    func posterSwipe(leading: PosterSwipeAction? = nil, trailing: PosterSwipeAction? = nil, enabled: Bool = true) -> some View {
        modifier(PosterSwipe(leading: leading, trailing: trailing, enabled: enabled))
    }
}

struct PosterSwipeAction {
    let title: String
    let icon: String
    let colour: Color
    let action: () -> Void
}

private struct PosterSwipe: ViewModifier {
    let leading: PosterSwipeAction?
    let trailing: PosterSwipeAction?
    let enabled: Bool
    @State private var offset: CGFloat = 0
    /// Decided on the first movement: sideways swipes move the row, upward
    /// or downward ones are left to the list's scrolling.
    @State private var sideways: Bool?
    @State private var armed = false

    private static let trigger: CGFloat = 96

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { actionBlock }
            .simultaneousGesture(drag, including: enabled ? .all : .subviews)
            .accessibilityActions {
                if let leading { Button(leading.title, action: leading.action) }
                if let trailing { Button(trailing.title, action: trailing.action) }
            }
    }

    @ViewBuilder private var actionBlock: some View {
        let action = offset > 0 ? leading : (offset < 0 ? trailing : nil)
        if let action {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(action.colour)
                .overlay(alignment: offset > 0 ? .leading : .trailing) {
                    HStack(spacing: 6) {
                        if offset < 0 { label(action) }
                        Image(systemName: action.icon).font(.system(size: 14, weight: .bold))
                        if offset > 0 { label(action) }
                    }
                    .foregroundStyle(Poster.paper)
                    .padding(.horizontal, 18)
                    .scaleEffect(armed ? 1.08 : 1)
                }
                .accessibilityHidden(true)
        }
    }

    private func label(_ action: PosterSwipeAction) -> some View {
        Text(action.title.uppercased()).font(Theme.mono(11, .bold)).tracking(1)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                if sideways == nil {
                    sideways = abs(value.translation.width) > abs(value.translation.height) * 1.6
                }
                guard sideways == true else { return }
                var x = value.translation.width
                if x > 0, leading == nil { x = 0 }
                if x < 0, trailing == nil { x = 0 }
                // Resists a little past the line.
                if abs(x) > Self.trigger { x = (x > 0 ? 1 : -1) * (Self.trigger + (abs(x) - Self.trigger) * 0.35) }
                offset = x
                let nowArmed = abs(x) >= Self.trigger
                if nowArmed != armed {
                    armed = nowArmed
                    if nowArmed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                }
            }
            .onEnded { _ in
                let fire = armed ? (offset > 0 ? leading : trailing) : nil
                sideways = nil
                armed = false
                withAnimation(.spring(duration: 0.3)) { offset = 0 }
                fire?.action()
            }
    }
}

private struct ShowPosterCard: ViewModifier {
    let url: URL?
    let title: String
    let fill: Color
    let inList: Bool

    func body(content: Content) -> some View {
        let colour = Poster.colour(url, title: title)
        Group {
            if inList {
                content.posterRow(colour, fill: fill)
            } else {
                content.posterCard(colour, fill: fill)
            }
        }
        .task(id: url) { await ArtworkColors.shared.load(url) }
    }
}

extension View {
    /// A poster card in the colour of the show whose artwork is `url`
    /// (measured once, then remembered).
    func showCard(_ url: URL?, title: String, fill: Color = Theme.surface) -> some View {
        modifier(ShowPosterCard(url: url, title: title, fill: fill, inList: false))
    }

    /// The same as a list row.
    func showRow(_ url: URL?, title: String, fill: Color = Theme.surface) -> some View {
        modifier(ShowPosterCard(url: url, title: title, fill: fill, inList: true))
    }
}

extension PodcastEpisode {
    /// The show's own artwork (its colour is the episode's strip colour).
    var showArtwork: URL? { podcast?.artworkURL ?? artwork }
    var showTitle: String { podcast?.title ?? "" }
}
