import SwiftUI
import SwiftData
import PodcastCore

struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @State private var continuing: [PodcastEpisode] = []
    @Query(sort: \Podcast.title) private var shows: [Podcast]
    @Query(LibraryView.newEpisodesQuery) private var newEpisodes: [PodcastEpisode]
    @State private var addingShow = false
    @State private var path = NavigationPath()
    @AppStorage("showsSort") private var showsSort = ShowsSort.az.rawValue

    private static var newEpisodesQuery: FetchDescriptor<PodcastEpisode> {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        // More than are shown: `newCards` leaves some out.
        descriptor.fetchLimit = 60
        return descriptor
    }

    /// The New Episodes cards: what came out since Paul followed each show,
    /// plus that show's newest one. Following a show with a long back
    /// catalogue filled the carousel with its old episodes (Paul, 8 Nov
    /// 2026: cap it at the latest one).
    /// How long an episode stays in New (Paul, 11 Nov 2026): two weeks from
    /// when it came out. After that it's only on its show page (still
    /// unplayed, and still in Up Next if it's there).
    static let newFor: TimeInterval = 14 * 86_400

    private var newCards: [PodcastEpisode] {
        var seen = Set<String>()
        var cards: [PodcastEpisode] = []
        let cutoff = Date().addingTimeInterval(-Self.newFor)
        for episode in newEpisodes {
            // Newest first, so everything after this is older too.
            if episode.published < cutoff { break }
            guard let show = episode.podcast else { continue }
            let firstForShow = seen.insert(show.feedURL).inserted
            if firstForShow || episode.published >= show.followedAt {
                cards.append(episode)
            }
            if cards.count == 12 { break }
        }
        return cards
    }


    private var caughtUp: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All caught up")
                .font(Theme.big(26))
                .foregroundStyle(Theme.ink)
            Text("No new episodes waiting. New ones land here as they come out.")
                .font(Theme.text(13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // Lazy: rows are only made as they scroll into view.
                LazyVStack(alignment: .leading, spacing: 10) {
                    if shows.isEmpty {
                        emptyState
                    } else {
                        // HISTORY · STATS as small keys on the right.
                        HStack(spacing: 6) {
                            Spacer()
                            NavigationLink { HistoryView() } label: { libraryKey("HISTORY", icon: "clock.arrow.circlepath") }
                            NavigationLink { StatsView() } label: { libraryKey("STATS", icon: "chart.bar") }
                        }
                        .buttonStyle(KeyButtonStyle(kind: .plain, radius: 8))
                        .padding(.horizontal, 12)

                        // Option 3 (Paul, 11 Nov 2026): each section opens
                        // with a big heading on a heavy rule in its own colour
                        // (olive new, amber carry on, ink shows), and the rows
                        // get quieter down the page: full poster rows for new,
                        // slim lines with a progress ring for started, a plain
                        // list for shows.
                        // New as one "morning paper" card, Carry on as one
                        // big card then small rows, Your shows as poster
                        // rows (Paul, 11 Nov 2026: N4, C2, S3 on
                        // https://claude.ai/artifact/SbZUnVKhQJPYuS8Hv4hZKw).
                        let fresh = newCards
                        bigHeading("New", count: fresh.count, colour: Theme.accentFill)
                        if fresh.isEmpty {
                            caughtUp
                        } else {
                            NewPaper(episodes: fresh)
                                .padding(.horizontal, 12)
                        }

                        if !continuing.isEmpty {
                            bigHeading("Carry on", count: continuing.count, colour: Theme.adMarker)
                                .padding(.top, 8)
                            CarryOnBlock(episodes: continuing)
                                .padding(.horizontal, 12)
                        }

                        bigHeading("Your shows", count: shows.count, colour: Poster.rust) {
                            sortMenu
                        }
                        .padding(.top, 8)
                        subLabel("Sorted by " + sort.short)
                            .padding(.top, -6)
                        yourShows
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .onAppear { continuing = store.continueListening(excluding: player.nowPlaying?.episodeID, limit: 3) }
            .onChange(of: player.nowPlaying?.episodeID) { _, id in continuing = store.continueListening(excluding: id, limit: 3) }
            .tabTitle("Library")
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            // From the player's / an episode page's show name.
            .onChange(of: store.revealShow, initial: true) { _, show in
                guard let show else { return }
                path = NavigationPath()
                path.append(show)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingShow = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a show")
                }
            }
            .sheet(isPresented: $addingShow) { AddShowView() }
        }
    }

    private var sort: ShowsSort { ShowsSort(rawValue: showsSort) ?? .az }

    /// Your shows in Paul's chosen order (sort key in the section header).
    private var sortedShows: [Podcast] {
        switch sort {
        case .az:
            return shows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .za:
            return shows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        case .newestEpisode, .oldestEpisode:
            var latest: [PersistentIdentifier: Date] = [:]
            for show in shows {
                latest[show.persistentModelID] = show.episodes.map(\.published).max() ?? .distantPast
            }
            let newestFirst = sort == .newestEpisode
            return shows.sorted { a, b in
                let first = latest[a.persistentModelID] ?? .distantPast
                let second = latest[b.persistentModelID] ?? .distantPast
                return newestFirst ? first > second : first < second
            }
        }
    }

    /// Small cards with the description, in rounded paper cards like every
    /// other list. The only layout since Paul dropped the large artwork
    /// tiles (11 Nov 2026; "description only" went on 10 Nov).
    private var yourShows: some View {
        let ordered = sortedShows
        return LazyVStack(spacing: 8) {
            ForEach(ordered) { show in
                NavigationLink(value: show) {
                    ShowPosterRow(show: show)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    /// Sections sit straight in the menu (inside a Picker iOS dropped their
    /// headings, so "Newest first" showed twice with nothing to tell the
    /// two apart; Paul, build 136), and every choice says what it sorts by.
    private var sortMenu: some View {
        // iOS's own pickers inside the menu: the tick sits in its own
        // column, so the chosen line's words don't move (Paul, after build
        // 140: a tick pushed "Newest episode first" to the right). Sorting
        // by when you followed is gone (Paul, 11 Nov 2026).
        Menu {
            Picker("Name", selection: sortBinding) {
                Text("Name, A to Z").tag(ShowsSort.az)
                Text("Name, Z to A").tag(ShowsSort.za)
            }
            .pickerStyle(.inline)
            Picker("Latest episode", selection: sortBinding) {
                Text("Newest episode first").tag(ShowsSort.newestEpisode)
                Text("Oldest episode first").tag(ShowsSort.oldestEpisode)
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort shows")
        .accessibilityValue(sort.short)
    }

    private var sortBinding: Binding<ShowsSort> {
        Binding(get: { sort }, set: { showsSort = $0.rawValue })
    }

    private func libraryKey(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(title).font(Theme.mono(10, .bold)).tracking(0.8)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
    }

    /// A section's big heading (option 3): the name and count in Big
    /// Shoulders on a heavy rule, rule and count in the section's colour,
    /// with anything else (the sort key) on the right.
    private func bigHeading(_ title: String, count: Int, colour: Color) -> some View {
        bigHeading(title, count: count, colour: colour) { EmptyView() }
    }

    private func bigHeading<Trailing: View>(_ title: String, count: Int, colour: Color, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(title)
                .font(Theme.big(30))
                .foregroundStyle(Theme.ink)
            Text("\(count)")
                .font(Theme.big(30))
                .foregroundStyle(colour)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) { colour.frame(height: 3) }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A small label inside a section ("TODAY", "SORTED BY NAME A–Z").
    private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.mono(9))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 20)
            .padding(.top, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NO SHOWS YET")
                .font(Theme.mono(15, .bold))
                .foregroundStyle(Theme.ink)
            Text("Search Apple's podcast directory by name, or paste a link from Apple Podcasts or a show's RSS feed.")
                .foregroundStyle(Theme.muted)
            Button { addingShow = true } label: {
                Text("+ ADD A SHOW").font(Theme.mono(13, .bold)).padding(.horizontal, 18).frame(minHeight: 48)
            }
            .buttonStyle(.accentKey)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// Where new episodes go (TOP / BTM / OFF) and how many are unplayed, on
/// each show in Your shows: "TOP · 3 NEW".
enum ShowBadges {
    static func text(_ show: Podcast) -> String {
        let tag: String = switch show.autoAdd {
        case .top: "Top"
        case .bottom: "Btm"
        case .off: "Off"
        }
        return "\(tag) · \(show.episodes.filter { !$0.played }.count) new"
    }
}

/// How Your shows is ordered (Paul, 10 Nov 2026), saved as "showsSort".
enum ShowsSort: String {
    // A saved "followed" sort from before 11 Nov 2026 falls back to A–Z.
    case az, za, newestEpisode, oldestEpisode

    /// Shown beside YOUR SHOWS.
    var short: String {
        switch self {
        case .az: return "NAME A–Z"
        case .za: return "NAME Z–A"
        case .newestEpisode: return "NEWEST EPISODE"
        case .oldestEpisode: return "OLDEST EPISODE"
        }
    }
}

/// Play next / Play last / played actions, shared by cards and lists.
struct EpisodeMenuItems: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode

    var body: some View {
        Button("Play", systemImage: "play") { player.play(episode) }
        Button("Episode notes", systemImage: "doc.text") { store.notesEpisode = episode }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { store.playNext(episode) }
        Button("Play last", systemImage: "text.line.last.and.arrowtriangle.forward") { store.playLast(episode) }
        if downloads.progress[episode.episodeID] != nil {
            Button("Stop download", systemImage: "xmark.circle") { store.removeDownload(episode) }
        } else if episode.downloadFile != nil {
            Button("Remove download", systemImage: "trash", role: .destructive) { store.removeDownload(episode) }
        } else {
            Button("Download", systemImage: "arrow.down.circle") { downloads.download(episode) }
        }
        if transcripts.isQueued(episode) {
            Button("Stop transcribing", systemImage: "stop.circle") { transcripts.stop(episode) }
        } else if transcripts.canTranscribeNow(episode) {
            Button("Transcribe now", systemImage: "text.quote") { transcripts.transcribeNow(episode) }
        }
        if episode.played {
            Button("Mark as unplayed", systemImage: "circle") { store.markUnplayed(episode) }
        } else {
            Button("Mark as played", systemImage: "checkmark.circle") {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
        }
    }
}

/// Download / progress / downloaded, for the New Episodes cards.
struct DownloadButton: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    var tint: Color = Theme.ink

    var body: some View {
        Group {
            if let fraction = downloads.progress[episode.episodeID] {
                Button { store.removeDownload(episode) } label: {
                    ZStack {
                        Circle().stroke(tint.opacity(0.3), lineWidth: 2)
                        Circle().trim(from: 0, to: max(0.03, fraction))
                            .stroke(tint == Theme.ink ? Theme.accentFill : tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill").font(.system(size: 9, weight: .bold))
                    }
                    .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Stop download, \(Int(fraction * 100)) percent done")
            } else if episode.downloadFile != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(tint == Theme.ink ? Theme.accentText : tint)
                    .accessibilityLabel("Downloaded")
            } else {
                Button { downloads.download(episode) } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .accessibilityLabel("Download")
            }
        }
        .font(.title3)
        .foregroundStyle(tint)
        .frame(width: 44, height: 44)
    }
}

/// New as one printed card, the "morning paper" (Paul's pick N4, 11 Nov
/// 2026): how many new episodes and how long they'd take, one line each
/// (tap for the episode page, the stamp to play, swipe right for Up Next
/// and left for played, as before), then Add all to Up Next and Mark all
/// played. Printed in the colour of what's playing, or the dark display
/// colour when nothing is.
private struct NewPaper: View {
    @Environment(LibraryStore.self) private var store
    let episodes: [PodcastEpisode]

    var body: some View {
        let colour = AccentColour.shared.colour ?? Theme.display
        let total = episodes.reduce(0.0) { $0 + ($1.timeLeft ?? $1.duration ?? 0) }
        VStack(alignment: .leading, spacing: 0) {
            Text("Last two weeks · \(TimeFormat.length(total)) to listen".uppercased())
                .font(Theme.mono(9))
                .tracking(0.8)
                .foregroundStyle(Poster.paper.opacity(0.8))
            Text(episodes.count == 1 ? "1 new episode" : "\(episodes.count) new episodes")
                .font(Theme.big(26))
                .foregroundStyle(Poster.paper)
                .padding(.top, 2)
                .padding(.bottom, 8)
            ForEach(episodes) { episode in
                NewPaperLine(episode: episode, colour: colour)
            }
            HStack(spacing: 8) {
                // When every one is already queued it says so, in the same
                // light-on-dark style as Mark all played (Paul, build 141:
                // the dimmed paper key was invisible on the card).
                let allQueued = episodes.allSatisfy { store.isQueued($0) }
                Button(action: addAll) {
                    Text(allQueued ? "✓ ALL IN UP NEXT" : "ADD ALL TO UP NEXT")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(allQueued ? Poster.paper.opacity(0.85) : colour)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(allQueued ? AnyShapeStyle(.black.opacity(0.25)) : AnyShapeStyle(Poster.paper), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(allQueued)
                Button(action: markAll) {
                    Text("MARK ALL PLAYED")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(Poster.paper)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(14)
        .background { PrintedArtwork(url: nil, colour: colour, strength: 0) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Only the ones not already in Up Next, oldest first.
    private func addAll() {
        let missing = episodes.filter { !store.isQueued($0) }
        guard !missing.isEmpty else { return }
        store.undoable("Added \(missing.count) to Up Next", episodes: []) {
            store.commit(QueueEngine.playLast(missing.map(\.queueEpisode), in: store.queue, settings: store.queueSettings))
        }
    }

    private func markAll() {
        let list = episodes
        store.undoable("Marked \(list.count) played", episodes: list) { store.markPlayed(list) }
    }
}

/// One line of the New card.
private struct NewPaperLine: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let colour: Color

    var body: some View {
        let inQueue = store.isQueued(episode)
        let isCurrent = player.nowPlaying?.episodeID == episode.episodeID
        var parts = [episode.showTitle, TimeFormat.ago(episode.published)]
        if isCurrent { parts.append("Playing") } else if inQueue { parts.append("In Up Next") }
        return HStack(spacing: 10) {
            Button {
                if isCurrent { player.togglePlayPause() } else { player.play(episode) }
            } label: {
                Stamp(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 34)
                    .overlay {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Poster.paper)
                            .frame(width: 20, height: 20)
                            .background(.black.opacity(0.45), in: Circle())
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCurrent && player.isPlaying ? "Pause" : "Play")
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.title(16))
                    .foregroundStyle(Poster.paper)
                    .lineLimit(2)
                Text(parts.filter { !$0.isEmpty }.joined(separator: " · ").uppercased())
                    .font(Theme.mono(8.5))
                    .foregroundStyle(Poster.paper.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let length = episode.timeLeft ?? episode.duration, length > 0 {
                Text(TimeFormat.length(length).uppercased())
                    .font(Theme.mono(9))
                    .foregroundStyle(Poster.paper.opacity(0.8))
                    .fixedSize()
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Poster.paper.opacity(0.18).frame(height: 1) }
        // Solid behind the line, so a swipe slides it over its action.
        .background { PrintedArtwork(url: nil, colour: colour, strength: 0) }
        .contentShape(Rectangle())
        .onTapGesture { store.notesEpisode = episode }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the episode page")
        .contextMenu { EpisodeMenuItems(episode: episode) }
        .posterSwipe(
            leading: inQueue ? nil : PosterSwipeAction(title: "Up next", icon: "plus", colour: Poster.swipeAdd, action: { store.playLast(episode) }),
            trailing: PosterSwipeAction(title: "Played", icon: "checkmark", colour: Poster.swipePlayed) {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            })
    }
}

/// Carry on (Paul's pick C2, 11 Nov 2026): the episode you're most likely
/// to go back to as a printed card in its show's colour with a big play
/// key and its progress, the others as small rows with a thin bar.
private struct CarryOnBlock: View {
    @Environment(PlayerModel.self) private var player
    let episodes: [PodcastEpisode]

    var body: some View {
        VStack(spacing: 10) {
            if let first = episodes.first {
                Button { player.play(first) } label: { CarryOnCard(episode: first) }
                    .buttonStyle(.plain)
                    .contextMenu { EpisodeMenuItems(episode: first) }
            }
            ForEach(episodes.dropFirst()) { episode in
                Button { player.play(episode) } label: { CarryOnSmall(episode: episode) }
                    .buttonStyle(.plain)
                    .contextMenu { EpisodeMenuItems(episode: episode) }
            }
        }
    }
}

private extension PodcastEpisode {
    var carryOnFraction: Double {
        guard let duration, duration > 0 else { return 0 }
        return min(1, max(0.02, position / duration))
    }
    var carryOnLeft: String {
        timeLeft.map { "\(TimeFormat.length($0)) left" } ?? ""
    }
}

private struct CarryOnCard: View {
    let episode: PodcastEpisode

    var body: some View {
        let colour = Poster.colour(episode.showArtwork, title: episode.showTitle)
        HStack(spacing: 12) {
            Stamp(url: episode.artwork, title: episode.showTitle, size: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text([episode.showTitle, episode.carryOnLeft].filter { !$0.isEmpty }.joined(separator: " · ").uppercased())
                    .font(Theme.mono(9))
                    .foregroundStyle(Poster.paper.opacity(0.8))
                    .lineLimit(1)
                Text(episode.title)
                    .font(Theme.title(19))
                    .foregroundStyle(Poster.paper)
                    .lineLimit(2)
                Capsule().fill(Poster.paper.opacity(0.3))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule().fill(Poster.paper).frame(width: geometry.size.width * episode.carryOnFraction)
                        }
                    }
                    .padding(.top, 5)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(colour)
                .frame(width: 44, height: 44)
                .background(Poster.paper, in: Circle())
        }
        .padding(12)
        .background { PrintedArtwork(url: episode.artwork, colour: colour, strength: 0.45) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(Int(episode.carryOnFraction * 100)) percent played")
        .accessibilityHint("Plays from where you stopped")
    }
}

private struct CarryOnSmall: View {
    let episode: PodcastEpisode

    var body: some View {
        let colour = Poster.colour(episode.showArtwork, title: episode.showTitle)
        HStack(spacing: 10) {
            Stamp(url: episode.artwork, title: episode.showTitle, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(Theme.text(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Capsule().fill(Theme.hairline)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule().fill(colour).frame(width: geometry.size.width * episode.carryOnFraction)
                        }
                    }
            }
            Text(episode.carryOnLeft.uppercased())
                .font(Theme.mono(9))
                .foregroundStyle(Theme.muted)
                .fixedSize()
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(Int(episode.carryOnFraction * 100)) percent played")
        .accessibilityHint("Plays from where you stopped")
    }
}

/// Your shows as poster rows like New (Paul's pick S3, 11 Nov 2026): the
/// show's colour strip, where its new episodes go, its name in the title
/// font, a NEW pill in its colour and its stamp.
private struct ShowPosterRow: View {
    let show: Podcast

    private var mode: String {
        switch show.autoAdd {
        case .top: return "Top of Up Next"
        case .bottom: return "Bottom of Up Next"
        case .off: return "Not adding"
        }
    }

    var body: some View {
        let colour = Poster.colour(show.artworkURL, title: show.title)
        let unplayed = show.episodes.reduce(0) { $0 + ($1.played ? 0 : 1) }
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.uppercased())
                    .font(Theme.mono(8.5))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                Text(show.title)
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if unplayed > 0 {
                Text("\(unplayed) NEW")
                    .font(Theme.mono(8.5, .bold))
                    .foregroundStyle(Poster.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(colour, in: Capsule())
                    .fixedSize()
            }
            Stamp(url: show.artworkURL, title: show.title, size: 40)
        }
        .showCard(show.artworkURL, title: show.title)
        .contentShape(Rectangle())
    }
}
