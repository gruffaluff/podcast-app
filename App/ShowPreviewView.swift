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
                .listRowInsets(EdgeInsets())
            Section {
                if let feed {
                    let shown = Array(feed.episodes.prefix(30))
                    ForEach(Array(shown.enumerated()), id: \.element.guid) { index, episode in
                        episodeRow(episode)
                            .showRow(feed.artworkURL ?? item.artworkURL, title: feed.title)
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
        .ignoresSafeArea(edges: .top)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $follower.justFollowed) { ShowSettingsView(show: $0, justFollowed: true) }
    }

    private var followedShow: Podcast? {
        if let followed = follower.followed { return followed }
        return item.feedURL.flatMap { store.podcast(feedURL: $0.absoluteString) }
    }

    /// Same look as a followed show's page: the artwork filling the card,
    /// fading into its colour, big title, then Follow (or Open show).
    private var header: some View {
        let art = feed?.artworkURL ?? item.artworkURL
        let tint = ArtworkColors.shared.background(for: art) ?? Theme.display
        return VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 170)
            // The show's poster, the artwork as a stamp beside the name.
            HStack(alignment: .bottom, spacing: 12) {
                Stamp(url: art, title: feed?.title ?? item.title, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text([feed?.author ?? item.artist, item.genre, feed.map { "\($0.episodes.count) episodes" }].compactMap { $0 }.joined(separator: " · ").uppercased())
                        .font(Theme.mono(9.5))
                        .tracking(0.8)
                        .foregroundStyle(Theme.displayDim)
                        .lineLimit(2)
                    Text((feed?.title ?? item.title).uppercased())
                        .font(Theme.big(40))
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            if let show = followedShow {
                NavigationLink(value: show) {
                    Text("✓ FOLLOWING · OPEN SHOW ▸")
                        .font(Theme.mono(12, .bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.displayText, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await follower.follow(item, store: store) }
                } label: {
                    Group {
                        if follower.busy { ProgressView().tint(tint) } else { Text(follower.failed ? "TRY AGAIN" : "+ FOLLOW").font(Theme.mono(13, .bold)) }
                    }
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.displayText, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .disabled(follower.busy)
            }
            if let summary = feed?.summary.map(PlainText.notesFromHTML), !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.displayDim)
                    .lineLimit(4)
            }
        }
        .foregroundStyle(Theme.displayText)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ShowHeroBackground(url: art, tint: tint) }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36))
        .task(id: art) { await ArtworkColors.shared.load(art) }
    }

    private func episodeRow(_ episode: ParsedEpisode) -> some View {
        let isOpen = expanded == episode.guid
        let summary = PlainText.notesFromHTML(episode.summary ?? "")
        let meta = [episode.published.map { $0.formatted(date: .abbreviated, time: .omitted) },
                    episode.duration.map { TimeFormat.clock($0) }].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 4) {
            PosterRowText(label: meta, title: episode.title, titleSize: 18, lines: 3)
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
        .onTapGesture {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { expanded = isOpen ? nil : episode.guid }
        }
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
