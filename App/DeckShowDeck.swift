import SwiftUI
import UIKit
import PodcastCore

// Deck (Paul, 14 Nov 2026): the show cards on the Shows tab (prototype
// renderShows). Paul, 15 Nov 2026: as a stacked deck the swipe "feels like
// it does nothing", so it's a row you swipe along: cards side by side, the
// next one peeking in from the right, following the finger and settling on
// each card; ‹ dots › under it.

/// The row of show cards with the ‹ dots › under it.
struct DeckShowStack: View {
    let entries: [DeckShowEntry]
    /// `DeckShowsCache.generation`: the same number means the same entries.
    let generation: Int
    /// Which show is on top of the deck. Kept here (it was the Shows page's
    /// own state), so settling on a card redraws only this row and its dots.
    @State private var index = 0
    @State private var shown: String?

    static let cardHeight: CGFloat = 376

    var body: some View {
        let current: Int = min(max(0, index), entries.count - 1)
        VStack(spacing: 12) {
            // Smoother scrolling (Paul, 16 Nov 2026): the cards are their
            // own view that only redraws when the entries change, not each
            // time the row passes a card while it's being swiped.
            DeckShowRow(entries: entries, generation: generation, shown: $shown)
                .equatable()
                .accessibilityAction(named: Text("Next show")) { step(1) }
                .accessibilityAction(named: Text("Previous show")) { step(-1) }
            DeckShowDots(count: entries.count, current: current) { step($0) }
        }
        .onAppear { shown = entries[current].id }
        .onChange(of: shown) { _, id in
            guard let id, let found = entries.firstIndex(where: { $0.id == id }), found != index else { return }
            index = found
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    /// The ‹ › keys: wrap round at the ends, as before.
    private func step(_ by: Int) {
        let count: Int = entries.count
        guard count > 1 else { return }
        let from: Int = min(max(0, index), count - 1)
        let to: Int = ((from + by) % count + count) % count
        withAnimation(.snappy(duration: 0.3)) {
            index = to
            shown = entries[to].id
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// The sideways row of show cards, settling on each card.
private struct DeckShowRow: View, Equatable {
    let entries: [DeckShowEntry]
    let generation: Int
    @Binding var shown: String?

    nonisolated static func == (lhs: DeckShowRow, rhs: DeckShowRow) -> Bool {
        lhs.generation == rhs.generation
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(entries) { entry in
                    DeckShowCard(entry: entry)
                        .containerRelativeFrame(.horizontal) { width, _ in max(240, width - 56) }
                        .id(entry.id)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 14)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $shown)
        .contentMargins(.horizontal, 22, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: DeckShowStack.cardHeight + 28)
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
                // Smoother scrolling (Paul, 15 Nov 2026): the shadow is cast
                // by a plain rounded shape the size of the artwork, behind
                // it, rather than worked out from the picture itself.
                ArtworkView(url: show.artworkURL, title: show.title, size: art, radius: 16)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colour)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
                    }
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
        // Dots only for a few shows, and dark enough to see; a count after
        // that (Paul, 14 Nov 2026: the faint dots were "a little unclear").
        if count <= 6 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index == current ? Theme.ink : Theme.faint.opacity(0.55))
                        .frame(width: index == current ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Show \(current + 1) of \(count)")
        } else {
            Text("\(current + 1) of \(count)")
                .font(Theme.outfit(15, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
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
struct DeckAllShowsRow: View, Equatable {
    let entries: [DeckShowEntry]
    /// `DeckShowsCache.generation`: the same number means the same entries.
    let generation: Int
    /// The "All your shows" label and sort key above the grid; off when the
    /// page's own header has them (tabs mode's Your shows).
    let labelled: Bool
    /// Paul, 15 Nov 2026: "add the sort button". Kept on this iPhone.
    @AppStorage(DeckShowsSort.key) private var sortRaw: String = DeckShowsSort.newFirst.rawValue
    /// The sorted list, kept until the entries or the order change.
    @State private var memo = DeckShowsSortMemo()
    private static let columns: [GridItem] = [GridItem(.flexible(), spacing: 12),
                                              GridItem(.flexible(), spacing: 12)]

    private var sort: DeckShowsSort { DeckShowsSort(rawValue: sortRaw) ?? .newFirst }

    /// Smoother scrolling (Paul, 16 Nov 2026): the Shows page redraws for
    /// small reasons; the grid only does when its entries changed (its sort
    /// setting still redraws it).
    nonisolated static func == (lhs: DeckAllShowsRow, rhs: DeckAllShowsRow) -> Bool {
        lhs.generation == rhs.generation && lhs.labelled == rhs.labelled
    }

    /// "Latest episode" goes through every episode of every show, so the
    /// order is worked out once per list and sort, not on every redraw.
    private func sortedEntries() -> [DeckShowEntry] {
        let key: String = String(generation) + "|" + sortRaw
        if memo.key != key {
            memo.entries = sort.sorted(entries)
            memo.key = key
        }
        return memo.entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if labelled {
                HStack(alignment: .firstTextBaseline) {
                    DeckShowLabel(text: "All your shows")
                    Spacer(minLength: 8)
                    DeckShowsSortMenu()
                }
                .padding(.leading, 22)
                .padding(.trailing, 16)
            }
            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(sortedEntries()) { entry in
                    NavigationLink(value: entry.show) { DeckShowTile(entry: entry) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// The ⇅ key for All your shows: the order it's in, tap for the choices.
struct DeckShowsSortMenu: View {
    @AppStorage(DeckShowsSort.key) private var sortRaw: String = DeckShowsSort.newFirst.rawValue

    private var sort: DeckShowsSort { DeckShowsSort(rawValue: sortRaw) ?? .newFirst }

    var body: some View {
        Menu {
            Picker("Sort", selection: $sortRaw) {
                ForEach(DeckShowsSort.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text(sort.title)
                    .font(Theme.outfit(12, .semibold))
            }
            .foregroundStyle(Theme.muted)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort your shows: " + sort.title)
    }
}

/// Holds All your shows in its chosen order between redraws (not observed).
@MainActor
final class DeckShowsSortMemo {
    var key: String = ""
    var entries: [DeckShowEntry] = []
}

/// The orders for All your shows.
enum DeckShowsSort: String, CaseIterable {
    case newFirst, name, latestEpisode, topRank

    static let key = "deckShowsSort"

    var title: String {
        switch self {
        case .newFirst: return "New first"
        case .name: return "Name A–Z"
        case .latestEpisode: return "Latest episode"
        case .topRank: return "Top ranking"
        }
    }

    /// The entries come in "new first" order (new, Top rank, A–Z).
    func sorted(_ entries: [DeckShowEntry]) -> [DeckShowEntry] {
        switch self {
        case .newFirst:
            return entries
        case .name:
            return entries.sorted { $0.show.title.localizedStandardCompare($1.show.title) == .orderedAscending }
        case .latestEpisode:
            let latest: [String: Date] = Dictionary(entries.map {
                ($0.id, $0.show.episodes.map(\.published).max() ?? .distantPast)
            }, uniquingKeysWith: { first, _ in first })
            return entries.sorted { (latest[$0.id] ?? .distantPast) > (latest[$1.id] ?? .distantPast) }
        case .topRank:
            return entries.sorted { a, b in
                let first: Int = a.rank ?? 999
                let second: Int = b.rank ?? 999
                if first != second { return first < second }
                return a.show.title.localizedStandardCompare(b.show.title) == .orderedAscending
            }
        }
    }
}

/// A square tile that is the show's artwork, edge to edge, with the name
/// in white over a dark fade at the foot and "n new" in white over a
/// shaded top corner, like the tab cards' order number.
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
            // Smoother scrolling (Paul, 16 Nov 2026): the artwork, fade,
            // name (with its soft shadow) and badge are drawn once into one
            // picture, which then just moves as the page scrolls, instead
            // of being put together (the name's shadow included) on every
            // frame for every tile on screen. Everything sits inside the
            // tile's rounded shape, so nothing is cut off.
            .drawingGroup()
            // Smoother scrolling (Paul, 15 Nov 2026): the shadow comes from a
            // plain rounded shape behind the tile, not from the artwork,
            // fade and words drawn together, which was slow for every tile.
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.10), radius: 8, y: 4)
            }
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
            DeckCornerShadeLabel(text: "\(entry.fresh.count) new", corner: .topTrailing)
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
