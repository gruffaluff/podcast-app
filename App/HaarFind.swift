import SwiftUI
import SwiftData
import PodcastCore

/// Haar, phase 3: Find, search and Discover in one (Paul, 13 Nov 2026).
/// One box for shows you follow, episodes, anything said in your
/// transcripts and new shows from Apple's directory. With nothing typed:
/// recent searches, New to you (shows like ones you follow) and the UK
/// charts, with big serif rank numbers and how each show has moved since
/// an earlier day's chart (kept on this iPhone; Apple's chart doesn't say),
/// and the categories as plain words along the top of the chart.
struct HaarFindView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Query(sort: \Podcast.followedAt, order: .reverse) private var followed: [Podcast]
    /// Back to the player (the handle at the top, swiped up).
    let close: () -> Void

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
    @State private var suggestions: (show: String, items: [DirectoryItem])?
    @AppStorage("recentSearches") private var recentText = ""

    private var recents: [String] { recentText.split(separator: "\n").map(String.init) }
    private var term: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    searchField
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                    if term.count >= 2 {
                        results
                    } else {
                        if !recents.isEmpty { recentRow }
                        if let suggestions, !suggestions.items.isEmpty {
                            newToYou(suggestions.show, suggestions.items)
                        }
                        charts
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            // The same misty fog page as Library (Paul, 13 Nov 2026: Find
            // was "so white it stands out"; it only had the pale layer).
            .haarPage()
            .refreshable { await loadChart() }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: query) { await search() }
            .task(id: genre) { await loadChart() }
            .task { await loadSuggestions() }
            .navigationDestination(for: DirectoryItem.self) { ShowPreviewView(item: $0) }
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
        }
    }

    // MARK: Top

    /// A handle (swipe it up, or tap it, to go back to the player) and the
    /// serif title.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Capsule()
                .fill(Theme.ink.opacity(0.22))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .accessibilityHidden(true)
            Text("Find")
                .font(Theme.big(36))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
            if value.translation.height < -40 { close() }
        })
        .onTapGesture { fieldFocused = false }
        .accessibilityAction(named: "Back to the player") { close() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
            TextField("Shows, people, anything said", text: $query)
                .focused($fieldFocused)
                .submitLabel(.search)
                .onSubmit { remember(query) }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .frostedCard(radius: 23)
    }

    private func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        recentText = ([trimmed] + recents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }).prefix(10).joined(separator: "\n")
    }

    private func sectionTitle(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.big(23))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(Theme.text(12, .medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Nothing typed

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent")
                    .font(Theme.text(12, .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button("Clear") { recentText = "" }
                    .font(Theme.text(12, .semibold))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 18) {
                    ForEach(recents, id: \.self) { recent in
                        Button(recent) { query = recent }
                            .font(Theme.text(15, .medium))
                            .foregroundStyle(Theme.ink)
                            .buttonStyle(.plain)
                            .frame(minHeight: 34)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func newToYou(_ showTitle: String, _ items: [DirectoryItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("New to you", detail: "Like \(showTitle)")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { HaarSuggestion(item: $0) }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var charts: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(genre.map { "Top in \($0.name)" } ?? "Top in the UK", detail: "Chart")
            categoryTabs
            if chart.isEmpty {
                Group {
                    if chartFailed {
                        Text("Couldn't load the chart. Pull down to try again.")
                            .font(Theme.text(14))
                            .foregroundStyle(Theme.muted)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(chart.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { hairline }
                        HaarChartRow(item: item, rank: index + 1, move: moves[item.id])
                    }
                }
                .padding(.vertical, 4)
                .frostedCard()
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.ink.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 66)
    }

    /// The categories as plain words; the chosen one in ink, underlined.
    private var categoryTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    tab("All", selected: genre == nil) { genre = nil }
                        .id("all")
                    ForEach(PodcastGenre.all) { item in
                        tab(item.name, selected: genre == item) { genre = item }
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .onChange(of: genre) { _, value in
                withAnimation { proxy.scrollTo(value?.id ?? "all", anchor: .center) }
            }
        }
    }

    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(Theme.text(14, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.ink : Theme.muted)
                    .fixedSize()
                Capsule()
                    .fill(selected ? Theme.ink : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

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
    /// followed (as Discover did).
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
        let fresh = items.filter { !followedTitles.contains($0.title.lowercased()) }
        suggestions = (anchor.title, Array(fresh.prefix(10)))
    }

    // MARK: Results

    @ViewBuilder private var results: some View {
        let shows: [Podcast] = followed.filter { contains($0.title, term) || contains($0.author, term) }
        let episodes: [PodcastEpisode] = matchingEpisodes(term)
        if !shows.isEmpty {
            sectionTitle("Your shows")
            resultCard {
                ForEach(Array(shows.prefix(6).enumerated()), id: \.element.feedURL) { index, show in
                    if index > 0 { hairline }
                    Button { store.showSheet = show } label: {
                        resultRow(artwork: show.artworkURL, artTitle: show.title, title: show.title, detail: show.author)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if !episodes.isEmpty {
            sectionTitle("Episodes", detail: "\(episodes.count) found")
            resultCard {
                ForEach(Array(episodes.prefix(8).enumerated()), id: \.element.episodeID) { index, episode in
                    if index > 0 { hairline }
                    Button { player.play(episode) } label: {
                        resultRow(artwork: episode.artwork, artTitle: episode.showTitle, title: episode.title,
                                  detail: episode.showTitle, dim: episode.played)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { EpisodeMenuItems(episode: episode) }
                }
            }
        }
        if !transcriptResults.isEmpty {
            let found = store.episodes(transcriptResults.map(\.episodeID))
            sectionTitle("Said in your episodes")
            VStack(spacing: 10) {
                ForEach(transcriptResults.prefix(6), id: \.episodeID) { result in
                    if let episode = found[result.episodeID] {
                        ForEach(Array(result.matches.prefix(2).enumerated()), id: \.offset) { _, match in
                            TranscriptResultRow(episode: episode, match: match)
                                .padding(14)
                                .frostedCard()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        sectionTitle("New shows", detail: searchingDirectory ? "Searching…" : nil)
        if directory.isEmpty {
            Text(searchingDirectory ? " " : "No shows found in Apple's directory.")
                .font(Theme.text(14))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
        } else {
            resultCard {
                ForEach(Array(directory.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { hairline }
                    HaarChartRow(item: item, rank: nil, move: nil)
                }
            }
        }
    }

    private func resultCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 4)
            .frostedCard()
            .padding(.horizontal, 14)
    }

    private func resultRow(artwork: URL?, artTitle: String, title: String, detail: String, dim: Bool = false) -> some View {
        HStack(spacing: 12) {
            ArtworkView(url: artwork, title: artTitle, size: 42, radius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.text(15, .semibold))
                    .foregroundStyle(Theme.ink.opacity(dim ? 0.5 : 1))
                    .lineLimit(2)
                Text(detail)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
        let files = ((try? store.context.fetch(descriptor)) ?? []).compactMap { episode in
            episode.transcriptFile.map { TranscriptIndex.File(episodeID: episode.episodeID, fileName: $0) }
        }
        let said = await TranscriptIndex.shared.search(text, in: files)
        guard !Task.isCancelled else { return }
        transcriptResults = said
        if let found = try? await FeedClient.searchDirectory(text), !Task.isCancelled {
            directory = found.map(DirectoryItem.init)
        }
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

/// A chart (or directory) row: the rank in big serif figures with how it
/// moved under it, the artwork, name and category, and Follow.
struct HaarChartRow: View {
    let item: DirectoryItem
    let rank: Int?
    let move: ChartHistory.Move?
    @State private var follower = Follower()

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                if let rank {
                    VStack(spacing: 0) {
                        Text("\(rank)")
                            .font(Theme.serif(rank > 99 ? 20 : 28))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        moveLabel
                    }
                    .frame(width: 40)
                }
                ArtworkView(url: item.artworkURL, title: item.title, size: 46, radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Theme.text(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text([item.genre, item.artist].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .background(NavigationLink(value: item) { EmptyView() }.opacity(0))
            HaarFollowButton(item: item, follower: follower)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }

    @ViewBuilder private var moveLabel: some View {
        switch move {
        case .some(.up(let places)):
            Text("▲ \(places)").font(Theme.text(9, .semibold)).foregroundStyle(Theme.ink.opacity(0.7))
                .accessibilityLabel("Up \(places)")
        case .some(.down(let places)):
            Text("▼ \(places)").font(Theme.text(9, .semibold)).foregroundStyle(Theme.muted.opacity(0.8))
                .accessibilityLabel("Down \(places)")
        case .some(.new):
            Text("NEW").font(Theme.text(9, .bold)).tracking(0.5).foregroundStyle(Theme.accentText)
        case .some(.same):
            Text("–").font(Theme.text(9, .semibold)).foregroundStyle(Theme.muted.opacity(0.6))
                .accessibilityLabel("No change")
        case .none:
            EmptyView()
        }
    }
}

/// Follow as a plain word: "Follow" in the accent, then "Following".
struct HaarFollowButton: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    let follower: Follower

    private var isFollowing: Bool {
        if let url = item.feedURL, store.podcast(feedURL: url.absoluteString) != nil { return true }
        return follower.followed != nil
    }

    var body: some View {
        if follower.busy {
            ProgressView().frame(width: 64, height: 36)
        } else if isFollowing {
            Label("Following", systemImage: "checkmark")
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 64, height: 36)
                .accessibilityLabel("Following")
        } else {
            Button {
                Task { await follower.follow(item, store: store) }
            } label: {
                Text(follower.failed ? "Retry" : "Follow")
                    .font(Theme.text(14, .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minWidth: 64, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(follower.failed ? "Retry follow" : "Follow \(item.title)")
        }
    }
}

/// A "New to you" show: artwork, name, Follow.
private struct HaarSuggestion: View {
    let item: DirectoryItem
    @State private var follower = Follower()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: item) {
                VStack(alignment: .leading, spacing: 6) {
                    ArtworkView(url: item.artworkURL, title: item.title, size: 120, radius: 14)
                        .shadow(color: Color(hex: 0x28323C).opacity(0.14), radius: 10, y: 5)
                    Text(item.title)
                        .font(Theme.text(13, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
            HaarFollowButton(item: item, follower: follower)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -6)
        }
        .frame(width: 120)
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }
}

/// How each show has moved in a chart since an earlier day's chart, kept
/// on this iPhone (Apple's chart feed has no movement). The first day a
/// chart is seen there are no marks; after that, NEW for shows that
/// weren't in the earlier one.
enum ChartHistory {
    enum Move: Equatable {
        case up(Int), down(Int), same, new
    }

    private struct Saved: Codable {
        var day: String
        var ranks: [String: Int]
        var previous: [String: Int]?
    }

    /// Saves today's ranks (moving the last day's to "previous" on a new
    /// day) and returns each show's move against the previous day's.
    static func record(key: String, ids: [String], now: Date = Date()) -> [String: Move] {
        let defaults = UserDefaults.standard
        let storageKey = "chartHistory." + key
        let today = dayString(now)
        var saved: Saved? = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        var ranks: [String: Int] = [:]
        for (index, id) in ids.enumerated() where ranks[id] == nil {
            ranks[id] = index + 1
        }
        if var current = saved {
            if current.day != today {
                current.previous = current.ranks
                current.day = today
            }
            current.ranks = ranks
            saved = current
        } else {
            saved = Saved(day: today, ranks: ranks, previous: nil)
        }
        if let saved, let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: storageKey)
        }
        guard let previous = saved?.previous, !previous.isEmpty else { return [:] }
        var moves: [String: Move] = [:]
        for (id, rank) in ranks {
            if let before = previous[id] {
                if before > rank {
                    moves[id] = .up(before - rank)
                } else if before < rank {
                    moves[id] = .down(rank - before)
                } else {
                    moves[id] = .same
                }
            } else {
                moves[id] = .new
            }
        }
        return moves
    }

    private static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
