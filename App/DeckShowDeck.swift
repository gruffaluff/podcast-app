import SwiftUI
import UIKit
import PodcastCore

// Deck (Paul, 14 Nov 2026): the show deck on the Shows tab (prototype
// renderShows). One big card for the show on top, two more fanned behind
// it; swipe sideways (or ‹ ›) to go through the shows with new episodes.

/// The deck of show cards with the ‹ dots › under it.
struct DeckShowStack: View {
    let entries: [DeckShowEntry]
    @Binding var index: Int
    @State private var drag: CGFloat = 0

    static let cardHeight: CGFloat = 376

    var body: some View {
        let current: Int = min(max(0, index), entries.count - 1)
        VStack(spacing: 12) {
            ZStack(alignment: .top) {
                behind(current, k: 2)
                behind(current, k: 1)
                top(entries[current])
            }
            .frame(height: 384, alignment: .top)
            DeckShowDots(count: entries.count, current: current) { step($0) }
        }
    }

    private func top(_ entry: DeckShowEntry) -> some View {
        DeckShowCard(entry: entry)
            .id(entry.id)
            .offset(x: drag)
            .rotationEffect(.degrees(Double(drag / 40)))
            .gesture(DeckShowPan(isEnabled: entries.count > 1, changed: { drag = $0 }, ended: released))
            .padding(.leading, 28)
            .padding(.trailing, 40)
            .accessibilityAction(named: Text("Next show")) { step(1) }
            .accessibilityAction(named: Text("Previous show")) { step(-1) }
    }

    /// The next shows' cards fanned behind, each a little turned, showing
    /// just a faded block of its colour.
    @ViewBuilder private func behind(_ current: Int, k: Int) -> some View {
        if entries.count > k {
            let entry: DeckShowEntry = entries[(current + k) % entries.count]
            DeckShowBackCard(show: entry.show)
                .padding(.leading, CGFloat(28 + k * 12))
                .padding(.trailing, CGFloat(40 - k * 10))
                .offset(y: CGFloat(k * 4))
                .rotationEffect(.degrees(Double(k) * 2.2))
                .accessibilityHidden(true)
        }
    }

    private func released(_ velocity: CGFloat) {
        let flick: Bool = abs(drag) > 30 && abs(velocity) > 600
        guard abs(drag) > 80 || flick else {
            withAnimation(.spring(duration: 0.3)) { drag = 0 }
            return
        }
        let forward: Bool = drag < 0
        withAnimation(.snappy(duration: 0.3)) {
            step(forward ? 1 : -1)
            drag = 0
        }
    }

    private func step(_ by: Int) {
        let count: Int = entries.count
        guard count > 1 else { return }
        let from: Int = min(max(0, index), count - 1)
        withAnimation(.snappy(duration: 0.3)) {
            index = ((from + by) % count + count) % count
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// A card behind the top one: the colour block at half strength.
private struct DeckShowBackCard: View {
    let show: Podcast

    var body: some View {
        let colour: Color = DeckShowColour.of(show)
        VStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [colour, DeckShowColour.dark(colour)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.5)
                .frame(height: 150)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(height: 370)
        .deckPlainCard(radius: 28)
    }
}

/// The show on top of the deck: its artwork on a block of its colour (with
/// "n NEW"), name, where new episodes go, two episodes (new first) with +
/// or IN UP NEXT, and Open the show.
struct DeckShowCard: View {
    let entry: DeckShowEntry

    var body: some View {
        let colour: Color = DeckShowColour.of(entry.show)
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: entry.show) {
                DeckShowArtBlock(show: entry.show, colour: colour)
                    .overlay(alignment: .topLeading) { badge(colour) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(entry.show.title)")
            names
                .padding(.horizontal, 4)
                .padding(.top, 12)
            DeckShowCardEpisodes(entry: entry, colour: colour)
                .padding(.horizontal, 4)
                .padding(.top, 10)
            Spacer(minLength: 6)
            openButton
        }
        .padding(16)
        .frame(height: DeckShowStack.cardHeight)
        .deckPlainCard(radius: 28, lifted: true)
        .task(id: entry.show.artworkURL) { await ArtworkColors.shared.load(entry.show.artworkURL) }
    }

    @ViewBuilder private func badge(_ colour: Color) -> some View {
        if !entry.fresh.isEmpty {
            Text("\(entry.fresh.count) NEW")
                .font(Theme.outfit(11, .heavy))
                .tracking(0.4)
                .foregroundStyle(DeckShowColour.dark(colour))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
                .padding(12)
        }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.show.title)
                .font(Theme.outfit(23, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(DeckShowOrder.ruleLine(entry.show, rank: entry.rank))
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    private var openButton: some View {
        NavigationLink(value: entry.show) {
            Text("Open the show")
                .font(Theme.outfit(14, .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.background.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The two episode lines on the show card: new ones, else the newest
/// unplayed; a coloured dot when new, + to add to Up next or IN UP NEXT.
private struct DeckShowCardEpisodes: View {
    @Environment(LibraryStore.self) private var store
    let entry: DeckShowEntry
    let colour: Color

    var body: some View {
        let shown: [PodcastEpisode] = pick()
        VStack(alignment: .leading, spacing: 2) {
            if shown.isEmpty {
                Text("All played. New ones land here.")
                    .font(Theme.outfit(14, .medium))
                    .foregroundStyle(Theme.muted)
                    .frame(height: 30)
            }
            ForEach(shown, id: \.episodeID) { episode in
                line(episode)
            }
        }
    }

    private func pick() -> [PodcastEpisode] {
        if !entry.fresh.isEmpty { return Array(entry.fresh.prefix(2)) }
        let unplayed: [PodcastEpisode] = entry.show.episodes
            .filter { !$0.played }
            .sorted { $0.published > $1.published }
        return Array(unplayed.prefix(2))
    }

    private func line(_ episode: PodcastEpisode) -> some View {
        let isNew: Bool = entry.fresh.contains { $0.episodeID == episode.episodeID }
        return HStack(spacing: 10) {
            Circle()
                .fill(isNew ? colour : Theme.cardEdge)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(episode.title)
                .font(Theme.outfit(14, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing(episode)
        }
        .frame(height: 30)
    }

    @ViewBuilder private func trailing(_ episode: PodcastEpisode) -> some View {
        if store.isQueued(episode) {
            Text("IN UP NEXT")
                .font(Theme.outfit(11, .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.muted)
        } else {
            Button {
                withAnimation(LibraryStore.listChange) { store.playLast(episode) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.background))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 30)
            .accessibilityLabel("Add \(episode.title) to Up next")
        }
    }
}

/// The show's artwork on a block of its colour (prototype: the gradient
/// block).
struct DeckShowArtBlock: View {
    let show: Podcast
    let colour: Color
    var height: CGFloat = 150
    var art: CGFloat = 112

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [colour, DeckShowColour.dark(colour)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: height)
            .overlay {
                ArtworkView(url: show.artworkURL, title: show.title, size: art, radius: 16)
                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
            }
    }
}

/// ‹ dots › under the deck. With many shows the dots become "3 of 24".
private struct DeckShowDots: View {
    let count: Int
    let current: Int
    let step: (Int) -> Void

    var body: some View {
        HStack(spacing: 16) {
            arrow("chevron.left", label: "Previous show") { step(-1) }
            middle
            arrow("chevron.right", label: "Next show") { step(1) }
        }
        .frame(maxWidth: .infinity)
        .opacity(count > 1 ? 1 : 0)
    }

    @ViewBuilder private var middle: some View {
        if count <= 12 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index == current ? Theme.ink : Theme.cardEdge)
                        .frame(width: index == current ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Show \(current + 1) of \(count)")
        } else {
            Text("\(current + 1) of \(count)")
                .font(Theme.outfit(13, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// "All your shows": every show, two across down the page (Paul, 14 Nov
/// 2026: "stack your shows rather than scroll", then "full card images
/// with text on top"). Tap one for its page.
struct DeckAllShowsRow: View {
    let entries: [DeckShowEntry]
    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 12),
                                       GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckShowLabel(text: "All your shows")
                .padding(.horizontal, 22)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry.show) { DeckShowTile(entry: entry) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// A square tile that is the show's artwork, edge to edge, with the name
/// in white over a dark fade at the foot and "n new" in the corner.
private struct DeckShowTile: View {
    let entry: DeckShowEntry

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { art }
            .overlay(alignment: .bottom) { shade }
            .overlay(alignment: .bottomLeading) { name }
            .overlay(alignment: .topTrailing) { badge }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.cardEdge, lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.10), radius: 8, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var art: some View {
        CachedImage(url: entry.show.artworkURL) { Theme.placeholderColor(for: entry.show.title) }
    }

    private var shade: some View {
        LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.72)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 96)
            .allowsHitTesting(false)
    }

    private var name: some View {
        Text(entry.show.title)
            .font(Theme.outfit(15, .heavy))
            .foregroundStyle(Color.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
            .padding(12)
    }

    @ViewBuilder private var badge: some View {
        if !entry.fresh.isEmpty {
            Text("\(entry.fresh.count) new")
                .font(Theme.outfit(12, .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: 0x1C1B1A)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
                .padding(9)
        }
    }
}

/// A small Deck section label: bold capitals, spaced, muted.
struct DeckShowLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.outfit(12, .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A pan that begins only when the finger starts moving sideways, so up /
/// down drags go straight to the page's scrolling. (A copy of Poster.swift's
/// private `SidewaysPan`, kept here so the Deck files stand on their own.)
struct DeckShowPan: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    /// How far it has moved sideways.
    let changed: (CGFloat) -> Void
    /// Sideways speed when the finger lifts (points per second).
    let ended: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        // Measured against the window: the card moves with the finger.
        case .changed:
            changed(recognizer.translation(in: nil).x)
        case .ended:
            ended(recognizer.velocity(in: nil).x)
        case .cancelled, .failed:
            ended(0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity: CGPoint = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}
