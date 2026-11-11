import SwiftUI
import SwiftData
import PodcastCore

/// Search across transcripts, your shows and episodes, and saved clips
/// (bookmarked lines for now; shared clips arrive in step 7).
struct SearchView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case transcripts = "Transcripts"
        case shows = "Shows"
        case clips = "Saved"
        var id: String { rawValue }
    }

    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Query(sort: \Podcast.title) private var shows: [Podcast]
    @Query(sort: \Bookmark.created, order: .reverse) private var bookmarks: [Bookmark]

    @State private var query = ""
    @State private var scope: Scope = .transcripts
    @State private var transcriptResults: [TranscriptIndex.Result] = []
    @State private var searching = false
    /// Recent searches, newest first (on this iPhone).
    @AppStorage("recentSearches") private var recentText = ""
    private var recents: [String] { recentText.split(separator: "\n").map(String.init) }

    private func remember(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        recentText = ([trimmed] + recents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }).prefix(10).joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                DeckSwitch(options: Scope.allCases.map { (label: $0.rawValue, value: $0) }, selection: $scope)
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)

                if query.isEmpty && !recents.isEmpty {
                    recentRows
                } else {
                    switch scope {
                    case .transcripts: transcriptRows
                    case .shows: showRows
                    case .clips: clipRows
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Words, people, shows")
            .onSubmit(of: .search) { remember(query) }
            .tabTitle("Search")
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            .task(id: query) { await searchTranscripts() }
        }
    }

    // MARK: Recent

    @ViewBuilder private var recentRows: some View {
        HStack {
            Text("RECENT SEARCHES").font(Theme.mono(11, .bold)).tracking(1.4).foregroundStyle(Theme.muted)
            Spacer()
            Button("Clear") { recentText = "" }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
        }
        .listRowBackground(Theme.background)
        .listRowSeparator(.hidden)
        ForEach(recents, id: \.self) { term in
            Button { query = term } label: {
                Label(term, systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.ink)
            }
            .listRowBackground(Theme.background)
        }
    }

    // MARK: Transcripts

    @ViewBuilder private var transcriptRows: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            hint("Search everything said in your episodes' transcripts.")
        } else if searching && transcriptResults.isEmpty {
            HStack { Spacer(); ProgressView(); Spacer() }
                .listRowBackground(Theme.background)
        } else if transcriptResults.isEmpty {
            hint("No transcript mentions “\(query)”.")
        } else {
            let episodes = store.episodes(transcriptResults.map(\.episodeID))
            ForEach(transcriptResults, id: \.episodeID) { result in
                if let episode = episodes[result.episodeID] {
                    ForEach(Array(result.matches.enumerated()), id: \.offset) { _, match in
                        TranscriptResultRow(episode: episode, match: match)
                            .showRow(episode.showArtwork, title: episode.showTitle)
                    }
                }
            }
        }
    }

    private func searchTranscripts() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            transcriptResults = []
            return
        }
        // Wait for typing to pause.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }

        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.transcriptFile != nil },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        let files = ((try? store.context.fetch(descriptor)) ?? []).compactMap { episode in
            episode.transcriptFile.map { TranscriptIndex.File(episodeID: episode.episodeID, fileName: $0) }
        }
        let results = await TranscriptIndex.shared.search(text, in: files)
        guard !Task.isCancelled else { return }
        transcriptResults = results
    }

    // MARK: Shows and episodes

    @ViewBuilder private var showRows: some View {
        let text = query.trimmingCharacters(in: .whitespaces)
        let matchingShows = text.isEmpty ? shows : shows.filter { contains($0.title, text) || contains($0.author, text) }
        if matchingShows.isEmpty && text.isEmpty {
            hint("Shows you follow appear here.")
        }
        ForEach(matchingShows) { show in
            NavigationLink(value: show) {
                HStack(spacing: 10) {
                    PosterRowText(label: show.author, title: show.title, titleSize: 18, lines: 2)
                    Stamp(url: show.artworkURL, title: show.title, size: 40)
                }
            }
            .showRow(show.artworkURL, title: show.title)
        }
        if text.count >= 2 {
            let episodes = matchingEpisodes(text)
            if !episodes.isEmpty {
                DeckHeader(title: "Episodes", detail: "\(episodes.count) found")
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
            ForEach(episodes) { episode in
                Button { player.play(episode) } label: {
                    HStack(spacing: 10) {
                        PosterRowText(label: episode.showTitle, title: episode.title, titleSize: 18, lines: 2, dim: episode.played)
                        Stamp(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 40)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { EpisodeMenuItems(episode: episode) }
                .showRow(episode.showArtwork, title: episode.showTitle)
            }
        }
    }

    private func matchingEpisodes(_ text: String) -> [PodcastEpisode] {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        descriptor.fetchLimit = 30
        return (try? store.context.fetch(descriptor)) ?? []
    }

    // MARK: Clips

    @ViewBuilder private var clipRows: some View {
        let text = query.trimmingCharacters(in: .whitespaces)
        let matching = text.isEmpty ? bookmarks : bookmarks.filter { contains($0.text, text) }
        if matching.isEmpty {
            hint(bookmarks.isEmpty ? "Touch and hold a line in a transcript and choose Bookmark to save it here." : "No saved clips mention “\(text)”.")
        }
        let episodes = store.episodes(matching.map(\.episodeID))
        ForEach(matching) { bookmark in
            if let episode = episodes[bookmark.episodeID] {
                ClipRow(bookmark: bookmark, episode: episode)
                    .showRow(episode.showArtwork, title: episode.showTitle)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.context.delete(bookmark)
                            store.save()
                        }
                    }
            }
        }
    }

    // MARK: Helpers

    private func contains(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .padding(.vertical, 12)
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
    }
}

/// A transcript match: episode, quote with the match highlighted, actions.
private struct TranscriptResultRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let match: TranscriptSearch.Match

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 36, radius: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text((episode.podcast?.title ?? "").uppercased()).font(Theme.mono(10)).foregroundStyle(Theme.muted)
                    Text(episode.title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink).lineLimit(1)
                }
            }
            Text(highlighted)
                .font(.system(.body))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Button {
                    player.play(episode)
                    player.seek(to: match.time)
                } label: {
                    deckKeyLabel("▶ \(TimeFormat.clock(match.time))")
                }
                .buttonStyle(KeyButtonStyle(kind: .dark, radius: 8))
                .accessibilityLabel("Play from \(TimeFormat.clock(match.time))")
                if !store.isQueued(episode) {
                    Button { store.playLast(episode) } label: {
                        deckKeyLabel("+ UP NEXT")
                    }
                    .buttonStyle(KeyButtonStyle(radius: 8))
                    .accessibilityLabel("Add to Up Next")
                }
            }
            .padding(.bottom, 3)
        }
        .padding(.vertical, 6)
    }

    private var highlighted: AttributedString {
        let snippet = match.snippet
        var before = AttributedString(String(snippet[..<match.highlight.lowerBound]))
        var hit = AttributedString(String(snippet[match.highlight]))
        let after = AttributedString(String(snippet[match.highlight.upperBound...]))
        hit.backgroundColor = Theme.highlight
        before.foregroundColor = Theme.ink
        return before + hit + after
    }
}

private struct ClipRow: View {
    @Environment(PlayerModel.self) private var player
    let bookmark: Bookmark
    let episode: PodcastEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(episode.podcast?.title ?? "") · \(episode.title)".uppercased())
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text("“\(bookmark.text)”")
                .font(.system(.body))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Button {
                    player.play(episode)
                    player.seek(to: bookmark.time)
                } label: {
                    deckKeyLabel("▶ \(TimeFormat.clock(bookmark.time))")
                }
                .buttonStyle(KeyButtonStyle(kind: .dark, radius: 8))
                .accessibilityLabel("Play from \(TimeFormat.clock(bookmark.time))")
                ShareLink(item: "“\(bookmark.text)”\n— \(episode.podcast?.title ?? ""), \(episode.title) (\(TimeFormat.clock(bookmark.time)))") {
                    deckKeyLabel("SHARE")
                }
                .buttonStyle(KeyButtonStyle(radius: 8))
            }
            .padding(.bottom, 3)
        }
        .padding(.vertical, 6)
    }
}

/// Searches transcript files off the main thread, keeping their lines in
/// memory after the first search.
actor TranscriptIndex {
    static let shared = TranscriptIndex()

    struct File: Sendable {
        let episodeID: String
        let fileName: String
    }

    struct Result: Sendable {
        let episodeID: String
        let matches: [TranscriptSearch.Match]
    }

    private var cache: [String: [TranscriptLayout.Line]] = [:]

    func search(_ query: String, in files: [File]) -> [Result] {
        var results: [Result] = []
        for file in files {
            if Task.isCancelled { break }
            let lines: [TranscriptLayout.Line]
            if let cached = cache[file.fileName] {
                lines = cached
            } else {
                lines = TranscriptFiles.load(file.fileName).map { TranscriptLayout.lines(from: $0.segments) } ?? []
                cache[file.fileName] = lines
            }
            let matches = TranscriptSearch.matches(of: query, in: lines)
            if !matches.isEmpty { results.append(Result(episodeID: file.episodeID, matches: matches)) }
        }
        return results
    }
}

/// The label inside a small key in a list row.
func deckKeyLabel(_ text: String) -> some View {
    Text(text)
        .font(Theme.mono(11, .bold))
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
}
