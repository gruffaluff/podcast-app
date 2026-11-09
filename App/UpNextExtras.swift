import SwiftUI
import PodcastCore

/// Up Next pulled up over the player: drag to reorder, swipe to remove,
/// total time at the current speed, and Keep playing new episodes.
struct UpNextSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    /// The first one that isn't playing now.
    private var nextIndex: Int? {
        store.queue.firstIndex { $0.episode.id != player.nowPlaying?.episodeID }
    }

    var body: some View {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        let total = store.queue.compactMap { episodes[$0.episode.id]?.timeLeft }.reduce(0, +)
        NavigationStack {
            List {
                Section {
                    ForEach(Array(store.queue.enumerated()), id: \.element.episode.id) { index, item in
                        let episode = episodes[item.episode.id]
                        // No numbers (the top is next); a small NEXT tag on the
                        // first one instead.
                        HStack(spacing: 12) {
                            ArtworkView(url: episode?.artwork, title: episode?.podcast?.title ?? item.episode.title, size: 42, radius: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.episode.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if index == nextIndex { DeckTag(text: "NEXT") }
                                    Text([episode?.podcast?.title, episode?.timeLeft.map { TimeFormat.clock($0) }].compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        // Same as the Up Next tab: the row paints its own
                        // colour edge to edge, banded rows instead of lines,
                        // iOS's own lift (no separate see-through copy).
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(rowColor(item, index: index))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(rowColor(item, index: index))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.undoable("Removed from Up Next", episodes: []) { store.removeFromQueue(item.episode.id) }
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                    // Long press and drag, like the Up Next tab. (Always-on
                    // edit mode here redrew rows in the wrong order after a
                    // move, then snapped back.)
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
                } header: {
                    Text(summary(total: total))
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                }
                Section {
                    Toggle(isOn: Binding(get: { store.keepPlayingNew }, set: { store.keepPlayingNew = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep playing new episodes").foregroundStyle(Theme.ink)
                            Text("When Up Next runs out, carry on with this week's new episodes.")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.accentFill)
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("UP NEXT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func rowColor(_ item: QueueItem, index: Int) -> Color {
        if item.episode.id == player.nowPlaying?.episodeID { return Theme.highlight }
        return index.isMultiple(of: 2) ? Theme.surface : Theme.surfaceBand
    }

    private func summary(total: TimeInterval) -> String {
        let count = "\(store.queue.count) episode\(store.queue.count == 1 ? "" : "s")"
        guard total > 0 else { return count }
        let atSpeed = player.speed > 1 ? " · about \(TimeFormat.clock(total / player.speed)) at \(PlayerOptions.speedLabel(player.speed))" : ""
        return "\(count) · \(TimeFormat.clock(total))\(atSpeed)"
    }
}

/// The episode page's status: where it is in Up Next, the download, and
/// the transcript, each with the one key that fits (Delete, Download,
/// Stop; Transcribe, Stop, Open).
struct EpisodeStatusRows: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode
    @Environment(\.dismiss) private var dismiss
    @State private var showingTranscript = false

    var body: some View {
        VStack(spacing: 8) {
            if let position = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) {
                // Tap to go to it in Up Next (Paul, 9 Nov 2026).
                Button {
                    store.revealInUpNext = episode.episodeID
                    dismiss()
                } label: {
                    row(icon: "list.number", title: "In Up Next · \(Self.ordinal(position + 1))", detail: "Show it in Up Next") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Up Next at this episode")
            }
            downloadRow
            transcriptRow
        }
        .sheet(isPresented: $showingTranscript) { TranscriptView(episode: episode) }
    }

    @ViewBuilder private var downloadRow: some View {
        if let progress = downloads.progress[episode.episodeID] {
            row(icon: "arrow.down.circle", title: "Downloading · \(Int(progress * 100))%", detail: "You can keep using the app") {
                key("STOP") { store.removeDownload(episode) }
            }
        } else if episode.downloadFile != nil {
            row(icon: "checkmark.circle.fill", title: "Downloaded", detail: "Plays offline") {
                key("DELETE") { store.removeDownload(episode) }
            }
        } else {
            row(icon: "arrow.down.circle", title: "Not downloaded", detail: "Streams when played") {
                key("DOWNLOAD", dark: true) { downloads.download(episode) }
            }
        }
    }

    @ViewBuilder private var transcriptRow: some View {
        switch episode.transcriptState {
        case .ready:
            row(icon: "text.quote", title: "Transcript ready", detail: transcripts.transcript(for: episode)?.source == .publisher ? "From the show" : "Made on this iPhone") {
                key("OPEN") { showingTranscript = true }
            }
        case .transcribing:
            row(icon: "waveform", title: "Transcribing on this iPhone…", detail: "Stop it if the phone gets warm or slow") {
                key("STOP", dark: true) { transcripts.stop(episode) }
            }
        case .waiting where transcripts.isQueued(episode):
            row(icon: "clock", title: "Waiting to transcribe", detail: transcripts.schedule.label) {
                key("STOP") { transcripts.stop(episode) }
            }
        default:
            row(icon: "text.quote", title: "No transcript", detail: "Made on this iPhone, nothing leaves it") {
                key("TRANSCRIBE", dark: true) { transcripts.transcribeNow(episode) }
            }
        }
    }

    private func row<Trailing: View>(icon: String, title: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }

    private func key(_ title: String, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(11, .bold))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
        }
        .buttonStyle(KeyButtonStyle(kind: dark ? .dark : .plain, radius: 12))
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
    }

    static func ordinal(_ n: Int) -> String {
        let tens = n % 100
        let suffix = (11...13).contains(tens) ? "th" : (n % 10 == 1 ? "st" : n % 10 == 2 ? "nd" : n % 10 == 3 ? "rd" : "th")
        return "\(n)\(suffix)"
    }
}

/// A show suggested when Up Next is empty (from Apple's UK chart, ones not
/// followed yet); the row opens its preview page, where it can be followed.
struct SuggestionRow: View {
    let item: DirectoryItem

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: item.artworkURL, title: item.title, size: 44, radius: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(item.artist ?? item.genre ?? "").font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
    }

    static func load(store: LibraryStore) async -> [DirectoryItem] {
        let followed = Set(store.allShows.map(\.feedURL))
        let chart = (try? await FeedClient.topChart()) ?? []
        return Array(chart.filter { $0.feedURL.map { !followed.contains($0.absoluteString) } ?? true }.prefix(5))
    }
}
