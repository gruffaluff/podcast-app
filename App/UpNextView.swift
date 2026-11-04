import SwiftUI
import PodcastCore

struct UpNextView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @State private var showingPriority = false

    var body: some View {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        let settings = store.queueSettings

        NavigationStack {
            List {
                Section {
                    ForEach(Array(store.queue.enumerated()), id: \.element.episode.id) { index, item in
                        if let episode = episodes[item.episode.id] {
                            Button { player.play(episode) } label: {
                                QueueRow(number: index + 1, item: item, episode: episode, settings: settings, isPlaying: player.nowPlaying?.episodeID == episode.episodeID)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Played") { store.markPlayed(episode.episodeID) }
                                    .tint(Theme.ink)
                                Button("Remove") { store.removeFromQueue(episode.episodeID) }
                                    .tint(Theme.muted)
                            }
                            .contextMenu {
                                if transcripts.canTranscribeNow(episode) {
                                    Button("Transcribe now", systemImage: "text.quote") { transcripts.transcribeNow(episode) }
                                }
                                Button("Episode notes", systemImage: "doc.text") { store.notesEpisode = episode }
                                Button("Mark as played", systemImage: "checkmark.circle") { store.markPlayed(episode.episodeID) }
                                Button("Remove from Up Next", systemImage: "minus.circle") { store.removeFromQueue(episode.episodeID) }
                            }
                        }
                    }
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.hairline)
                    if store.queue.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UP NEXT IS EMPTY")
                                .font(Theme.mono(13, .bold))
                                .foregroundStyle(Theme.ink)
                            Text("Set shows to Top or Bottom (Library → a show → Off / Top / Bottom), or use Play next on any episode.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 10)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    header(episodes: episodes)
                }

                Section {
                    Toggle(isOn: Binding(get: { store.keepPlayingNew }, set: { store.keepPlayingNew = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep playing new episodes")
                                .foregroundStyle(Theme.ink)
                            Text("When Up Next runs out, carry on with this week's new episodes from your auto-add shows.")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.accentFill)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .navigationTitle("UP NEXT")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingPriority = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Top show priority")
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .sheet(isPresented: $showingPriority) {
                NavigationStack {
                    TopPriorityView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingPriority = false }
                            }
                        }
                }
            }
        }
    }

    private func header(episodes: [String: PodcastEpisode]) -> some View {
        let total = store.queue.compactMap { episodes[$0.episode.id]?.timeLeft }.reduce(0, +)
        var counts = "\(store.queue.count) EPISODE\(store.queue.count == 1 ? "" : "S")"
        if total > 0 { counts += " · TOTAL \(TimeFormat.clock(total))" }

        return VStack(alignment: .leading, spacing: 4) {
            Text(counts)
            Text(checkedLabel)
        }
        .font(Theme.mono(11))
        .foregroundStyle(Theme.muted)
        .textCase(nil)
    }

    private var checkedLabel: String {
        if store.isRefreshing { return "CHECKING FOR NEW EPISODES…" }
        guard let last = store.lastChecked else { return "PULL TO CHECK FOR NEW EPISODES" }
        return "CHECKED \(TimeFormat.ago(last).uppercased()) · PULL TO CHECK"
    }
}

private struct QueueRow: View {
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let number: Int
    let item: QueueItem
    let episode: PodcastEpisode
    let settings: QueueSettings
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(number < 10 ? "0\(number)" : "\(number)")
                .font(Theme.mono(15, .bold))
                .foregroundStyle(isPlaying ? Theme.accentText : Theme.ink)
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    DeckTag(text: tag)
                    Text(episode.podcast?.title ?? "")
                        .lineLimit(1)
                }
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
                if let status {
                    Text(status.uppercased())
                        .font(Theme.mono(10))
                        .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) {
                Text(episode.timeLeft.map { TimeFormat.clock($0) } ?? "--:--")
                    .font(Theme.mono(12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                EpisodeLights(episode: episode)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// TOP1 / TOP2 (rank), BTM, or YOU for episodes Paul added.
    private var tag: String {
        switch item.source {
        case .manual: return "YOU"
        case .auto:
            switch settings.mode(for: item.episode.showID) {
            case .top:
                let rank = settings.rank(of: item.episode.showID)
                return rank == Int.max ? "TOP" : "TOP\(rank + 1)"
            case .bottom: return "BTM"
            case .off: return "AUTO"
            }
        }
    }

    /// Only the things worth a line: playing, downloading, transcribing.
    private var status: String? {
        var parts: [String] = []
        if isPlaying { parts.append("Playing") }
        if let download = downloads.status(for: episode), download != "Downloaded" { parts.append(download) }
        switch episode.transcriptState {
        case .transcribing: parts.append("Transcribing")
        case .waiting:
            if transcripts.schedule != .onRequest || !transcripts.canTranscribeNow(episode) { parts.append("Transcript waiting") }
        default: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

}
