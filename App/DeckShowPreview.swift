import SwiftUI
import PodcastCore
import UIKit

// Deck (Paul, 15 Nov 2026: "the show screen via Find is still the old
// one"): a show you don't follow yet, opened from Find or the charts, in
// the same look as a followed show's page (`DeckShowPage`): a white header
// card with the artwork, name and "publisher · genre · n episodes", one
// wide Follow pill (or "Following · Open show" in the show's colour), the
// description; then LATEST EPISODES as white cards (tap one for more of
// its notes). ShowPreviewView keeps the following itself.
//
// Each episode can go into Up next without following the show (Paul, 16
// Nov 2026: try a show for one guest or topic): "+ Up next" / "Play next"
// on its card, "In Up next" once it's there (TriedShows.swift).

struct DeckShowPreview: View {
    let item: DirectoryItem
    let feed: ParsedFeed?
    let feedURL: URL?
    let failed: Bool
    let followedShow: Podcast?
    let busy: Bool
    let followFailed: Bool
    let colour: Color
    let follow: () -> Void
    @State private var expanded: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                episodesLabel
                    .padding(.top, 22)
                episodes
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .deckPage()
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var art: URL? { feed?.artworkURL ?? item.artworkURL }
    private var title: String { feed?.title ?? item.title }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(url: art, title: title, size: 104, radius: 20)
                names
            }
            followKey
                .padding(.top, 14)
            if let summary = feed?.summary.map(PlainText.notesFromHTML), !summary.isEmpty {
                Text(summary)
                    .font(Theme.outfit(14, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 28)
        .task(id: art) { await ArtworkColors.shared.load(art) }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.outfit(24, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(byline)
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var byline: String {
        let count: String? = feed.map { "\($0.episodes.count) episodes" }
        return [feed?.author ?? item.artist, item.genre, count]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder private var followKey: some View {
        if let show = followedShow {
            NavigationLink(value: show) {
                DeckShowPill(title: "Following · Open show", icon: "checkmark", fill: colour, wide: true, height: 44)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: follow) {
                Group {
                    if busy {
                        ProgressView()
                            .tint(Theme.background)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Theme.ink))
                    } else {
                        DeckShowPill(title: followFailed ? "Try again" : "Follow", icon: "plus",
                                     on: true, wide: true, height: 44)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    // MARK: Episodes

    private var episodesLabel: some View {
        HStack {
            DeckShowLabel(text: "Latest episodes")
            Spacer(minLength: 8)
            if let feed {
                Text("\(feed.episodes.count) in all")
                    .font(Theme.outfit(12, .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder private var episodes: some View {
        if let feed {
            LazyVStack(spacing: 8) {
                ForEach(Array(feed.episodes.prefix(30)), id: \.guid) { episode in
                    DeckPreviewEpisodeCard(episode: episode, feed: feed, feedURL: feedURL,
                                           open: expanded == episode.guid) {
                        expanded = expanded == episode.guid ? nil : episode.guid
                    }
                }
            }
        } else if failed {
            Text("Couldn't load this show's episodes. Pull down to try again.")
                .font(Theme.outfit(14, .medium))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }
}

/// One episode of a show not yet followed: date · length, the title (two
/// lines' room), two lines of notes; tap for all of them.
private struct DeckPreviewEpisodeCard: View {
    @Environment(LibraryStore.self) private var store
    let episode: ParsedEpisode
    let feed: ParsedFeed
    let feedURL: URL?
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meta.uppercased())
                .font(Theme.outfit(11, .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(16, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2, reservesSpace: true)
            if !summary.isEmpty {
                Text(summary)
                    .font(Theme.outfit(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(open ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let feedURL {
                queueKeys(feedURL)
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) { toggle() }
        }
    }

    private var meta: String {
        [episode.published.map { $0.formatted(date: .abbreviated, time: .omitted) },
         episode.duration.map { TimeFormat.clock($0) }].compactMap { $0 }.joined(separator: " · ")
    }

    private var summary: String { PlainText.notesFromHTML(episode.summary ?? "") }

    /// "+ Up next" and "Play next", or "In Up next" once it's there. No
    /// need to follow the show first.
    @ViewBuilder private func queueKeys(_ feedURL: URL) -> some View {
        if store.isQueued(feedURL: feedURL, guid: episode.guid) {
            DeckShowPill(title: "In Up next", icon: "checkmark", height: 32)
                .opacity(0.6)
                .accessibilityLabel("In Up next")
        } else {
            HStack(spacing: 8) {
                Button { add(feedURL, next: false) } label: {
                    DeckShowPill(title: "Up next", icon: "plus", on: true, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to the end of Up next")
                Button { add(feedURL, next: true) } label: {
                    DeckShowPill(title: "Play next", icon: "text.line.first.and.arrowtriangle.forward", height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func add(_ feedURL: URL, next: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.addWithoutFollowing(feedURL: feedURL, feed: feed, guid: episode.guid, next: next)
    }
}
