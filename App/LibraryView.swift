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
    /// Most recently updated first by default (Paul, 11 Nov 2026); a new
    /// key so an older saved A–Z doesn't stick.
    @AppStorage("showsOrder") private var showsSort = ShowsSort.newestEpisode.rawValue

    static var newEpisodesQuery: FetchDescriptor<PodcastEpisode> {
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
    /// How long an episode stays in New (Paul, 12 Nov 2026): one week from
    /// when it came out. After that it's only on its show page (still
    /// unplayed, and still in Up Next if it's there).
    static let newFor: TimeInterval = 7 * 86_400

    private var newCards: [PodcastEpisode] { Self.pickNew(from: newEpisodes, limit: 12) }

    /// The query for the full New list (more than the card shows).
    static var newEpisodesQueryForList: FetchDescriptor<PodcastEpisode> {
        var descriptor = newEpisodesQuery
        descriptor.fetchLimit = 200
        return descriptor
    }

    static func pickNew(from newEpisodes: [PodcastEpisode], limit: Int) -> [PodcastEpisode] {
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
            if cards.count == limit { break }
        }
        return cards
    }


    private var caughtUp: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All caught up")
                .font(Theme.title(19))
                .foregroundStyle(Theme.ink)
            Text("No new episodes waiting. New ones land here as they come out.")
                .font(Theme.text(13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
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
                        // Deck 0 (Paul, 11 Nov 2026): New first, as one paper
                        // "front page" card (B on paper, artwork on the right
                        // so it never looks like Carry on), then Carry on as
                        // boxes, then Your shows by most recently updated.
                        let fresh = newCards
                        bigHeading("New", count: fresh.count, colour: Theme.ink)
                        if fresh.isEmpty {
                            caughtUp
                        } else {
                            NewPaper(episodes: fresh)
                                .padding(.horizontal, 12)
                        }

                        if !continuing.isEmpty {
                            bigHeading("Carry on", count: continuing.count, colour: Theme.ink)
                                .padding(.top, 6)
                            CarryOnBlock(episodes: continuing)
                                .padding(.horizontal, 12)
                        }

                        bigHeading("Your shows", count: shows.count, colour: Theme.ink) {
                            sortMenu
                        }
                        .padding(.top, 6)
                        subLabel("Sorted by " + sort.short)
                            .padding(.top, -8)
                        yourShows
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .onAppear { continuing = carryOn(playing: player.nowPlaying?.episodeID) }
            .onChange(of: player.nowPlaying?.episodeID) { _, id in continuing = carryOn(playing: id) }
            .tabTitle("Library")
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            // From the player's / an episode page's show name.
            .onChange(of: store.revealShow, initial: true) { _, show in
                guard let show else { return }
                path = NavigationPath()
                path.append(show)
            }
            // History and Stats sit level with the title, beside Add a show
            // (Paul, build 143: their own row left gaps above and below).
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink { HistoryView() } label: { Image(systemName: "clock.arrow.circlepath") }
                        .accessibilityLabel("History")
                    NavigationLink { StatsView() } label: { Image(systemName: "chart.bar") }
                        .accessibilityLabel("Stats")
                    Button { addingShow = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a show")
                }
            }
            .sheet(isPresented: $addingShow) { AddShowView() }
        }
    }

    private var sort: ShowsSort { ShowsSort(rawValue: showsSort) ?? .newestEpisode }

    /// Started episodes, the one playing first (it's shown as the dark
    /// playing card, like everywhere else).
    private func carryOn(playing: String?) -> [PodcastEpisode] {
        var list = store.continueListening(excluding: nil, limit: 3)
        if let index = list.firstIndex(where: { $0.episodeID == playing }), index > 0 {
            list.insert(list.remove(at: index), at: 0)
        }
        return list
    }

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
                Text("Recently updated first").tag(ShowsSort.newestEpisode)
                Text("Least recently updated first").tag(ShowsSort.oldestEpisode)
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

    /// A section's big heading (option 3): the name and count in Big
    /// Shoulders on a heavy rule, rule and count in the section's colour,
    /// with anything else (the sort key) on the right.
    private func bigHeading(_ title: String, count: Int, colour: Color) -> some View {
        bigHeading(title, count: count, colour: colour) { EmptyView() }
    }

    private func bigHeading<Trailing: View>(_ title: String, count: Int, colour: Color, @ViewBuilder trailing: () -> Trailing) -> some View {
        // Deck 0: a small mono label and count, like the deck's printing.
        HStack(alignment: .center, spacing: 8) {
            Text("\(title.uppercased()) · \(String(format: "%02d", count))")
                .font(Theme.mono(11, .medium))
                .tracking(1.4)
                .foregroundStyle(colour)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 32)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A small label inside a section ("TODAY", "SORTED BY NAME A–Z").
    private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.mono(9))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 16)
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

/// How Your shows is ordered (Paul, 10 Nov 2026), saved as "showsOrder"
/// (most recently updated first by default, Paul 11 Nov 2026).
enum ShowsSort: String {
    // A saved "followed" sort from before 11 Nov 2026 falls back to A–Z.
    case az, za, newestEpisode, oldestEpisode

    /// Shown beside YOUR SHOWS.
    var short: String {
        switch self {
        case .az: return "NAME A–Z"
        case .za: return "NAME Z–A"
        case .newestEpisode: return "RECENTLY UPDATED"
        case .oldestEpisode: return "LEAST RECENTLY UPDATED"
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

/// New as one paper "front page" card (Deck 0, Paul's pick B on paper, 11
/// Nov 2026): how many new episodes and how long they'd take, the newest
/// four as lines with the show's artwork on the right (tap a line for the
/// episode page, the artwork to play; swipe right for Up Next, left for
/// played), then Add all to Up Next and Mark all played. ALL › opens the
/// whole list, with both actions at the bottom by your thumb.
private struct NewPaper: View {
    @Environment(LibraryStore.self) private var store
    let episodes: [PodcastEpisode]

    var body: some View {
        let total = episodes.reduce(0.0) { $0 + ($1.timeLeft ?? $1.duration ?? 0) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(episodes.count == 1 ? "1 new episode" : "\(episodes.count) new episodes")
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 6)
                NavigationLink {
                    NewListView()
                } label: {
                    Text("\(TimeFormat.length(total)) · All ›".uppercased())
                        .font(Theme.mono(9, .medium))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All new episodes")
            }
            .padding(.bottom, 4)
            ForEach(Array(episodes.prefix(4).enumerated()), id: \.element.episodeID) { index, episode in
                NewPaperLine(episode: episode, first: index == 0)
            }
            NewActions(episodes: episodes)
                .padding(.top, 14)
        }
        // Roomier (Paul, 12 Nov 2026: it looked cramped next to the other
        // rows): more padding, and lines sized like Carry on and Up Next.
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .deckCard()
    }
}

/// Add all to Up Next (only those not already in it, oldest first) and
/// Mark all played, both with Undo.
private struct NewActions: View {
    @Environment(LibraryStore.self) private var store
    let episodes: [PodcastEpisode]

    var body: some View {
        // When every one is already queued it says so (Paul, build 141).
        let allQueued = episodes.allSatisfy { store.isQueued($0) }
        HStack(spacing: 8) {
            Button(action: addAll) {
                Text(allQueued ? "✓ All in Up Next" : "+ All to Up Next")
                    .modifier(OutlineKeyLabel())
            }
            .buttonStyle(.plain)
            .disabled(allQueued)
            Button(action: markAll) {
                Text("✓ Mark all played")
                    .modifier(OutlineKeyLabel())
            }
            .buttonStyle(.plain)
        }
    }

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

/// A quiet outlined key label (small mono capitals).
private struct OutlineKeyLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.mono(9.5, .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 38)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.controlBorder, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// One line of New: the title and a small line under it on the left, the
/// show's artwork on the right (tap to play).
private struct NewPaperLine: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    var first = false

    var body: some View {
        let inQueue = store.isQueued(episode)
        let isCurrent = player.nowPlaying?.episodeID == episode.episodeID
        var parts: [String] = [episode.showTitle, TimeFormat.ago(episode.published)]
        let length: TimeInterval = episode.timeLeft ?? episode.duration ?? 0
        if length > 0 { parts.append(TimeFormat.length(length)) }
        if isCurrent { parts.append("Playing") } else if inQueue { parts.append("In Up Next") }
        let line: String = parts.filter { !$0.isEmpty }.joined(separator: " · ").uppercased()
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isCurrent { PlayingBars(active: player.isPlaying) }
                    Text(episode.title)
                        .font(Theme.title(17))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(line)
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    EpisodeLights(episode: episode)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if isCurrent { player.togglePlayPause() } else { player.play(episode) }
            } label: {
                Stamp(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCurrent && player.isPlaying ? "Pause" : "Play")
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            if !first { Theme.hairline.frame(height: 1) }
        }
        // Solid behind the line, so a swipe slides it over its action.
        .background(Theme.surface)
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

/// Every new episode (the last week), with Add all and Mark all
/// played at the bottom, in thumb reach.
private struct NewListView: View {
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]

    private var episodes: [PodcastEpisode] { LibraryView.pickNew(from: unplayed, limit: 60) }

    var body: some View {
        let list = episodes
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.episodeID) { index, episode in
                    NewPaperLine(episode: episode, first: index == 0)
                }
                if list.isEmpty {
                    Text("All caught up")
                        .font(Theme.title(18))
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .deckCard()
            .padding(12)
            Text("Swipe right for Up Next, left for played".uppercased())
                .font(Theme.mono(8.5))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if !list.isEmpty {
                NewActions(episodes: list)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.plate)
            }
        }
        .navigationTitle("New · last week")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Carry on (Deck 0): boxes like Up Next, artwork on the left, how far
/// through as a thin line; the episode playing is the dark playing card.
private struct CarryOnBlock: View {
    @Environment(PlayerModel.self) private var player
    let episodes: [PodcastEpisode]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(episodes) { episode in
                let isCurrent = player.nowPlaying?.episodeID == episode.episodeID
                Button {
                    if isCurrent { player.togglePlayPause() } else { player.play(episode) }
                } label: {
                    CarryOnRow(episode: episode, isCurrent: isCurrent)
                }
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

private struct CarryOnRow: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let isCurrent: Bool

    private var carryOnDetail: String {
        let parts: [String] = [episode.showTitle, episode.carryOnLeft]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ").uppercased()
    }

    var body: some View {
        let colour = Poster.colour(episode.showArtwork, title: episode.showTitle)
        let content = HStack(spacing: 10) {
            // A play / pause icon over the artwork shows that tapping the
            // card starts and stops it (Paul, 12 Nov 2026).
            Stamp(url: episode.artwork, title: episode.showTitle, size: 40)
                .overlay {
                    Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isCurrent { PlayingBars(active: player.isPlaying) }
                    Text(episode.title)
                        .font(Theme.title(16))
                        .foregroundStyle(isCurrent ? Poster.paper : Theme.ink)
                        .lineLimit(1)
                }
                Text(carryOnDetail)
                    .font(Theme.mono(8.5))
                    .foregroundStyle(isCurrent ? Poster.paper.opacity(0.7) : Theme.muted)
                    .lineLimit(1)
                Capsule().fill(isCurrent ? Poster.paper.opacity(0.25) : Theme.hairline)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule().fill(isCurrent ? Poster.paper : colour)
                                .frame(width: geometry.size.width * episode.carryOnFraction)
                        }
                    }
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            EpisodeLights(episode: episode, onDark: isCurrent)
        }
        .contentShape(Rectangle())
        Group {
            if isCurrent {
                content.playingCard()
            } else {
                content.posterCard(colour)
            }
        }
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(Int(episode.carryOnFraction * 100)) percent played")
        .accessibilityHint(isCurrent ? "Plays or pauses" : "Plays from where you stopped")
    }
}

/// Your shows as boxes (Deck 0): the band in the show's colour, artwork on
/// the left, the name, where its new episodes go and when it last had one,
/// and a NEW pill in its colour.
private struct ShowPosterRow: View {
    let show: Podcast

    private var mode: String {
        switch show.autoAdd {
        case .top: return "Top"
        case .bottom: return "Btm"
        case .off: return "Off"
        }
    }

    /// "TOP · UPDATED 2H AGO".
    private func detail(latest: Date?) -> String {
        var parts: [String] = [mode]
        if let latest { parts.append("Updated " + TimeFormat.ago(latest)) }
        return parts.joined(separator: " · ").uppercased()
    }

    var body: some View {
        let colour: Color = Poster.colour(show.artworkURL, title: show.title)
        let unplayed: Int = show.episodes.reduce(0) { $0 + ($1.played ? 0 : 1) }
        let latest: Date? = show.episodes.map(\.published).max()
        HStack(spacing: 10) {
            Stamp(url: show.artworkURL, title: show.title, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(show.title)
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail(latest: latest))
                    .font(Theme.mono(8.5))
                    .tracking(0.5)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if unplayed > 0 {
                Text("\(unplayed) NEW")
                    .font(Theme.mono(8.5, .bold))
                    .foregroundStyle(Poster.paper)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(colour, in: Capsule())
                    .fixedSize()
            }
        }
        .showCard(show.artworkURL, title: show.title)
        .contentShape(Rectangle())
    }
}
