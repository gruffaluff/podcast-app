import SwiftUI
import SwiftData
import PodcastCore

// Deck (Paul, 14 Nov 2026): the Shows tab. Spec: renderShows in
// design/deck/poddeck-prototype.html. A deck of show cards (shows with new
// episodes first, then Top shows by rank, then A–Z), swipe sideways or use
// ‹ › to go through them; under it every show as small tiles. The New pill
// opens this week's new episodes; + goes to Find to add a show. Show pages
// are pushed on this tab's own NavigationStack (also from `revealShow`).

/// Switches Deck's page (0 Up next, 1 Shows, 2 Find). DeckRoot sets it.
private struct DeckSelectTabKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    var deckSelectTab: (Int) -> Void {
        get { self[DeckSelectTabKey.self] }
        set { self[DeckSelectTabKey.self] = newValue }
    }
}

/// One followed show with what the Shows tab shows about it, worked out
/// once per redraw.
struct DeckShowEntry: Identifiable {
    let show: Podcast
    /// New episodes (unplayed, out in the last week), newest first.
    let fresh: [PodcastEpisode]
    /// Place in the Top ranking (1 = favourite); nil when not a Top show.
    let rank: Int?
    var id: String { show.feedURL }
}

/// The order of the show deck (prototype `showOrder`): shows with new
/// episodes first, then Top shows by rank, then A–Z.
@MainActor
enum DeckShowOrder {
    static func isNew(_ episode: PodcastEpisode, cutoff: Date) -> Bool {
        !episode.played && episode.published > cutoff
    }

    static func entries(_ shows: [Podcast], top: [Podcast]) -> [DeckShowEntry] {
        let cutoff: Date = Date().addingTimeInterval(-LibraryView.newFor)
        var ranks: [String: Int] = [:]
        for (index, show) in top.enumerated() { ranks[show.feedURL] = index + 1 }
        let list: [DeckShowEntry] = shows.map { show in
            let fresh: [PodcastEpisode] = show.episodes
                .filter { isNew($0, cutoff: cutoff) }
                .sorted { $0.published > $1.published }
            return DeckShowEntry(show: show, fresh: fresh, rank: ranks[show.feedURL])
        }
        return list.sorted(by: before)
    }

    static func before(_ a: DeckShowEntry, _ b: DeckShowEntry) -> Bool {
        let aNew: Bool = !a.fresh.isEmpty
        let bNew: Bool = !b.fresh.isEmpty
        if aNew != bNew { return aNew }
        let aRank: Int = a.rank ?? 999
        let bRank: Int = b.rank ?? 999
        if aRank != bRank { return aRank < bRank }
        return a.show.title.localizedCaseInsensitiveCompare(b.show.title) == .orderedAscending
    }

    /// Where new episodes of this show go, in words.
    static func ruleLine(_ show: Podcast, rank: Int?) -> String {
        switch show.autoAdd {
        case .top:
            guard let rank else { return "Top of Up next" }
            return "Top of Up next · \(EpisodeStatusRows.ordinal(rank)) in your ranking"
        case .bottom:
            return "Dealt in at the bottom of Up next"
        case .off:
            return "Not dealt in: waits here"
        }
    }
}

/// A show's colour (its artwork's, measured once and remembered), with a
/// calm placeholder until it's known, and its darker shade for gradients.
@MainActor
enum DeckShowColour {
    static func of(_ show: Podcast) -> Color {
        ArtworkColors.shared.background(for: show.artworkURL) ?? Theme.placeholderColor(for: show.title)
    }

    static func dark(_ colour: Color) -> Color {
        colour.mix(with: .black, by: 0.35)
    }
}

struct DeckShowsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.deckSelectTab) private var selectTab
    @Query(sort: \Podcast.title) private var shows: [Podcast]
    @State private var path = NavigationPath()
    /// Which show is on top of the deck.
    @State private var index = 0
    @State private var showingNew = false

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Podcast.self) { show in
                    DeckShowPage(show: show)
                }
        }
        // From the player's show name or an episode page's "Show ›": RootView
        // switches to this tab; push the show (and clear anything open).
        .onChange(of: store.revealShow, initial: true) { _, show in reveal(show) }
        .onChange(of: store.revealInUpNext) { _, id in
            if id != nil { showingNew = false }
        }
    }

    private var root: some View {
        let entries: [DeckShowEntry] = DeckShowOrder.entries(shows, top: store.topShows)
        return ScrollView {
            content(entries)
        }
        .scrollIndicators(.hidden)
        .deckPage()
        .refreshable { await store.refreshAll() }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNew) { DeckShowsNewSheet() }
    }

    private func content(_ entries: [DeckShowEntry]) -> some View {
        let newCount: Int = entries.reduce(0) { $0 + $1.fresh.count }
        return VStack(alignment: .leading, spacing: 0) {
            DeckShowsHeader(count: entries.count, newCount: newCount,
                            openNew: { showingNew = true },
                            add: { selectTab(2) })
            if entries.isEmpty {
                DeckShowsEmpty { selectTab(2) }
                    .padding(.top, 24)
            } else {
                DeckShowStack(entries: entries, index: $index)
                    .padding(.top, 18)
                DeckAllShowsRow(entries: entries)
                    .padding(.top, 22)
            }
        }
        .padding(.bottom, 16)
    }

    private func reveal(_ show: Podcast?) {
        guard let show, Theme.isDeck else { return }
        showingNew = false
        var fresh = NavigationPath()
        fresh.append(show)
        path = fresh
    }
}

/// "Shows" · "n followed", the New · n pill (ink when there are new ones)
/// and + to add a show (goes to Find).
struct DeckShowsHeader: View {
    let count: Int
    let newCount: Int
    let openNew: () -> Void
    let add: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shows")
                    .font(Theme.outfit(34, .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(count) followed")
                    .font(Theme.outfit(13, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Button(action: openNew) {
                DeckShowPill(title: "New · \(newCount)", on: newCount > 0)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityHint("This week's new episodes")
            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .accessibilityLabel("Add a show")
        }
        .padding(.leading, 22)
        .padding(.trailing, 14)
        .padding(.top, 8)
    }
}

/// Nothing followed yet.
private struct DeckShowsEmpty: View {
    let find: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("No shows yet")
                .font(Theme.outfit(24, .heavy))
                .foregroundStyle(Theme.ink)
            Text("Follow a show and its new episodes are dealt into Up next by your rules.")
                .font(Theme.outfit(14, .medium))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(action: find) {
                DeckShowPill(title: "Find something", on: true)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .deckPlainCard(radius: 28, lifted: true)
        .padding(.horizontal, 16)
    }
}

/// A Deck pill: white with a fine edge, ink when on, or filled with a
/// show's colour.
struct DeckShowPill: View {
    let title: String
    var icon: String? = nil
    var on = false
    var fill: Color? = nil
    var wide = false
    var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(Theme.outfit(13, .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 13)
        .frame(height: height)
        .frame(maxWidth: wide ? .infinity : nil)
        .background(Capsule().fill(background))
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
        .contentShape(Capsule())
    }

    private var background: Color { fill ?? (on ? Theme.ink : Theme.surface) }
    private var foreground: Color { fill != nil ? Color.white : (on ? Theme.background : Theme.ink) }
    private var border: Color { fill ?? (on ? Theme.ink : Theme.cardEdge) }
}
