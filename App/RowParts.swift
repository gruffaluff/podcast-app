import SwiftUI

// Shared row parts, kept from the poster look (11 Nov 2026) for the Deck
// screens that still use them: colours, the artwork stamp, row text, the
// row card and the swipe action description.

enum Poster {
    /// Text on a printed colour area.
    static let paper = Color(hex: 0xF6F2E9)
    /// Full-row swipe colours: add (green) and played (red).
    static let swipeAdd = Color(hex: 0x45543A)
    static let swipePlayed = Color(hex: 0xB4472E)
    /// Library's Your shows heading (Paul, after build 139: ink matched
    /// the text and didn't stand out).
    static let rust = Color(hex: 0xB4472E)
    /// The strip down the left of a few settings rows.
    static let stripWidth: CGFloat = 8
    /// The band of the show's colour across the top of every row card.
    static let bandHeight: CGFloat = 4

    /// A show's colour: measured from its artwork (dark enough for paper
    /// text), or a steady placeholder colour until that's done.
    @MainActor
    static func colour(_ url: URL?, title: String) -> Color {
        ArtworkColors.shared.background(for: url) ?? Theme.placeholderColor(for: title)
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
            // A thin edge instead of a shadow: a shadow on every stamp in a
            // list cost frames while scrolling.
            .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
}

/// The text of a row: a small capitals label line, then the title, in
/// proper case.
struct PosterRowText: View {
    let label: String
    let title: String
    var titleSize: CGFloat = 19
    var lines = 2
    var dim = false
    var onColour = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // The label line is always there (blank if empty): one height.
            Text(label.isEmpty ? " " : label.uppercased())
                .font(Theme.mono(9.5))
                .tracking(0.8)
                .foregroundStyle(onColour ? Poster.paper.opacity(0.8) : Theme.muted)
                .lineLimit(1)
            Text(title)
                .font(Theme.title(titleSize))
                .foregroundStyle(onColour ? Poster.paper : (dim ? Theme.muted : Theme.ink))
                // Always the room of `lines` lines, so every row is the same
                // height whatever the title (Paul, 13 Nov 2026).
                .lineLimit(lines, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A row card (Native warm, Paul 11 Nov 2026): a plain white rounded
    /// row on the warm page, like an iOS inset list, no colour band. Every
    /// list row uses it; `strip` (the show's colour) is no longer drawn.
    func posterCard(_ strip: Color, fill: Color = Theme.surface) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(fill)
            }
    }

    /// A poster row in a list: the card plus the list settings around it.
    func posterRow(_ strip: Color, fill: Color = Theme.surface) -> some View {
        posterCard(strip, fill: fill).deckCardRow()
    }
}

struct PosterSwipeAction {
    let title: String
    let icon: String
    let colour: Color
    let action: () -> Void
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
