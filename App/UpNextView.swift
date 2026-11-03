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
                if player.nowPlaying != nil {
                    Section {
                        NowPlayingDeck()
                            .listRowBackground(Theme.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 8, trailing: 14))
                    }
                }
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
                                Button("Mark as played", systemImage: "checkmark.circle") { store.markPlayed(episode.episodeID) }
                                Button("Remove from Up Next", systemImage: "minus.circle") { store.removeFromQueue(episode.episodeID) }
                            }
                        }
                    }
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.hairline)
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
            .overlay {
                if store.queue.isEmpty {
                    ContentUnavailableView(
                        "Up Next is empty",
                        systemImage: "list.bullet",
                        description: Text("Follow shows in Library and set them to Top or Bottom, or use Play next on any episode.")
                    )
                    .foregroundStyle(Theme.muted)
                    .allowsHitTesting(false)
                }
            }
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

/// The display panel at the top of Up Next: what's playing, segmented
/// progress (ads in amber), and a Skip ad key while an ad plays.
private struct NowPlayingDeck: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        if let item = player.nowPlaying {
            DeckDisplay {
                HStack {
                    Text("NOW ▸ \(item.showTitle.uppercased())").lineLimit(1)
                    Spacer()
                    Text(modes)
                }
                .font(Theme.mono(11))
                .foregroundStyle(Theme.displayDim)
                Text(item.title.uppercased())
                    .font(Theme.mono(15, .semibold))
                    .lineLimit(1)
                SegmentBar(progress: progress, ads: adFractions, count: 24)
                HStack {
                    Text("\(TimeFormat.clock(player.currentTime)) / \(TimeFormat.clock(player.duration))")
                        .monospacedDigit()
                    Spacer()
                    if player.currentAd != nil {
                        Button { player.skipCurrentAd() } label: {
                            Text("SKIP AD ▸▸").font(Theme.mono(12, .bold)).padding(.horizontal, 12).frame(minHeight: 36)
                        }
                        .buttonStyle(.accentKey)
                    } else {
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .frame(width: 44, height: 36)
                        }
                        .buttonStyle(.key)
                        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    }
                }
            }
        }
    }

    private var progress: Double {
        player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }

    private var modes: String {
        var parts = [PlayerOptions.speedLabel(player.speed)]
        if player.trimSilences { parts.append("TRIM") }
        if player.boostVoices { parts.append("BOOST") }
        return parts.joined(separator: " · ")
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
                HStack(spacing: 3) {
                    LED(on: episode.downloadFile != nil)
                    LED(on: episode.transcriptState == .ready, color: Theme.accentFill)
                }
                .accessibilityElement()
                .accessibilityLabel(lightsLabel)
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

    private var lightsLabel: String {
        let downloaded = episode.downloadFile != nil ? "Downloaded" : "Not downloaded"
        let transcript = episode.transcriptState == .ready ? "transcript ready" : "no transcript"
        return "\(downloaded), \(transcript)"
    }
}
