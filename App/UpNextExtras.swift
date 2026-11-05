import SwiftUI
import PodcastCore

/// Up Next's top: what's playing, in its artwork's colour with the artwork
/// fading in, with skip / play keys and progress. Tap the title (or the
/// handle) to open the full player. Replaces the mini player on this tab.
struct NowPlayingHeader: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        if let item = player.nowPlaying {
            let tint = ArtworkColors.shared.background(for: item.artworkURL) ?? Theme.display
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NOW PLAYING · \(PlayerOptions.speedLabel(player.speed))" + (player.trimSilences ? " · TRIM" : ""))
                        .font(Theme.mono(11, .bold))
                        .tracking(1.2)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(.black.opacity(0.22), in: Capsule())
                    Spacer()
                    if player.currentAd != nil {
                        Button { player.skipCurrentAd() } label: {
                            Text("SKIP AD")
                                .font(Theme.mono(12, .bold))
                                .foregroundStyle(Theme.adText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(Theme.highlight, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { player.requestOpenPlayer() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title.uppercased())
                            .font(Theme.big(30))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                        Text(item.showTitle + (player.currentChapter.map { " · \($0.title)" } ?? ""))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.displayDim)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 70)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the player")
                HStack(spacing: 10) {
                    SkipButton(direction: .back, iconSize: 18, frame: 44)
                        .overlay(Circle().stroke(Theme.displayText, lineWidth: 2))
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(tint)
                            .frame(width: 54, height: 54)
                            .background(Theme.displayText, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    SkipButton(direction: .forward, iconSize: 18, frame: 44)
                        .overlay(Circle().stroke(Theme.displayText, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 6) {
                        SegmentBar(progress: progress, ads: adFractions, count: 30, height: 6)
                        Text(player.duration > 0 ? "\(TimeFormat.clock(max(0, player.duration - player.currentTime))) left" : " ")
                            .font(Theme.mono(12, .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.displayDim)
                    }
                }
                Button { player.requestOpenPlayer() } label: {
                    Capsule().fill(Theme.displayText.opacity(0.5)).frame(width: 36, height: 5)
                        .frame(maxWidth: .infinity, minHeight: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open the player")
            }
            .foregroundStyle(Theme.displayText)
            .tint(Theme.displayText)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .background {
                ZStack(alignment: .topTrailing) {
                    tint
                    CachedImage(url: item.artworkURL) { Color.clear }
                        .frame(width: 220, height: 220)
                        .offset(x: 50, y: -10)
                        .mask(
                            RadialGradient(colors: [.black, .black.opacity(0)], center: UnitPoint(x: 0.6, y: 0.45), startRadius: 40, endRadius: 150)
                                .frame(width: 220, height: 220)
                                .offset(x: 50, y: -10)
                        )
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
        }
    }

    private var progress: Double {
        player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }
}

/// Up Next pulled up over the player: drag to reorder, swipe to remove,
/// total time at the current speed, and Keep playing new episodes.
struct UpNextSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        let total = store.queue.compactMap { episodes[$0.episode.id]?.timeLeft }.reduce(0, +)
        NavigationStack {
            List {
                Section {
                    ForEach(Array(store.queue.enumerated()), id: \.element.episode.id) { index, item in
                        let episode = episodes[item.episode.id]
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(Theme.big(18))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 22)
                            ArtworkView(url: episode?.artwork, title: episode?.podcast?.title ?? item.episode.title, size: 42, radius: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.episode.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text([episode?.podcast?.title, episode?.timeLeft.map { TimeFormat.clock($0) }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
                        }
                        .listRowBackground(item.episode.id == player.nowPlaying?.episodeID ? Theme.highlight : Theme.surface)
                    }
                    .onMove { from, to in store.moveQueue(from: from, to: to) }
                    .onDelete { offsets in
                        let ids = offsets.map { store.queue[$0].episode.id }
                        for id in ids { store.removeFromQueue(id) }
                    }
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
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("UP NEXT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
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
    @State private var showingTranscript = false

    var body: some View {
        VStack(spacing: 8) {
            if let position = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) {
                row(icon: "list.number", title: "In Up Next · \(Self.ordinal(position + 1))", detail: "Change the order in Up Next") { EmptyView() }
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

/// When Up Next is empty: a few popular shows from Apple's UK chart to try,
/// each opening its preview page (Follow from there).
struct EmptyQueueSuggestions: View {
    @Environment(LibraryStore.self) private var store
    @State private var items: [DirectoryItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !items.isEmpty {
                Text("SOMETHING NEW TO TRY")
                    .font(Theme.mono(11, .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.muted)
                ForEach(items) { item in
                    NavigationLink {
                        ShowPreviewView(item: item)
                    } label: {
                        HStack(spacing: 12) {
                            ArtworkView(url: item.artworkURL, title: item.title, size: 46, radius: 10)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(item.artist ?? item.genre ?? "").font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.muted)
                        }
                        .padding(8)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            guard items.isEmpty else { return }
            let followed = Set(store.allShows.map(\.feedURL))
            let chart = (try? await FeedClient.topChart()) ?? []
            items = Array(chart.filter { $0.feedURL.map { !followed.contains($0.absoluteString) } ?? true }.prefix(5))
        }
    }
}
