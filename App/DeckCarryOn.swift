import SwiftUI
import PodcastCore

// Deck (Paul, 15 Nov 2026: "add all 4" of the gaps): Carry on on the Shows
// tab, above the show cards. Episodes started and not finished (not the one
// playing, which is Up next's top card), up to three, each a slim white
// card: artwork with a ring showing how far through, title, "show · 34m
// left", and a play key. Tap the card for the episode page.

struct DeckCarryOnSection: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @State private var episodes: [PodcastEpisode] = []

    var body: some View {
        Group {
            if !episodes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    DeckShowLabel(text: "Carry on")
                        .padding(.horizontal, 22)
                    VStack(spacing: 8) {
                        ForEach(episodes, id: \.episodeID) { episode in
                            DeckCarryOnCard(episode: episode)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: player.nowPlaying?.episodeID) { _, _ in reload() }
        .onChange(of: player.isPlaying) { _, _ in reload() }
    }

    private func reload() {
        episodes = store.continueListening(excluding: player.nowPlaying?.episodeID, limit: 3)
    }
}

private struct DeckCarryOnCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        HStack(spacing: 12) {
            Button { store.notesEpisode = episode } label: { words }
                .buttonStyle(.plain)
            playKey
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 20)
    }

    private var words: some View {
        HStack(spacing: 12) {
            ring
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail)
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

    /// The artwork inside a thin ring that fills as far as you've got.
    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.cardEdge, lineWidth: 3)
            Circle().trim(from: 0, to: fraction)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ArtworkView(url: episode.artwork, title: episode.showTitle, size: 36, radius: 18)
        }
        .frame(width: 46, height: 46)
    }

    private var playKey: some View {
        Button { player.play(episode) } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.background)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.ink))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play " + episode.title)
    }

    private var fraction: Double {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        return min(1, max(0.03, episode.position / duration))
    }

    private var detail: String {
        guard let left = episode.timeLeft else { return episode.showTitle }
        return episode.showTitle + " · " + TimeFormat.length(left) + " left"
    }
}
