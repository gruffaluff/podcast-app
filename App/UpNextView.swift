import SwiftUI
import PodcastCore

struct UpNextView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player

    var body: some View {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        let settings = store.queueSettings

        NavigationStack {
            List {
                Section {
                    ForEach(store.queue, id: \.episode.id) { item in
                        if let episode = episodes[item.episode.id] {
                            Button { player.play(episode) } label: {
                                QueueRow(item: item, episode: episode, settings: settings, isPlaying: player.nowPlaying?.episodeID == episode.episodeID)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Played") { store.markPlayed(episode.episodeID) }
                                    .tint(Theme.accentFill)
                                Button("Remove") { store.removeFromQueue(episode.episodeID) }
                                    .tint(Theme.muted)
                            }
                            .contextMenu {
                                Button("Mark as played", systemImage: "checkmark.circle") { store.markPlayed(episode.episodeID) }
                                Button("Remove from Up Next", systemImage: "minus.circle") { store.removeFromQueue(episode.episodeID) }
                            }
                        }
                    }
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
                } header: {
                    header(episodes: episodes)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .overlay {
                if store.queue.isEmpty {
                    ContentUnavailableView(
                        "Up Next is empty",
                        systemImage: "list.bullet",
                        description: Text("Follow shows in Library and set them to Top or Bottom, or use Play next on any episode.")
                    )
                    .foregroundStyle(Theme.muted)
                }
            }
            .refreshable { await store.refreshAll() }
            .navigationTitle("Up Next")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func header(episodes: [String: PodcastEpisode]) -> some View {
        let total = store.queue.compactMap { episodes[$0.episode.id]?.timeLeft }.reduce(0, +)
        var counts = "\(store.queue.count) episode\(store.queue.count == 1 ? "" : "s")"
        if total > 0 { counts += " · \(TimeFormat.length(total))" }

        return VStack(alignment: .leading, spacing: 4) {
            Text(checkedLabel)
            Text(counts)
        }
        .font(.footnote)
        .foregroundStyle(Theme.muted)
        .textCase(nil)
    }

    private var checkedLabel: String {
        if store.isRefreshing { return "Checking for new episodes…" }
        guard let last = store.lastChecked else { return "Pull to check for new episodes" }
        let ago = TimeFormat.ago(last)
        return "Checked \(ago == "Just now" ? "just now" : ago) · pull to check now"
    }
}

private struct QueueRow: View {
    let item: QueueItem
    let episode: PodcastEpisode
    let settings: QueueSettings
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title)
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.podcast?.title ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(episode.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts: [String] = []
        if isPlaying { parts.append("Playing") }
        if let left = episode.timeLeft, left > 0 {
            parts.append(episode.position > 30 ? "\(TimeFormat.length(left)) left" : TimeFormat.length(left))
        }
        parts.append(sourceLabel)
        return parts.joined(separator: " · ")
    }

    private var sourceLabel: String {
        switch item.source {
        case .manual:
            return "Added by you"
        case .auto:
            switch settings.mode(for: item.episode.showID) {
            case .top: return "Auto · Top"
            case .bottom: return "Auto · Bottom"
            case .off: return "Auto"
            }
        }
    }
}
