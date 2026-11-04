import SwiftUI
import PodcastCore

/// A show's mini homepage from Discover or search, before following it:
/// artwork, description, Follow, and its latest episodes (tap one for its
/// notes). Once followed, it links to the show's own page.
struct ShowPreviewView: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    @State private var follower = Follower()
    @State private var feed: ParsedFeed?
    @State private var failed = false
    @State private var expanded: String?

    var body: some View {
        List {
            header
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)
            Section {
                if let feed {
                    ForEach(feed.episodes.prefix(30), id: \.guid) { episode in
                        episodeRow(episode)
                            .listRowBackground(Theme.background)
                            .listRowSeparatorTint(Theme.hairline)
                    }
                } else if failed {
                    Text("Couldn't load this show's episodes. Pull down to try again.")
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.background)
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Theme.background)
                }
            } header: {
                DeckHeader(title: "Latest episodes", detail: feed.map { "\($0.episodes.count) in all" })
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }

    private var followedShow: Podcast? {
        if let followed = follower.justFollowed { return followed }
        return item.feedURL.flatMap { store.podcast(feedURL: $0.absoluteString) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ArtworkView(url: feed?.artworkURL ?? item.artworkURL, title: item.title, size: 110, radius: 10)
                VStack(alignment: .leading, spacing: 6) {
                    Text((feed?.title ?? item.title).uppercased())
                        .font(Theme.mono(19, .bold))
                        .foregroundStyle(Theme.ink)
                    if let author = feed?.author ?? item.artist {
                        Text(author.uppercased())
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.muted)
                    }
                    if let genre = item.genre { DeckTag(text: genre.uppercased()) }
                }
            }
            if let summary = feed?.summary.map(PlainText.fromHTML), !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            if let show = followedShow {
                NavigationLink(value: show) {
                    Text("✓ FOLLOWING · OPEN SHOW ▸")
                        .font(Theme.mono(12, .bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.key)
                .padding(.bottom, 3)
            } else {
                Button {
                    Task { await follower.follow(item, store: store) }
                } label: {
                    Group {
                        if follower.busy { ProgressView() } else { Text(follower.failed ? "TRY AGAIN" : "+ FOLLOW").font(Theme.mono(13, .bold)) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.accentKey)
                .disabled(follower.busy)
                .padding(.bottom, 3)
            }
        }
        .padding(.vertical, 8)
    }

    private func episodeRow(_ episode: ParsedEpisode) -> some View {
        let isOpen = expanded == episode.guid
        let summary = PlainText.fromHTML(episode.summary ?? "")
        let meta = [episode.published.map { $0.formatted(date: .abbreviated, time: .omitted) },
                    episode.duration.map { TimeFormat.clock($0) }].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 4) {
            Text(meta.uppercased())
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
            Text(episode.title)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
            if !summary.isEmpty {
                Text(summary)
                    .font(isOpen ? .subheadline : .caption)
                    .foregroundStyle(isOpen ? Theme.ink : Theme.muted)
                    .lineLimit(isOpen ? nil : 2)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded = isOpen ? nil : episode.guid } }
    }

    private func load() async {
        failed = false
        var url = item.feedURL
        if url == nil { url = (try? await FeedClient.lookup(appleID: item.appleID))?.feedURL }
        guard let url, let parsed = try? await FeedClient.fetchFeed(url) else {
            failed = feed == nil
            return
        }
        feed = parsed
    }
}
