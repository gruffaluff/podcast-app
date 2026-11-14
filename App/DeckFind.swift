import SwiftUI
import SwiftData
import PodcastCore

// Deck (Paul, 14 Nov 2026): Find, search and Discover in one. Spec: the
// prototype's renderFind / chartRow / the "follow" sheet
// (design/deck/poddeck-prototype.html). Built on Haar's Find (HaarFind.swift:
// the same searches, ChartHistory for chart movement, recent searches),
// restyled as Deck: white cards on the warm page, Outfit.
//
// One box for shows you follow, episodes, anything said in your transcripts
// and new shows from Apple's directory. With nothing typed: recent
// searches, "New to you" (shows in the same category as one you follow) and
// the UK charts with big rank numbers and how each has moved.
//
// Following a show (Follow on a chart row or a New to you card) opens the
// Deck follow sheet: where new episodes go (Top / Bottom / Nowhere, Bottom
// to start, Paul's call), alerts, "Download the newest now" and, for Top,
// a link to Top show priority. Only the newest episode downloads and older
// ones are not marked played (CLAUDE.md). When the sheet closes the newest
// episode is dealt into Up next by the show's rule.

struct DeckFindView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Podcast.followedAt, order: .reverse) private var followed: [Podcast]

    @State private var path = NavigationPath()
    @State private var query = ""
    @FocusState private var fieldFocused: Bool
    @State private var directory: [DirectoryItem] = []
    @State private var searchingDirectory = false
    @State private var transcriptResults: [TranscriptIndex.Result] = []
    @State private var genre: PodcastGenre?
    @State private var chart: [DirectoryItem] = []
    @State private var moves: [String: ChartHistory.Move] = [:]
    @State private var chartFailed = false
    @State private var suggestions: DeckSuggestions?
    @AppStorage("recentSearches") private var recentText = ""

    private var recents: [String] { recentText.split(separator: "\n").map(String.init) }
    private var term: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack(path: $path) {
            page
                .navigationDestination(for: DirectoryItem.self) { ShowPreviewView(item: $0) }
                .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
        }
    }

    private var page: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                title
                searchField
                if term.count >= 2 {
                    DeckFindResults(term: term, followed: followed, transcriptResults: transcriptResults,
                                    directory: directory, searching: searchingDirectory)
                } else {
                    home
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .deckPage()
        .refreshable { await loadChart() }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: query) { await search() }
        .task(id: genre) { await loadChart() }
        .task { await loadSuggestions() }
    }

    // MARK: Top

    private var title: some View {
        Text("Find")
            .font(Theme.outfit(34, .heavy))
            .tracking(-1)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .accessibilityAddTraits(.isHeader)
            .onTapGesture { fieldFocused = false }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.muted)
            TextField("Shows, episodes, things people said", text: $query)
                .font(Theme.outfit(16, .medium))
                .focused($fieldFocused)
                .submitLabel(.search)
                .onSubmit { remember(query) }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
            if !query.isEmpty { clearButton }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var clearButton: some View {
        Button { query = "" } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear")
    }

    private func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        let others: [String] = recents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recentText = ([trimmed] + others).prefix(10).joined(separator: "\n")
    }

    // MARK: Nothing typed

    @ViewBuilder private var home: some View {
        if !recents.isEmpty {
            DeckRecentPills(recents: recents, pick: { query = $0 }, clear: { recentText = "" })
        }
        if let suggestions, !suggestions.items.isEmpty {
            DeckNewToYou(suggestions: suggestions)
        }
        DeckChartSection(genre: $genre, chart: chart, moves: moves, failed: chartFailed)
    }

    // MARK: Loading (as Haar's Find)

    private func loadChart() async {
        chartFailed = false
        do {
            let items: [DirectoryItem]
            if let genre {
                items = try await FeedClient.genreChart(genre)
            } else {
                items = try await FeedClient.topChart()
            }
            chart = items
            moves = ChartHistory.record(key: genre?.id ?? "uk", ids: items.map(\.id))
        } catch {
            if chart.isEmpty { chartFailed = true }
        }
    }

    /// Shows in the same category as a followed show, minus ones already
    /// followed (as Discover and Haar's Find did).
    private func loadSuggestions() async {
        guard suggestions == nil, !followed.isEmpty else { return }
        for show in followed.filter({ $0.genre == nil }).prefix(3) {
            if let match = try? await FeedClient.searchDirectory(show.title).first(where: { $0.feedURL?.absoluteString == show.feedURL || $0.collectionName == show.title }) {
                show.genre = match.primaryGenreName
            }
        }
        store.save()
        guard let anchor = followed.filter({ PodcastGenre.named($0.genre) != nil }).randomElement(),
              let category = PodcastGenre.named(anchor.genre),
              let items = try? await FeedClient.genreChart(category) else { return }
        let followedTitles = Set(followed.map { $0.title.lowercased() })
        let fresh: [DirectoryItem] = items.filter { !followedTitles.contains($0.title.lowercased()) }
        suggestions = DeckSuggestions(show: anchor.title, items: Array(fresh.prefix(10)))
    }

    private func search() async {
        let text = term
        guard text.count >= 2 else {
            directory = []
            transcriptResults = []
            return
        }
        // Wait for typing to pause.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        searchingDirectory = true
        defer { searchingDirectory = false }
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.transcriptFile != nil },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        let files: [TranscriptIndex.File] = ((try? store.context.fetch(descriptor)) ?? []).compactMap { episode in
            episode.transcriptFile.map { TranscriptIndex.File(episodeID: episode.episodeID, fileName: $0) }
        }
        let said = await TranscriptIndex.shared.search(text, in: files)
        guard !Task.isCancelled else { return }
        transcriptResults = said
        if let found = try? await FeedClient.searchDirectory(text), !Task.isCancelled {
            directory = found.map(DirectoryItem.init)
        }
    }
}

/// "New to you · because you follow X".
struct DeckSuggestions {
    let show: String
    let items: [DirectoryItem]
}

// MARK: - Small shared pieces

enum DeckFind {
    /// A small capitals label above a section (the prototype's .lbl).
    static func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.outfit(12, .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .lineLimit(2)
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    /// `text` with the first match of `term` marked in soft yellow.
    static func highlighted(_ text: String, term: String) -> AttributedString {
        guard let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return AttributedString(text)
        }
        return marked(text, range)
    }

    /// `text` with `range` marked (dark ink on the yellow in both looks).
    static func marked(_ text: String, _ range: Range<String.Index>) -> AttributedString {
        let before = AttributedString(String(text[..<range.lowerBound]))
        var hit = AttributedString(String(text[range]))
        let after = AttributedString(String(text[range.upperBound...]))
        hit.backgroundColor = Color(hex: 0xFFE7A3)
        hit.foregroundColor = Color(hex: 0x1C1B1A)
        return before + hit + after
    }

    /// Artwork as a rounded square.
    static func artwork(_ url: URL?, title: String, size: CGFloat, radius: CGFloat) -> some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay { CachedImage(url: url) { Theme.placeholderColor(for: title) } }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Results while typing

/// Your shows, Episodes, Said in your episodes and New shows for what's typed.
private struct DeckFindResults: View {
    @Environment(LibraryStore.self) private var store
    let term: String
    let followed: [Podcast]
    let transcriptResults: [TranscriptIndex.Result]
    let directory: [DirectoryItem]
    let searching: Bool

    var body: some View {
        let shows: [Podcast] = followed.filter { contains($0.title, term) || contains($0.author, term) }
        let episodes: [PodcastEpisode] = matchingEpisodes(term)
        VStack(alignment: .leading, spacing: 0) {
            if !shows.isEmpty { showsSection(Array(shows.prefix(6))) }
            if !episodes.isEmpty { episodesSection(Array(episodes.prefix(8))) }
            if !transcriptResults.isEmpty { DeckSaidSection(results: transcriptResults, term: term) }
            directorySection
            if shows.isEmpty && episodes.isEmpty && transcriptResults.isEmpty && directory.isEmpty && !searching {
                nothingFound
            }
        }
    }

    private func showsSection(_ shows: [Podcast]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckFind.label("Your shows")
            VStack(spacing: 8) {
                ForEach(shows, id: \.feedURL) { show in
                    NavigationLink(value: show) { showRow(show) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func showRow(_ show: Podcast) -> some View {
        HStack(spacing: 12) {
            DeckFind.artwork(show.artworkURL, title: show.title, size: 44, radius: 11)
            Text(DeckFind.highlighted(show.title, term: term))
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(10)
        .deckPlainCard(radius: 18)
        .contentShape(Rectangle())
    }

    private func episodesSection(_ episodes: [PodcastEpisode]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckFind.label("Episodes")
            VStack(spacing: 8) {
                ForEach(episodes, id: \.episodeID) { episode in
                    DeckEpisodeResultRow(episode: episode, term: term)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var directorySection: some View {
        if !directory.isEmpty || searching {
            DeckFind.label(searching && directory.isEmpty ? "New shows · searching…" : "New shows")
            VStack(spacing: 8) {
                ForEach(directory) { item in
                    DeckChartRow(item: item, rank: nil, move: nil)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var nothingFound: some View {
        Text("Nothing for “\(term)”. Try a show name, a topic or a phrase.")
            .font(Theme.outfit(14, .medium))
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 40)
    }

    private func matchingEpisodes(_ text: String) -> [PodcastEpisode] {
        guard text.count >= 2 else { return [] }
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        descriptor.fetchLimit = 30
        return (try? store.context.fetch(descriptor)) ?? []
    }

    private func contains(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

/// An episode found by name: tap for its episode page, hold for the menu.
private struct DeckEpisodeResultRow: View {
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    let term: String

    var body: some View {
        Button { store.notesEpisode = episode } label: {
            HStack(spacing: 12) {
                DeckFind.artwork(episode.artwork, title: episode.showTitle, size: 44, radius: 11)
                VStack(alignment: .leading, spacing: 1) {
                    Text(episode.showTitle)
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    Text(DeckFind.highlighted(episode.title, term: term))
                        .font(Theme.outfit(15, .bold))
                        .foregroundStyle(Theme.ink.opacity(episode.played ? 0.5 : 1))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .deckPlainCard(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { EpisodeMenuItems(episode: episode) }
    }
}

/// Lines from your transcripts with the words marked. Tap one to play the
/// episode from that line.
private struct DeckSaidSection: View {
    @Environment(LibraryStore.self) private var store
    let results: [TranscriptIndex.Result]
    let term: String

    var body: some View {
        let found: [String: PodcastEpisode] = store.episodes(results.map(\.episodeID))
        VStack(alignment: .leading, spacing: 0) {
            DeckFind.label("Said in your episodes")
            VStack(spacing: 8) {
                ForEach(results.prefix(6), id: \.episodeID) { result in
                    if let episode = found[result.episodeID] {
                        ForEach(Array(result.matches.prefix(2).enumerated()), id: \.offset) { _, match in
                            DeckSaidRow(episode: episode, match: match)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct DeckSaidRow: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let match: TranscriptSearch.Match

    var body: some View {
        Button(action: play) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ArtworkColors.shared.background(for: episode.artwork) ?? Theme.ink)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(DeckFind.marked(match.snippet, match.highlight))
                        .font(Theme.outfit(15, .medium))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(episode.showTitle + " · " + episode.title + " · " + TimeFormat.clock(match.time))
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .deckPlainCard(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Plays from \(TimeFormat.clock(match.time))")
    }

    private func play() {
        player.play(episode)
        player.seek(to: match.time)
    }
}

// MARK: - Nothing typed

private struct DeckRecentPills: View {
    let recents: [String]
    let pick: (String) -> Void
    let clear: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(recents, id: \.self) { recent in
                    Button { pick(recent) } label: { pill(recent) }
                        .buttonStyle(.plain)
                }
                Button("Clear", action: clear)
                    .font(Theme.outfit(13, .semibold))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 12)
    }

    private func pill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(Theme.outfit(13, .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: 1))
    }
}

private struct DeckNewToYou: View {
    let suggestions: DeckSuggestions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckFind.label("New to you · because you follow \(suggestions.show)")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(suggestions.items) { DeckSuggestionCard(item: $0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

/// A "New to you" card: a big artwork block, name, category, Follow.
private struct DeckSuggestionCard: View {
    let item: DirectoryItem
    @State private var follower = DeckFollower()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: item) { top }
                .buttonStyle(.plain)
            DeckFollowControl(item: item, follower: follower, pill: true)
                .padding(.top, 8)
        }
        .padding(10)
        .frame(width: 200)
        .deckPlainCard(radius: 22)
        .sheet(item: $follower.sheetShow) { DeckFollowSheet(show: $0) }
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .overlay { CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.title) } }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.bottom, 6)
            Text(item.title)
                .font(Theme.outfit(15, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text([item.genre, item.artist].compactMap { $0 }.joined(separator: " · "))
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

/// "Top in the UK" (or a category): the category words, then the chart.
private struct DeckChartSection: View {
    @Binding var genre: PodcastGenre?
    let chart: [DirectoryItem]
    let moves: [String: ChartHistory.Move]
    let failed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            DeckCategoryWords(genre: $genre)
            if chart.isEmpty {
                placeholder
            } else {
                rows
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(genre.map { "Top in \($0.name)" } ?? "Top in the UK")
                .font(Theme.outfit(22, .heavy))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("updated today")
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(Array(chart.enumerated()), id: \.element.id) { index, item in
                DeckChartRow(item: item, rank: index + 1, move: moves[item.id])
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private var placeholder: some View {
        if failed {
            Text("Couldn't load the chart. Pull down to try again.")
                .font(Theme.outfit(14, .medium))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(20)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(20)
        }
    }
}

/// The categories as plain words; the chosen one heavy ink, underlined.
private struct DeckCategoryWords: View {
    @Binding var genre: PodcastGenre?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    word("All", selected: genre == nil) { genre = nil }
                        .id("all")
                    ForEach(PodcastGenre.all) { item in
                        word(item.name, selected: genre == item) { genre = item }
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
            .onChange(of: genre) { _, value in
                withAnimation { proxy.scrollTo(value?.id ?? "all", anchor: .center) }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func word(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(Theme.outfit(15, selected ? .heavy : .medium))
                    .foregroundStyle(selected ? Theme.ink : Theme.faint)
                    .fixedSize()
                Rectangle()
                    .fill(selected ? Theme.ink : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Chart row

/// A chart (or directory) row as its own white card: the rank big with how
/// it moved under it (▲ n / ▼ n / NEW / –), the artwork, name and
/// category (tap for the show's page), and Follow as a word.
struct DeckChartRow: View {
    let item: DirectoryItem
    let rank: Int?
    let move: ChartHistory.Move?
    @State private var follower = DeckFollower()

    var body: some View {
        HStack(spacing: 12) {
            if let rank { rankColumn(rank) }
            NavigationLink(value: item) { info }
                .buttonStyle(.plain)
            DeckFollowControl(item: item, follower: follower, pill: false)
        }
        .padding(.leading, rank == nil ? 10 : 8)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .deckPlainCard(radius: 18)
        .accessibilityElement(children: .contain)
        .sheet(item: $follower.sheetShow) { DeckFollowSheet(show: $0) }
    }

    private func rankColumn(_ rank: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(rank)")
                .font(Theme.outfit(rank > 99 ? 19 : 24, .heavy))
                .tracking(-1)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            DeckChartMove(move: move)
        }
        .frame(width: 34)
    }

    private var info: some View {
        HStack(spacing: 12) {
            DeckFind.artwork(item.artworkURL, title: item.title, size: 46, radius: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text([item.genre, item.artist].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// How a show moved in the chart since an earlier day (ChartHistory).
private struct DeckChartMove: View {
    let move: ChartHistory.Move?

    private static let up = Color(hex: 0x1F8A4A)
    private static let down = Color(hex: 0xC7392A)

    var body: some View {
        switch move {
        case .some(.up(let places)):
            mark("▲ \(places)", Self.up).accessibilityLabel("Up \(places)")
        case .some(.down(let places)):
            mark("▼ \(places)", Self.down).accessibilityLabel("Down \(places)")
        case .some(.new):
            mark("NEW", Self.up)
        case .some(.same):
            mark("–", Theme.faint).accessibilityLabel("No change")
        case .none:
            EmptyView()
        }
    }

    private func mark(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(Theme.outfit(10, .heavy))
            .foregroundStyle(colour)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Following

/// Follow state for one row or card. Following saves the show straight
/// away (so the sheet can set it up and Top show priority can rank it) but
/// downloads and deals in nothing until the sheet closes.
@MainActor
@Observable
final class DeckFollower {
    var busy = false
    var failed = false
    /// Opens the Deck follow sheet for a show just followed.
    var sheetShow: Podcast?
    /// The show this follower followed (charts may have no feed link to
    /// look it up by afterwards).
    var followed: Podcast?

    func follow(_ item: DirectoryItem, store: LibraryStore) async {
        guard !busy else { return }
        busy = true
        failed = false
        defer { busy = false }
        var feedURL = item.feedURL
        if feedURL == nil {
            feedURL = (try? await FeedClient.lookup(appleID: item.appleID))?.feedURL
        }
        guard let feedURL else { failed = true; return }
        let isNew: Bool = store.podcast(feedURL: feedURL.absoluteString) == nil
        guard let show = try? await store.follow(feedURL: feedURL, downloadLatest: false) else {
            failed = true
            return
        }
        if show.genre == nil { show.genre = item.genre }
        store.save()
        followed = show
        if isNew { sheetShow = show }
    }
}

/// Follow (or Following, which opens the show) as a word on chart rows and
/// as a pill on New to you cards.
private struct DeckFollowControl: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    let follower: DeckFollower
    let pill: Bool

    private var show: Podcast? {
        if let followed = follower.followed { return followed }
        guard let url = item.feedURL else { return nil }
        return store.podcast(feedURL: url.absoluteString)
    }

    var body: some View {
        if follower.busy {
            ProgressView()
                .frame(minWidth: 64, minHeight: pill ? 34 : 40)
                .frame(maxWidth: pill ? .infinity : nil)
        } else if let show {
            NavigationLink(value: show) { label("Following", symbol: "checkmark", on: false) }
                .buttonStyle(.plain)
                .accessibilityLabel("Following \(item.title). Opens the show")
        } else {
            Button {
                Task { await follower.follow(item, store: store) }
            } label: {
                label(follower.failed ? "Retry" : "Follow", symbol: "plus", on: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(follower.failed ? "Retry follow" : "Follow \(item.title)")
        }
    }

    @ViewBuilder private func label(_ text: String, symbol: String, on: Bool) -> some View {
        if pill {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                Text(text).font(Theme.outfit(13, .semibold))
            }
            .foregroundStyle(on ? Theme.background : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Capsule().fill(on ? Theme.ink : Theme.surface))
            .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.cardEdge, lineWidth: 1))
            .contentShape(Capsule())
        } else {
            Text(text)
                .font(Theme.outfit(14, .heavy))
                .foregroundStyle(on ? Theme.ink : Theme.faint)
                .frame(minHeight: 40)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
    }
}

/// Opens right after following a show from Find: where its new episodes
/// go, alerts, downloading the newest, and (for Top) Top show priority.
/// Closing it (Done, or swiping it away) deals the newest episode into Up
/// next by the show's rule and downloads it if asked. Older episodes stay
/// unplayed (Paul's call).
struct DeckFollowSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    @State private var rule: AutoAddMode = .bottom
    @State private var alerts = false
    @State private var downloadNewest = true
    @State private var finished = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    ruleChoice
                    options
                    doneButton
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .deckPage()
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            rule = show.autoAdd
            alerts = show.notify
        }
        .onDisappear(perform: finish)
    }

    private var heading: some View {
        HStack(spacing: 12) {
            DeckFind.artwork(show.artworkURL, title: show.title, size: 52, radius: 13)
            VStack(alignment: .leading, spacing: 1) {
                Text("Following")
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                Text(show.title)
                    .font(Theme.outfit(20, .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
        }
        .padding(.top, 8)
    }

    private var ruleChoice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEW EPISODES GO TO")
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                rulePill("Top", .top)
                rulePill("Bottom", .bottom)
                rulePill("Nowhere", .off)
            }
        }
        .padding(.top, 18)
    }

    private func rulePill(_ title: String, _ mode: AutoAddMode) -> some View {
        let on: Bool = rule == mode
        return Button { choose(mode) } label: {
            Text(title)
                .font(Theme.outfit(14, .semibold))
                .foregroundStyle(on ? Theme.background : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(on ? Theme.ink : Theme.surface))
                .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.cardEdge, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var options: some View {
        DeckSetCard {
            DeckSetToggle(title: "Alert me for new episodes", isOn: alertsBinding)
            DeckSetLine()
            DeckSetToggle(title: "Download the newest now", isOn: $downloadNewest)
            if rule == .top {
                DeckSetLine()
                NavigationLink { DeckPriorityView() } label: {
                    DeckSetRowLabel(icon: "list.number", title: "Top show priority")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 14)
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .font(Theme.outfit(16, .bold))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(Theme.ink))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    private var alertsBinding: Binding<Bool> {
        Binding(get: { alerts }, set: { on in
            alerts = on
            show.notify = on
            store.save()
            if on { Task { _ = await NewEpisodeAlerts.requestPermission() } }
        })
    }

    /// Set straight away, so Top show priority already has the show.
    private func choose(_ mode: AutoAddMode) {
        rule = mode
        store.setAutoAdd(mode, for: show)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        store.dealInNewest(of: show, download: downloadNewest, downloads: downloads)
    }
}

extension LibraryStore {
    /// After following from Deck's Find: the newest episode goes into Up
    /// next by the show's rule (Top / Bottom; nothing for Nowhere), and
    /// downloads if asked (following the Wi-Fi only setting). Older
    /// episodes are left unplayed. Same steps as `follow(feedURL:)` does
    /// itself, but after the rule has been chosen.
    func dealInNewest(of show: Podcast, download: Bool, downloads: DownloadManager) {
        guard let latest = latestEpisode(of: show) else { return }
        if download { downloads.download(latest, automatic: true) }
        guard !latest.played else { return }
        commit(QueueEngine.addNewEpisodes([latest.queueEpisode], to: queue, settings: queueSettings))
        save()
    }
}
