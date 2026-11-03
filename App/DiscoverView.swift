import SwiftUI
import SwiftData
import PodcastCore

/// Find new shows: search Apple's directory, browse by category, see shows
/// like the ones Paul follows, and the UK top charts.
struct DiscoverView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Podcast.followedAt, order: .reverse) private var followed: [Podcast]

    @State private var query = ""
    @State private var searchResults: [DirectoryItem] = []
    @State private var searching = false
    @State private var genre: PodcastGenre?
    @State private var chart: [DirectoryItem] = []
    @State private var chartFailed = false
    @State private var suggestions: (show: String, items: [DirectoryItem])?

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchSection
                } else {
                    categoryChips
                    if genre == nil, let suggestions, !suggestions.items.isEmpty {
                        suggestionsSection(suggestions.show, suggestions.items)
                    }
                    chartSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Shows, people, topics")
            .onSubmit(of: .search) { Task { await search() } }
            .task(id: query) { await search(debounced: true) }
            .task(id: genre) { await loadChart() }
            .task { await loadSuggestions() }
            .refreshable { await loadChart() }
            .navigationTitle("DISCOVER")
        }
    }

    // MARK: Search

    private var searchSection: some View {
        Section {
            if searching && searchResults.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if searchResults.isEmpty {
                Text("No shows found.").foregroundStyle(Theme.muted)
            }
            ForEach(searchResults) { DirectoryItemRow(item: $0) }
        }
        .listRowBackground(Theme.background)
        .listRowSeparatorTint(Theme.hairline)
    }

    private func search(debounced: Bool = false) async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard term.count >= 2 else { searchResults = []; return }
        if debounced {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }
        searching = true
        defer { searching = false }
        if let results = try? await FeedClient.searchDirectory(term), !Task.isCancelled {
            searchResults = results.map(DirectoryItem.init)
        }
    }

    // MARK: Categories and charts

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("UK top", selected: genre == nil) { genre = nil }
                ForEach(PodcastGenre.all) { item in
                    chip(item.name, selected: genre == item) { genre = item }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Theme.background)
        .listRowSeparator(.hidden)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(selected ? Theme.background : Theme.ink)
                .background(selected ? Theme.ink : Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var chartSection: some View {
        Section {
            if chart.isEmpty {
                if chartFailed {
                    Text("Couldn't load the charts. Pull down to try again.").foregroundStyle(Theme.muted)
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            ForEach(Array(chart.enumerated()), id: \.element.id) { index, item in
                DirectoryItemRow(item: item, rank: index + 1)
            }
        } header: {
            Text(genre.map { "Top in \($0.name)" } ?? "Top in the UK this week")
                .font(Theme.screenTitle(20))
                .foregroundStyle(Theme.ink)
                .textCase(nil)
        }
        .listRowBackground(Theme.background)
        .listRowSeparatorTint(Theme.hairline)
    }

    private func loadChart() async {
        chartFailed = false
        do {
            if let genre {
                chart = try await FeedClient.genreChart(genre)
            } else {
                chart = try await FeedClient.topChart()
            }
        } catch {
            if chart.isEmpty { chartFailed = true }
        }
    }

    // MARK: Because you listen to…

    private func suggestionsSection(_ showTitle: String, _ items: [DirectoryItem]) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { SuggestionCard(item: $0) }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Because you listen to \(showTitle)")
                .font(Theme.screenTitle(20))
                .foregroundStyle(Theme.ink)
                .textCase(nil)
        }
        .listRowBackground(Theme.background)
        .listRowSeparator(.hidden)
    }

    /// Shows in the same category as a followed show, minus ones already followed.
    private func loadSuggestions() async {
        guard suggestions == nil, !followed.isEmpty else { return }
        // Fill in categories for a few shows that don't have one yet.
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
}

/// A show in Discover with a Follow button. Following looks up the feed
/// if needed, then opens the show's settings sheet.
struct DirectoryItemRow: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    var rank: Int?
    @State private var follower = Follower()

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 24)
            }
            ArtworkView(url: item.artworkURL, title: item.title, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text([item.artist, item.genre].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            FollowButton(item: item, follower: follower)
        }
        .padding(.vertical, 4)
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }
}

private struct SuggestionCard: View {
    let item: DirectoryItem
    @State private var follower = Follower()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(url: item.artworkURL, title: item.title, size: 132, radius: 12)
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(2, reservesSpace: true)
            FollowButton(item: item, follower: follower)
        }
        .frame(width: 132)
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }
}

/// Follow state shared by a row and its button.
@MainActor
@Observable
final class Follower {
    var busy = false
    var failed = false
    var justFollowed: Podcast?

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
        let isNew = store.podcast(feedURL: feedURL.absoluteString) == nil
        guard let show = try? await store.follow(feedURL: feedURL) else { failed = true; return }
        if show.genre == nil { show.genre = item.genre }
        store.save()
        if isNew { justFollowed = show }
    }
}

private struct FollowButton: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    let follower: Follower

    private var isFollowing: Bool {
        if let url = item.feedURL, store.podcast(feedURL: url.absoluteString) != nil { return true }
        return follower.justFollowed != nil
    }

    var body: some View {
        if follower.busy {
            ProgressView().frame(width: 44, height: 32)
        } else if isFollowing {
            Label("Following", systemImage: "checkmark")
                .labelStyle(.iconOnly)
                .foregroundStyle(Theme.accentText)
                .frame(width: 44, height: 32)
                .accessibilityLabel("Following")
        } else {
            Button(follower.failed ? "Retry" : "Follow") {
                Task { await follower.follow(item, store: store) }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Theme.ink)
        }
    }
}
