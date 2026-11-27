import SwiftUI
import SwiftData
import PodcastCore

// Deck: Your shows (Paul, 16 Nov 2026: "shows alone on the your shows
// tab"): the header and every followed show as tiles, two across (shows
// with new episodes first, then Top shows by rank, then A–Z, or the ⇅
// order); + goes to Find to add a show. Show pages are pushed on this
// tab's own NavigationStack (also from `revealShow`).

// `\.deckSelectTab` (switch Deck's page) is defined in DeckQueue.swift.

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

/// Your shows' order (prototype `showOrder`): shows with new episodes
/// first, then Top shows by rank, then A–Z.
@MainActor
enum DeckShowOrder {
    /// Smoother scrolling (Paul, 16 Nov 2026): the new episodes come from
    /// one fetch of the week's unplayed episodes, grouped by show, instead
    /// of walking every episode of every followed show (hundreds each) and
    /// sorting them. Same result: unplayed, out in the last week, newest
    /// first.
    static func entries(_ shows: [Podcast], top: [Podcast], context: ModelContext) -> [DeckShowEntry] {
        let cutoff: Date = Date().addingTimeInterval(-NewEpisodes.newFor)
        var ranks: [String: Int] = [:]
        for (index, show) in top.enumerated() { ranks[show.feedURL] = index + 1 }
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false && $0.published > cutoff },
            sortBy: [SortDescriptor(\PodcastEpisode.published, order: .reverse)]
        )
        let recent: [PodcastEpisode] = (try? context.fetch(descriptor)) ?? []
        var byShow: [String: [PodcastEpisode]] = [:]
        for episode in recent {
            guard let feed = episode.podcast?.feedURL else { continue }
            byShow[feed, default: []].append(episode)
        }
        let list: [DeckShowEntry] = shows.map { show in
            DeckShowEntry(show: show, fresh: byShow[show.feedURL] ?? [], rank: ranks[show.feedURL])
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

/// Smoother scrolling (Paul, 16 Nov 2026: Your shows "very jerky"): the
/// Shows tab's entries, worked out only when something they depend on
/// changes, not on every redraw. The page redraws for many small reasons
/// (Up next changing, iCloud and the player saving every few seconds), and
/// each redraw went through every episode of every show. Held in @State;
/// not observed, so filling it in during a redraw is fine.
@MainActor
final class DeckShowsCache {
    var key: String = ""
    /// `stillNew` when the entries were made.
    var stillNew: Int = 0
    var entries: [DeckShowEntry] = []
    /// Goes up each time `entries` is made again, so the rows below can
    /// tell "same list" cheaply.
    var generation: Int = 0
    /// The page has appeared once (the first appearance needs no refresh).
    var appeared = false
}

struct DeckShowsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.deckOpenSearch) private var openSearch
    @Environment(\.deckPageShown) private var pageShown
    @Query(sort: \Podcast.title) private var savedShows: [Podcast]
    /// Followed shows only (not ones only being tried, TriedShows.swift).
    private var shows: [Podcast] { savedShows.followedOnly }
    @State private var path = NavigationPath()
    @State private var cache = DeckShowsCache()
    /// Bumped to make the entries again (coming back to the page), for
    /// changes the key below can't see.
    @State private var refreshes = 0

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Podcast.self) { show in
                    DeckShowPage(show: show)
                }
                // Discover at the foot of the page (option C).
                .navigationDestination(for: DirectoryItem.self) { ShowPreviewView(item: $0) }
        }
        // From the player's show name or an episode page's "Show ›": RootView
        // switches to this tab; push the show (and clear anything open).
        .onChange(of: store.revealShow, initial: true) { _, show in reveal(show) }
        // "Your shows" tapped again in the bottom bar: back to the list.
        .onReceive(NotificationCenter.default.publisher(for: .deckPageToStart)) { note in
            guard note.object as? Int == 1 else { return }
            path = NavigationPath()
        }
        .onChange(of: pageShown) { _, shown in
            if shown { refreshes += 1 }
        }
    }

    private var root: some View {
        let entries: [DeckShowEntry] = currentEntries()
        let generation: Int = cache.generation
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Option C (27 Nov 2026): the switch and search at the top.
                    DeckPageTop(current: 1)
                    showsAlone(entries, generation: generation, jump: {
                        withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo(Self.discoverID, anchor: .top) }
                    })
                    // Browsing for new shows lives under your own (option C).
                    DeckDiscoverSection(paste: true)
                        .id(Self.discoverID)
                        .padding(.bottom, 16)
                }
            }
            .scrollIndicators(.hidden)
            // Pull down for the search; it checks for new episodes too.
            .deckPullToSearch()
        }
        .deckPage()
        .toolbar(.hidden, for: .navigationBar)
        // Back from a show page: played / unplayed there may have changed.
        .onAppear {
            if cache.appeared { refreshes += 1 } else { cache.appeared = true }
        }
    }

    /// The entries from the cache, made again only when the key changes.
    private func currentEntries() -> [DeckShowEntry] {
        let key: String = entriesKey()
        // Reading `played` on the cached new episodes also means the page
        // redraws when one of them is played anywhere, and is made again.
        // (Only when the shows are the same: an unfollowed show's episodes
        // are gone, so they aren't read.)
        let stale: Bool = key != cache.key || Self.stillNew(cache.entries) != cache.stillNew
        if stale {
            let made: [DeckShowEntry] = DeckShowOrder.entries(shows, top: store.topShows, context: store.context)
            cache.entries = made
            cache.generation += 1
            cache.key = key
            cache.stillNew = Self.stillNew(made)
        }
        return cache.entries
    }

    /// What the entries depend on, cheaply: each show and its place in the
    /// ranking (no episodes read), the last feed check, Undo coming and
    /// going (Undo can make a played episode new again), the hour (the week's cut-off moves on) and
    /// `refreshes`.
    private func entriesKey() -> String {
        var parts: [String] = []
        parts.reserveCapacity(shows.count + 4)
        for show in shows {
            parts.append(show.feedURL + "|" + show.autoAddRaw + "|" + String(show.topRank))
        }
        parts.append(store.lastChecked.map { String($0.timeIntervalSince1970) } ?? "-")
        parts.append(store.undoAction == nil ? "u0" : "u1")
        parts.append(String(Int(Date().timeIntervalSince1970 / 3600)))
        parts.append(String(refreshes))
        return parts.joined(separator: "\n")
    }

    /// How many of the entries' new episodes are still unplayed; -1 if
    /// any has been deleted since (e.g. iCloud merging duplicates), so the
    /// entries are made again without reading it.
    private static func stillNew(_ entries: [DeckShowEntry]) -> Int {
        var count: Int = 0
        for entry in entries {
            for episode in entry.fresh {
                if episode.isDeleted || episode.modelContext == nil { return -1 }
                if !episode.played { count += 1 }
            }
        }
        return count
    }

    static let discoverID = "deckDiscover"

    /// Just the header and every show as tiles, two across, in the ⇅ order.
    private func showsAlone(_ entries: [DeckShowEntry], generation: Int, jump: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckShowsAloneHeader(count: entries.count, add: openSearch, discover: jump)
            if entries.isEmpty {
                DeckShowsEmpty(find: jump)
                    .padding(.top, 24)
            } else {
                DeckAllShowsRow(entries: entries, generation: generation)
                    .equatable()
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 16)
    }

    private func reveal(_ show: Podcast?) {
        guard let show else { return }
        var fresh = NavigationPath()
        fresh.append(show)
        path = fresh
    }
}

/// Your shows' heading under the switch: "Your shows", "Discover ↓"
/// (jumps to browsing at the foot of the page), the ⇅ sort key and + to
/// add a show (opens the search, which also takes pasted links).
private struct DeckShowsAloneHeader: View {
    let count: Int
    let add: () -> Void
    let discover: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("Your shows")
                .font(Theme.outfit(22, .heavy))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button(action: discover) {
                Text("Discover ↓")
                    .font(Theme.outfit(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Discover new shows")
            if count > 0 {
                DeckShowsSortMenu()
            }
            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a show")
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .padding(.top, 10)
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
                DeckShowPill(title: "Discover shows", on: true)
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
