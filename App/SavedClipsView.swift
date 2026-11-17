import SwiftUI
import SwiftData
import PodcastCore

/// Saved clips (bookmarked lines and shared clips), newest first.
struct SavedClipsView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Bookmark.created, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        let episodes = store.episodes(bookmarks.map(\.episodeID))
        List {
            if bookmarks.isEmpty {
                Text("Touch and hold a line in a transcript and choose Bookmark or Share a clip to save it here.")
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.rowBackground)
                    .listRowSeparator(.hidden)
            }
            ForEach(bookmarks) { bookmark in
                if let episode = episodes[bookmark.episodeID] {
                    ClipRow(bookmark: bookmark, episode: episode)
                        .listRowBackground(Theme.rowBackground)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.context.delete(bookmark)
                                store.save()
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("Saved clips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A saved clip: show and episode, the quote, Play from and Share.
struct ClipRow: View {
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

/// The label inside a small key in a list row.
func deckKeyLabel(_ text: String) -> some View {
    Text(text)
        .font(Theme.mono(11, .bold))
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
}
