import SwiftUI
import SwiftData
import PodcastCore

// Up next suggestions (Paul, 15 Nov 2026): when Up next is down to its last
// episode (or none) besides the one playing, a few to add: episodes you
// started and didn't finish first, then unplayed ones from the last two
// weeks from Top shows (by rank), then from your other shows. Never one
// already in Up next or playing. Each a slim white card; + adds it to the
// end of Up next by the usual rules (with Undo), tap for the episode page.

extension LibraryStore {
    /// Up to `limit` episodes worth adding to Up next.
    func deckSuggestions(excluding playingID: String?, limit: Int = 3) -> [PodcastEpisode] {
        var taken: Set<String> = Set(queue.map(\.episode.id))
        if let playingID { taken.insert(playingID) }
        var picks: [PodcastEpisode] = []

        // 1. Started, not finished.
        for episode in continueListening(excluding: playingID, limit: 10) where !taken.contains(episode.episodeID) {
            guard picks.count < limit else { break }
            picks.append(episode)
            taken.insert(episode.episodeID)
        }
        guard picks.count < limit else { return picks }

        // 2. and 3. Unplayed from the last two weeks, one per show: Top
        // shows by rank (each show's oldest first, keeping its order), then
        // other followed shows, newest first.
        let cutoff: Date = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false && $0.published > cutoff },
            sortBy: [SortDescriptor(\.published, order: .forward)]
        )
        let recent: [PodcastEpisode] = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.podcast != nil && !taken.contains($0.episodeID) }
        let settings: QueueSettings = queueSettings
        var top: [PodcastEpisode] = []
        var others: [PodcastEpisode] = []
        for episode in recent {
            let showID: String = episode.podcast?.feedURL ?? ""
            if settings.mode(for: showID) == .top { top.append(episode) } else { others.append(episode) }
        }
        // Top shows in rank order (each show's oldest first, as `recent` is
        // oldest first); Top shows missing from the ranking come after.
        var rankedTop: [PodcastEpisode] = []
        for showID in settings.topRank {
            rankedTop.append(contentsOf: top.filter { $0.podcast?.feedURL == showID })
        }
        let ranked: Set<String> = Set(settings.topRank)
        rankedTop.append(contentsOf: top.filter { !ranked.contains($0.podcast?.feedURL ?? "") })
        let newestOthers: [PodcastEpisode] = Array(others.reversed())

        var shows: Set<String> = Set(picks.compactMap { $0.podcast?.feedURL })
        for episode in rankedTop + newestOthers {
            guard picks.count < limit else { break }
            let showID: String = episode.podcast?.feedURL ?? ""
            guard !shows.contains(showID) else { continue }
            shows.insert(showID)
            picks.append(episode)
        }
        return picks
    }
}

/// Words shared by the suggestion and saved-for-later cards.
@MainActor
enum DeckSuggestionWords {
    /// "Show · 34m", or "Show · 12m left" once started.
    static func detail(_ episode: PodcastEpisode) -> String {
        let show: String = episode.showTitle
        if episode.position > 30, let left = episode.timeLeft, left > 0 {
            return show + " · " + TimeFormat.length(left) + " left"
        }
        guard let duration = episode.duration, duration > 0 else { return show }
        return show + " · " + TimeFormat.length(duration)
    }
}

/// "Suggestions" and up to three slim cards.
struct DeckSuggestionsSection: View {
    let episodes: [PodcastEpisode]

    /// The label line and the space between cards, for fitting them in.
    static let labelHeight: CGFloat = 26
    static let cardHeight: CGFloat = 60
    static let gap: CGFloat = 6

    static func height(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return labelHeight + CGFloat(count) * cardHeight + CGFloat(count - 1) * gap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            DeckShowLabel(text: "Suggestions")
                .padding(.horizontal, 6)
                .frame(height: Self.labelHeight - Self.gap, alignment: .bottomLeading)
            ForEach(episodes, id: \.episodeID) { episode in
                DeckSuggestionCard(episode: episode)
            }
        }
    }
}

private struct DeckSuggestionCard: View {
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

    var body: some View {
        HStack(spacing: 12) {
            Button { store.notesEpisode = episode } label: { words }
                .buttonStyle(.plain)
            addKey
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: DeckSuggestionsSection.cardHeight,
               maxHeight: DeckSuggestionsSection.cardHeight, alignment: .leading)
        .deckPlainCard(radius: 18)
    }

    private var words: some View {
        HStack(spacing: 12) {
            DeckUpNextArtwork(episode: episode, size: 40, radius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(DeckSuggestionWords.detail(episode))
                    .font(Theme.outfit(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode page")
    }

    private var addKey: some View {
        Button {
            store.undoable("Added to Up next", episodes: []) { store.playLast(episode) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.background)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.ink))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add " + episode.title + " to Up next")
    }
}
