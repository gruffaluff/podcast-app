import SwiftUI
import SwiftData
import PodcastCore

// Deck (Paul, 14 Nov 2026): the New sheet from the Shows tab's "New · n"
// pill (prototype sheet "new"). This week's new episodes, already dealt
// into Up next by each show's rule; each says where it is, with + to add
// it and ✓ to mark it played. Add all / Mark all played at the bottom.

struct DeckShowsNewSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    /// The episode page opened from here (shown over this sheet; the root
    /// view can't show one while this sheet is up).
    @State private var opened: PodcastEpisode?

    private var fresh: [PodcastEpisode] {
        let cutoff: Date = Date().addingTimeInterval(-LibraryView.newFor)
        return unplayed.filter { $0.podcast != nil && DeckShowOrder.isNew($0, cutoff: cutoff) }
    }

    var body: some View {
        let list: [PodcastEpisode] = fresh
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                heading(list.count)
                if list.isEmpty {
                    Text("All caught up.")
                        .font(Theme.outfit(15, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(list, id: \.episodeID) { episode in
                        DeckShowsNewRow(episode: episode) { opened = episode }
                    }
                    actions(list)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            UndoBar()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.background)
        .sheet(item: $opened) { episode in
            EpisodeNotesView(episode: episode)
        }
    }

    private func heading(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count) new this week")
                .font(Theme.outfit(22, .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Already dealt in by your rules. Shows set to Nowhere wait here.")
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private func actions(_ list: [PodcastEpisode]) -> some View {
        let missing: [PodcastEpisode] = list.filter { !store.isQueued($0) }
        return HStack(spacing: 8) {
            Button { addAll(missing) } label: {
                DeckShowPill(title: missing.isEmpty ? "All in Up next" : "Add all to Up next",
                             on: !missing.isEmpty, wide: true, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(missing.isEmpty)
            Button { markAll(list) } label: {
                DeckShowPill(title: "Mark all played", wide: true, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// Those not in Up next yet go in, oldest first, by the queue rules.
    private func addAll(_ missing: [PodcastEpisode]) {
        guard !missing.isEmpty else { return }
        let oldestFirst: [PodcastEpisode] = missing.sorted { $0.published < $1.published }
        store.undoable("Added \(oldestFirst.count) to Up next", episodes: []) {
            store.commit(QueueEngine.playLast(oldestFirst.map(\.queueEpisode), in: store.queue, settings: store.queueSettings))
        }
    }

    private func markAll(_ list: [PodcastEpisode]) {
        store.undoable("Marked \(list.count) played", episodes: list) { store.markPlayed(list) }
    }
}

/// One new episode: artwork (plays), show · when, title, its place in Up
/// next; + (when not in Up next) and ✓.
private struct DeckShowsNewRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { player.play(episode) } label: {
                ArtworkView(url: episode.artwork, title: episode.showTitle, size: 44, radius: 11)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(episode.title)")
            Button(action: open) { words }
                .buttonStyle(.plain)
            if !store.isQueued(episode) {
                round("plus", label: "Add to Up next", dark: true) {
                    withAnimation(LibraryStore.listChange) { store.playLast(episode) }
                }
            }
            round("checkmark", label: "Mark played", dark: false) {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .deckPlainCard(radius: 18)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(episode.showTitle + " · " + TimeFormat.ago(episode.published))
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(place)
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var place: String {
        guard let index = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) else { return "Not in Up next" }
        return "\(EpisodeStatusRows.ordinal(index + 1)) in Up next"
    }

    private func round(_ symbol: String, label: String, dark: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(dark ? Theme.background : Theme.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(dark ? Theme.ink : Theme.cardLine))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
