import SwiftUI
import PodcastCore

/// A show's mini homepage from Find or the charts, before following it:
/// artwork, description, Follow, and its latest episodes (tap one for its
/// notes). Once followed, it links to the show's own page. Drawn by
/// `DeckShowPreview`, the same look as a followed show's page.
struct ShowPreviewView: View {
    @Environment(LibraryStore.self) private var store
    let item: DirectoryItem
    /// The page's colour, fixed when it opens so nothing changes colour
    /// while it's on screen (Paul, 11 Nov 2026). Unknown = neutral for
    /// this visit; it's measured for next time.
    @State private var pageColour: Color?

    init(item: DirectoryItem) {
        self.item = item
        _pageColour = State(initialValue: ArtworkColors.shared.background(for: item.artworkURL))
    }
    /// Follow opens the Deck follow sheet (where new episodes go, alerts,
    /// download the newest).
    @State private var deckFollower = DeckFollower()
    @State private var feed: ParsedFeed?
    /// The feed's link once known (charts may only give Apple's ID).
    @State private var feedURL: URL?
    @State private var failed = false

    var body: some View {
        DeckShowPreview(item: item, feed: feed, feedURL: feedURL, failed: failed, followedShow: followedShow,
                        busy: deckFollower.busy, followFailed: deckFollower.failed,
                        colour: pageColour ?? Theme.ink, follow: followTapped)
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $deckFollower.sheetShow) { DeckFollowSheet(show: $0) }
    }

    private func followTapped() {
        Task { await deckFollower.follow(item, store: store) }
    }

    private var followedShow: Podcast? {
        if let followed = deckFollower.followed { return followed }
        return item.feedURL.flatMap { store.followedPodcast(feedURL: $0.absoluteString) }
    }

    private func load() async {
        failed = false
        var url = item.feedURL
        if url == nil { url = (try? await FeedClient.lookup(appleID: item.appleID))?.feedURL }
        guard let url, let parsed = try? await FeedClient.fetchFeed(url) else {
            failed = feed == nil
            return
        }
        feedURL = url
        feed = parsed
    }
}
