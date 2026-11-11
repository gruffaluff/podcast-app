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
        let playing = store.queue.firstIndex { $0.episode.id == player.nowPlaying?.episodeID }
        // When each one starts at the current speed (Deck 0): the list reads
        // from the top, the first (or the one playing) is now.
        let lengths: [TimeInterval] = Self.lengths(of: store.queue, episodes: episodes)
        let starts: [Date] = UpNextTimes.starts(lengths: lengths, speed: player.speed)
        let nowIndex: Int = playing ?? 0

        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    // A plain row, not a section header: plain lists pin
                    // headers to the top while scrolling.
                    header(episodes: episodes)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                    ForEach(Array(store.queue.enumerated()), id: \.element.episode.id) { index, item in
                        if let episode = episodes[item.episode.id] {
                            queueRow(index: index, item: item, episode: episode, settings: settings, playing: playing,
                                     start: index == nowIndex ? "NOW" : UpNextTimes.clock(starts[index]))
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
                                .showRow(item.artworkURL, title: item.title)
                            }
                        }
                    }
                }
                .listSectionSeparator(.hidden)

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
            .onChange(of: editing) { if editing { openRow = nil } }
            // Arriving from an episode page's "In Up Next" row.
            .onChange(of: store.revealInUpNext, initial: true) { _, id in
                guard let id else { return }
                editing = false
                openRow = id
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                    store.revealInUpNext = nil
                }
            }
            }
            // Full-width banded rows (Paul, after build 127): in a rounded
            // inset panel the lifted row kept the panel's corner mask (white
            // corners) and the band colour got lost against the sand at the
            // panel's edges.
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .task(id: store.queue.isEmpty) {
                if store.queue.isEmpty, suggestions.isEmpty {
                    suggestions = await SuggestionRow.load(store: store)
                }
            }
            .tabTitle("Up Next")
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
    private func queueRow(index: Int, item: QueueItem, episode: PodcastEpisode, settings: QueueSettings, playing: Int?, start: String) -> some View {
        let isOpen = openRow == episode.episodeID
        return VStack(spacing: 8) {
            // Tap a row for its keys; the artwork plays (Paul, A + C).
            QueueRow(number: index + 1, item: item, episode: episode, settings: settings, isPlaying: player.nowPlaying?.episodeID == episode.episodeID, start: start) {
                player.play(episode)
            }
            // While reordering, taps do nothing (rows growing mid-drag jumped).
            .onTapGesture { if !editing { toggleRow(episode.episodeID) } }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isOpen ? "Hides the keys" : "Shows play, notes, download and more")
            if isOpen {
                UpNextRowKeys(episode: episode, onColour: index == playing) { openRow = nil }
                    .padding(.bottom, 4)
            }
        }
        // Each row is a box with a band of the show's colour (Deck 0, Paul
        // 11 Nov 2026); the episode that's on is a dark card. The cell
        // behind is sand, so the row iOS lifts to drag has sand corners.
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(QueueCard(episode: episode, isPlaying: index == playing))
        // Full-row swipes: right to the top of Up Next, left played. Notes
        // and Remove are in the row's keys (tap the row).
        .posterSwipe(
            leading: PosterSwipeAction(title: "To top", icon: "arrow.up.to.line", colour: Poster.swipeAdd) { store.playNext(episode) },
            trailing: PosterSwipeAction(title: "Played", icon: "checkmark", colour: Poster.swipePlayed) {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            },
            enabled: !editing)
        .deckCardRow()
    }


    /// How long each Up Next episode has left (its length if not started).
    private static func lengths(of queue: [QueueItem], episodes: [String: PodcastEpisode]) -> [TimeInterval] {
        var result: [TimeInterval] = []
        for item in queue {
            let episode: PodcastEpisode? = episodes[item.episode.id]
            result.append(episode?.timeLeft ?? episode?.duration ?? 0)
        }
        return result
    }

    private func toggleRow(_ id: String) {
        // No animation: List resizing rows animates jerkily.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { openRow = openRow == id ? nil : id }
    }

    private func header(episodes: [String: PodcastEpisode]) -> some View {
        let lengths: [TimeInterval] = Self.lengths(of: store.queue, episodes: episodes)
        var counts = "\(store.queue.count) EPISODE\(store.queue.count == 1 ? "" : "S")"
        if lengths.reduce(0, +) > 0 {
            counts += " · DONE BY \(UpNextTimes.clock(UpNextTimes.doneBy(lengths: lengths, speed: player.speed)))"
        }

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
    @Environment(PlayerModel.self) private var player
    let number: Int
    let item: QueueItem
    let episode: PodcastEpisode
    let settings: QueueSettings
    let isPlaying: Bool
    /// When it starts at the current speed ("NOW" for the first).
    let start: String
    /// Tapping the artwork plays straight away.
    let play: () -> Void

    var body: some View {
        let show = episode.podcast?.title ?? ""
        let time = episode.timeLeft.map { TimeFormat.clock($0) } ?? "--:--"
        let quiet: Color = isPlaying ? Poster.paper.opacity(0.7) : Theme.muted
        // Deck 0: artwork on the left (tap to play), the title, a small line
        // under it, and on the right when it starts plus DL / TX.
        HStack(alignment: .center, spacing: 10) {
            Button(action: play) {
                Stamp(url: episode.artwork, title: show.isEmpty ? episode.title : show, size: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Playing" : "Play")
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isPlaying { PlayingBars(active: player.isPlaying) }
                    Text(episode.title)
                        .font(Theme.title(17))
                        .foregroundStyle(isPlaying ? Poster.paper : Theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(([show] + [tag].compactMap { $0 } + [time + (isPlaying ? " left" : "")]).filter { !$0.isEmpty }.joined(separator: " · ").uppercased())
                    .font(Theme.mono(8.5))
                    .tracking(0.5)
                    .foregroundStyle(quiet)
                    .lineLimit(1)
                // When it came out (Paul, 9 Nov 2026), then downloading /
                // transcribing.
                Text(([Self.published(episode.published)] + [status].compactMap { $0 }).joined(separator: " · ").uppercased())
                    .font(Theme.mono(8.5))
                    .foregroundStyle(quiet)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text(start)
                    .font(Theme.mono(10, .medium))
                    .monospacedDigit()
                    .foregroundStyle(isPlaying ? Poster.paper : Theme.ink)
                EpisodeLights(episode: episode, onDark: isPlaying)
            }
            .fixedSize()
        }
        .contentShape(Rectangle())
    }

    /// "9 Nov", or "9 Nov 2025" for an earlier year.
    static func published(_ date: Date) -> String {
        let thisYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return (thisYear ? dayMonth : dayMonthYear).string(from: date)
    }

    // Made once: a formatter per row per redraw was wasteful.
    private static let dayMonth = formatter("d MMM")
    private static let dayMonthYear = formatter("d MMM yyyy")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = format
        return formatter
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
    /// On the playing block's printed colour rather than a paper row.
    var onColour = false
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
            // Like the download key: how far it has got, tap to stop.
            let label = transcripts.progress[episode.episodeID].map { "TX \(Int($0 * 100))%" } ?? "STOP TX"
            key(label, icon: "stop.circle") { transcripts.stop(episode) }
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
        .buttonStyle(RowKeyStyle(main: dark, onColour: onColour))
    }
}

/// Keys under an opened Up Next row (Paul, build 139: they were lost). On a
/// paper row: ink main key, sand others. On the playing block's printed
/// colour: paper main key, dark see-through others.
private struct RowKeyStyle: ButtonStyle {
    let main: Bool
    let onColour: Bool

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = onColour ? (main ? Poster.paper : Color.black.opacity(0.32)) : (main ? Theme.ink : Theme.background)
        let text: Color = onColour ? (main ? Color.black.opacity(0.85) : Poster.paper) : (main ? Theme.surface : Theme.ink)
        return configuration.label
            .foregroundStyle(text)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// An Up Next card: a box with a band of the show's colour, or for the
/// episode that's on, the dark playing card with a line showing how far
/// through it is.
struct QueueCard: ViewModifier {
    let episode: PodcastEpisode
    let isPlaying: Bool

    func body(content: Content) -> some View {
        let showArt = episode.podcast?.artworkURL ?? episode.artwork
        let colour = Poster.colour(showArt, title: episode.podcast?.title ?? episode.title)
        Group {
            if isPlaying {
                VStack(alignment: .leading, spacing: 10) {
                    content
                    // Its own view: only the line redraws as the episode plays.
                    PlayingProgress(episodeID: episode.episodeID)
                }
                .playingCard()
            } else {
                content.posterCard(colour)
            }
        }
        .task(id: showArt) { await ArtworkColors.shared.load(showArt) }
    }
}

/// How far through the episode that's on, as a paper line.
private struct PlayingProgress: View {
    @Environment(PlayerModel.self) private var player
    let episodeID: String

    var body: some View {
        let fraction = player.nowPlaying?.episodeID == episodeID && player.duration > 0
            ? min(1, player.currentTime / player.duration) : 0
        GeometryReader { geometry in
            Capsule().fill(Poster.paper.opacity(0.3))
                .overlay(alignment: .leading) {
                    Capsule().fill(Poster.paper).frame(width: geometry.size.width * fraction)
                }
        }
        .frame(height: 4)
    }
}
