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
    private var newCards: [PodcastEpisode] {
        var seen = Set<String>()
        var cards: [PodcastEpisode] = []
        for episode in newEpisodes {
            guard let show = episode.podcast else { continue }
            let firstForShow = seen.insert(show.feedURL).inserted
            if firstForShow || episode.published >= show.followedAt {
                cards.append(episode)
            }
            if cards.count == 12 { break }
        }
        return cards
    }


    /// The inbox: new episodes by when they came out.
    private var inboxGroups: [(title: String, episodes: [PodcastEpisode])] {
        let calendar = Calendar.current
        let now = Date()
        var today: [PodcastEpisode] = [], yesterday: [PodcastEpisode] = [], week: [PodcastEpisode] = [], earlier: [PodcastEpisode] = []
        for episode in newCards {
            if calendar.isDateInToday(episode.published) { today.append(episode) }
            else if calendar.isDateInYesterday(episode.published) { yesterday.append(episode) }
            else if now.timeIntervalSince(episode.published) < 7 * 86_400 { week.append(episode) }
            else { earlier.append(episode) }
        }
        return [("TODAY", today), ("YESTERDAY", yesterday), ("THIS WEEK", week), ("EARLIER", earlier)]
            .filter { !$0.1.isEmpty }
            .map { (title: $0.0, episodes: $0.1) }
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
                        let groups = inboxGroups
                        bigHeading("New", count: groups.reduce(0) { $0 + $1.episodes.count }, colour: Theme.accentFill)
                        if groups.isEmpty {
                            caughtUp
                        }
                        ForEach(groups, id: \.title) { group in
                            if groups.count > 1 {
                                subLabel(group.title)
                            }
                            VStack(spacing: 8) {
                                ForEach(group.episodes) { episode in
                                    InboxRow(episode: episode)
                                }
                            }
                            .padding(.horizontal, 12)
                        }

                        if !continuing.isEmpty {
                            bigHeading("Carry on", count: continuing.count, colour: Theme.adMarker)
                                .padding(.top, 8)
                            VStack(spacing: 0) {
                                ForEach(continuing) { episode in
                                    Button { player.play(episode) } label: {
                                        CarryOnLine(episode: episode)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { EpisodeMenuItems(episode: episode) }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        bigHeading("Your shows", count: shows.count, colour: Theme.ink) {
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
        case .followedNewest:
            return shows.sorted { $0.followedAt > $1.followedAt }
        case .followedOldest:
            return shows.sorted { $0.followedAt < $1.followedAt }
        }
    }

    /// Small cards with the description, in rounded paper cards like every
    /// other list. The only layout since Paul dropped the large artwork
    /// tiles (11 Nov 2026; "description only" went on 10 Nov).
    private var yourShows: some View {
        let ordered = sortedShows
        return LazyVStack(spacing: 0) {
            ForEach(ordered) { show in
                NavigationLink(value: show) {
                    // A plain list line: the quietest of the three sections.
                    HStack(spacing: 10) {
                        Stamp(url: show.artworkURL, title: show.title, size: 30)
                        Text(show.title)
                            .font(Theme.text(15, .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(ShowBadges.text(show).uppercased())
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Sections sit straight in the menu (inside a Picker iOS dropped their
    /// headings, so "Newest first" showed twice with nothing to tell the
    /// two apart; Paul, build 136), and every choice says what it sorts by.
    private var sortMenu: some View {
        Menu {
            Section("Name") {
                sortOption(.az, "Name, A to Z")
                sortOption(.za, "Name, Z to A")
            }
            Section("Latest episode") {
                sortOption(.newestEpisode, "Newest episode first")
                sortOption(.oldestEpisode, "Oldest episode first")
            }
            Section("When you followed") {
                sortOption(.followedNewest, "Recently followed first")
                sortOption(.followedOldest, "Followed longest ago first")
            }
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

    private func sortOption(_ option: ShowsSort, _ title: String) -> some View {
        Button {
            showsSort = option.rawValue
        } label: {
            if sort == option {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
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
    case az, za, newestEpisode, oldestEpisode, followedNewest, followedOldest

    /// Shown beside YOUR SHOWS.
    var short: String {
        switch self {
        case .az: return "NAME A–Z"
        case .za: return "NAME Z–A"
        case .newestEpisode: return "NEWEST EPISODE"
        case .oldestEpisode: return "OLDEST EPISODE"
        case .followedNewest: return "RECENTLY FOLLOWED"
        case .followedOldest: return "FIRST FOLLOWED"
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

/// A row in the Library inbox: a poster row with the artwork stamp (tap the
/// stamp to play, the row for the episode page); swipe right to add it to
/// Up Next, left to mark it played.
private struct InboxRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        let inQueue = store.queue.contains { $0.episode.id == episode.episodeID }
        let isCurrent = player.nowPlaying?.episodeID == episode.episodeID
        var parts = [episode.showTitle]
        if let left = episode.timeLeft, left > 0 { parts.append(TimeFormat.clock(left)) }
        if isCurrent { parts.append("Playing") } else if inQueue { parts.append("In Up Next") }
        return HStack(spacing: 10) {
            PosterRowText(label: parts.filter { !$0.isEmpty }.joined(separator: " · "), title: episode.title, titleSize: 19, lines: 2)
            Button {
                if isCurrent { player.togglePlayPause() } else { player.play(episode) }
            } label: {
                Stamp(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 44)
                    .overlay {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Poster.paper)
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.45), in: Circle())
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCurrent && player.isPlaying ? "Pause" : "Play")
        }
        .showCard(episode.showArtwork, title: episode.showTitle)
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

/// A started episode in Carry on: a slim line with a ring showing how far
/// through it is (in the show's colour), the title and time left.
private struct CarryOnLine: View {
    let episode: PodcastEpisode

    var body: some View {
        let colour = Poster.colour(episode.showArtwork, title: episode.showTitle)
        let fraction = episode.duration.map { $0 > 0 ? min(1, episode.position / $0) : 0 } ?? 0
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Theme.hairline, lineWidth: 4)
                Circle().trim(from: 0, to: max(0.02, fraction))
                    .stroke(colour, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(([episode.showTitle] + [episode.timeLeft.map { "\(TimeFormat.length($0)) left" }].compactMap { $0 }).filter { !$0.isEmpty }.joined(separator: " · ").uppercased())
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }
        .contentShape(Rectangle())
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
        .accessibilityLabel("\(episode.title), \(Int(fraction * 100)) percent played")
        .accessibilityHint("Plays from where you stopped")
    }
}
