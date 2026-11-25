import SwiftUI
import UIKit
import PodcastCore

// Deck: Your shows' tiles, their sort, and small shared pieces (the
// section label and the sideways pan used by show page swipes).

/// "All your shows": every show, two across down the page (Paul, 14 Nov
/// 2026: "stack your shows rather than scroll", then "full card images
/// with text on top"). Tap one for its page.
struct DeckAllShowsRow: View, Equatable {
    let entries: [DeckShowEntry]
    /// `DeckShowsCache.generation`: the same number means the same entries.
    let generation: Int
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
        lhs.generation == rhs.generation
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

    /// Colour means something new (Paul, 22 Nov 2026, I3): shows you're
    /// caught up on go black and white and a little quieter.
    private var art: some View {
        let caughtUp: Bool = entry.fresh.isEmpty
        return CachedImage(url: entry.show.artworkURL) { Theme.placeholderColor(for: entry.show.title) }
            .grayscale(caughtUp ? 1 : 0)
            .opacity(caughtUp ? 0.82 : 1)
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
            // The same coral pill as NEW on the Up next tabs (Paul, 16 Nov
            // 2026: "do we make it red like the other").
            Text("\(entry.fresh.count) NEW")
                .font(Theme.outfit(10, .heavy))
                .tracking(0.6)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(DeckRings.coral))
                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)
                .fixedSize()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityLabel("\(entry.fresh.count) new")
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
