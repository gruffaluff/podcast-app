import SwiftUI
import PodcastCore

// Deck: how the top card of Up next looks (Paul, 14 Nov 2026: "build the
// Layout setting now"). Only the top card changes; the deck, its order and
// its swipes stay the same whichever is picked. Prototype: renderLayout.

enum DeckLayout: String, CaseIterable, Identifiable {
    case standard, big, calm, read

    /// Saved on this iPhone ("deckLayout").
    static let key = "deckLayout"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return "Standard"
        case .big: return "Big buttons"
        case .calm: return "Calm"
        case .read: return "Read along"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "Artwork, title, controls"
        case .big: return "One huge pause, big skips: walking, running, cleaning"
        case .calm: return "Muted colours, sleep timer up front"
        case .read: return "The words being said take the card"
        }
    }
}

/// Settings → Layout: four choices, each with a tiny picture of the card.
struct DeckLayoutView: View {
    @AppStorage(DeckLayout.key) private var layout: String = DeckLayout.standard.rawValue

    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                intro
                grid
                footer
            }
        }
        .scrollIndicators(.hidden)
        .deckPage()
        .navigationTitle("Layout")
        .navigationBarTitleDisplayMode(.large)
    }

    private var intro: some View {
        Text("How the top card of Up next looks. The deck and its order stay the same whichever you pick.")
            .font(Theme.outfit(14, .medium))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 16)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(DeckLayout.allCases) { choice in
                DeckLayoutChoice(choice: choice, isOn: layout == choice.rawValue) {
                    layout = choice.rawValue
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        Text("Pick one and go back to Up next to see it.")
            .font(Theme.outfit(12, .medium))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
    }
}

/// One choice: the picture, its name and a line about it. The chosen one
/// has a thick ink edge.
private struct DeckLayoutChoice: View {
    let choice: DeckLayout
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                DeckLayoutMini(choice: choice)
                Text(choice.name)
                    .font(Theme.outfit(15, .heavy))
                    .foregroundStyle(Theme.ink)
                Text(choice.detail)
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.background))
            .overlay(shape.strokeBorder(isOn ? Theme.ink : Theme.cardEdge, lineWidth: isOn ? 3 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(choice.name + ". " + choice.detail)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : [.isButton])
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
}

/// The tiny picture of a top card (prototype's "minis").
struct DeckLayoutMini: View {
    let choice: DeckLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch choice {
            case .standard: standard
            case .big: big
            case .calm: calm
            case .read: read
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 146)
        .background(shape.fill(Theme.surface))
        .overlay(shape.strokeBorder(Theme.cardEdge, lineWidth: 1))
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

    private static let blue = Color(hex: 0x4C8DFF)

    private func block(_ colour: Color, width: CGFloat?, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(colour)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func dot(_ colour: Color, size: CGFloat) -> some View {
        Circle().fill(colour).frame(width: size, height: size).frame(maxWidth: .infinity)
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 0) {
            block(Self.blue, width: nil, height: 66, radius: 9)
            block(Theme.ink, width: 78, height: 7, radius: 3).padding(.top, 8)
            block(Theme.cardLine, width: nil, height: 3, radius: 1).padding(.top, 9)
            dot(Theme.ink, size: 24).padding(.top, 9)
        }
        .padding(10)
    }

    private var big: some View {
        VStack(alignment: .leading, spacing: 0) {
            block(Theme.ink, width: 60, height: 7, radius: 3).padding(.top, 2)
            block(Theme.ink, width: nil, height: 72, radius: 12).padding(.top, 9)
            HStack {
                block(Theme.cardLine, width: 48, height: 28, radius: 9)
                Spacer(minLength: 0)
                block(Theme.cardLine, width: 48, height: 28, radius: 9)
            }
            .padding(.top, 8)
        }
        .padding(10)
    }

    private var calm: some View {
        VStack(alignment: .leading, spacing: 0) {
            block(Color(hex: 0xAEBBD2), width: nil, height: 62, radius: 9).padding(.horizontal, 20).padding(.top, 8)
            block(Color(hex: 0xA9A49B), width: nil, height: 6, radius: 3).padding(.horizontal, 18).padding(.top, 14)
            dot(Color(hex: 0x4B5259), size: 22).padding(.top, 12)
        }
        .padding(10)
    }

    private var read: some View {
        VStack(alignment: .leading, spacing: 0) {
            block(Self.blue, width: 24, height: 24, radius: 6)
            block(Theme.ink, width: nil, height: 10, radius: 3).padding(.trailing, 12).padding(.top, 12)
            block(Theme.ink, width: nil, height: 10, radius: 3).padding(.trailing, 26).padding(.top, 6)
            block(Theme.cardLine, width: nil, height: 3, radius: 1).padding(.top, 24)
            dot(Theme.ink, size: 24).padding(.top, 11)
        }
        .padding(10)
    }
}
