import SwiftUI
import PodcastCore

struct UpNextView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @State private var showingPriority = false
    /// Edit mode: ≡ handles and delete buttons on every row.
    @State private var editing = false
    /// Shows from the chart, offered when Up Next is empty.
    @State private var suggestions: [DirectoryItem] = []
    /// The row whose keys are showing (tap a row to open, again to close).
    @State private var openRow: String?

    var body: some View {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        let settings = store.queueSettings

        NavigationStack {
            List {
                Section {
                    ForEach(Array(store.queue.enumerated()), id: \.element.episode.id) { index, item in
                        if let episode = episodes[item.episode.id] {
                            queueRow(index: index, item: item, episode: episode, settings: settings)
                        }
                    }
                    // Long press and drag to reorder (Paul); the reorder key
                    // shows the handles and delete buttons too. No long-press
                    // menu on these rows: it fought the drag for the same
                    // press (the row keys cover everything it had).
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
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
                        // Each suggestion is its own row (several links in one
                        // row all opened at once).
                        if !suggestions.isEmpty {
                            Text("SOMETHING NEW TO TRY")
                                .font(Theme.mono(11, .bold))
                                .tracking(1.4)
                                .foregroundStyle(Theme.muted)
                                .listRowBackground(Theme.background)
                                .listRowSeparator(.hidden)
                            ForEach(suggestions) { item in
                                NavigationLink {
                                    ShowPreviewView(item: item)
                                } label: {
                                    SuggestionRow(item: item)
                                }
                                .listRowBackground(Theme.background)
                                .listRowSeparatorTint(Theme.hairline)
                            }
                        }
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
            .environment(\.editMode, .constant(editing ? .active : .inactive))
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .task(id: store.queue.isEmpty) {
                if store.queue.isEmpty, suggestions.isEmpty {
                    suggestions = await SuggestionRow.load(store: store)
                }
            }
            .tabTitle("UP NEXT")
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            .toolbar {
                // Reorder / remove mode (long press and drag works anyway).
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { editing.toggle() } } label: {
                        Image(systemName: editing ? "checkmark" : "arrow.up.arrow.down")
                    }
                    .accessibilityLabel(editing ? "Done reordering" : "Reorder Up Next")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingPriority = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Shows and settings")
                }
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

    /// One Up Next row: tap for its keys, artwork to play, swipe right for
    /// notes / to the top, swipe left for played / remove.
    private func queueRow(index: Int, item: QueueItem, episode: PodcastEpisode, settings: QueueSettings) -> some View {
        let isOpen = openRow == episode.episodeID
        return VStack(spacing: 8) {
            // Tap a row for its keys; the artwork plays (Paul, A + C).
            QueueRow(number: index + 1, item: item, episode: episode, settings: settings, isPlaying: player.nowPlaying?.episodeID == episode.episodeID) {
                player.play(episode)
            }
            .onTapGesture { toggleRow(episode.episodeID) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isOpen ? "Hides the keys" : "Shows play, notes, download and more")
            if isOpen {
                UpNextRowKeys(episode: episode) { openRow = nil }
                    .padding(.bottom, 4)
            }
        }
        // Each row is its own paper card (no system lines): lines tied to
        // a row's place flickered in the wrong spots while dragging.
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 9, leading: 24, bottom: 9, trailing: 24))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
        )
        // Swipe right: notes (a full swipe opens them) and to the top.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Notes", systemImage: "doc.text") { store.notesEpisode = episode }
                .tint(Theme.accentFill)
            Button("To top", systemImage: "arrow.up.to.line") { store.playNext(episode) }
                .tint(Theme.muted)
        }
        .swipeActions(edge: .trailing) {
            Button("Played") {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
            .tint(Theme.ink)
            Button("Remove") {
                store.undoable("Removed from Up Next", episodes: []) { store.removeFromQueue(episode.episodeID) }
            }
            .tint(Theme.muted)
        }
    }

    private func toggleRow(_ id: String) {
        // No animation: List resizing rows animates jerkily.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { openRow = openRow == id ? nil : id }
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
    /// Tapping the artwork plays straight away.
    let play: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: play) {
                ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 46, radius: 8)
                    .overlay {
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 8).stroke(Theme.accentFill, lineWidth: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play number \(number)")
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let tag { DeckTag(text: tag) }
                    Text(episode.podcast?.title ?? "")
                        .lineLimit(1)
                }
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
                // Always takes its line (blank when there's nothing to say),
                // so rows don't change height when one starts playing.
                Text((status ?? " ").uppercased())
                    .font(Theme.mono(10))
                    .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
                    .lineLimit(1)
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
        .contentShape(Rectangle())
    }

    /// TOP1 / TOP2 (rank) or BTM for episodes added by a show's setting;
    /// none for episodes Paul added himself.
    private var tag: String? {
        switch item.source {
        case .manual: return nil
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

/// The keys under an opened Up Next row: play, notes, download,
/// transcribe, to the top, played, remove (Paul's option A).
private struct UpNextRowKeys: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode
    let close: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            playKey
            key("NOTES", icon: "doc.text") { store.notesEpisode = episode }
            downloadKey
            transcriptKey
            key("TO TOP", icon: "arrow.up.to.line") {
                store.playNext(episode)
                close()
            }
            key("PLAYED", icon: "checkmark") {
                close()
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
            key("REMOVE", icon: "xmark") {
                close()
                store.undoable("Removed from Up Next", episodes: []) { store.removeFromQueue(episode.episodeID) }
            }
        }
    }

    @ViewBuilder private var playKey: some View {
        let isThis = player.nowPlaying?.episodeID == episode.episodeID
        if isThis && player.isPlaying {
            key("PAUSE", icon: "pause.fill", dark: true) { player.pause() }
        } else {
            key("PLAY", icon: "play.fill", dark: true) { player.play(episode) }
        }
    }

    @ViewBuilder private var downloadKey: some View {
        if let fraction = downloads.progress[episode.episodeID] {
            key("\(Int(fraction * 100))%", icon: "stop.circle") { store.removeDownload(episode) }
                .accessibilityLabel("Stop download")
        } else if episode.downloadFile != nil {
            key("DEL DL", icon: "trash") { store.removeDownload(episode) }
                .accessibilityLabel("Delete download")
        } else {
            key("DL", icon: "arrow.down.circle") { downloads.download(episode) }
                .accessibilityLabel("Download")
        }
    }

    @ViewBuilder private var transcriptKey: some View {
        if transcripts.isQueued(episode) {
            key("STOP TX", icon: "stop.circle") { transcripts.stop(episode) }
                .accessibilityLabel("Stop transcribing")
        } else if transcripts.canTranscribeNow(episode) {
            key("TX", icon: "text.quote") { transcripts.transcribeNow(episode) }
                .accessibilityLabel("Transcribe now")
        } else {
            key("TX", icon: "text.quote") { store.notesEpisode = episode }
                .accessibilityLabel("Transcript")
        }
    }

    private func key(_ title: String, icon: String, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(Theme.mono(8, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(KeyButtonStyle(kind: dark ? .dark : .plain, radius: 8))
    }
}
