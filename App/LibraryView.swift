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
    /// The New Episodes card scrolled into view.
    @State private var cardInView: PersistentIdentifier?
    @State private var path = NavigationPath()
    @AppStorage("showsLayout") private var showsLayout = "large"
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

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if shows.isEmpty {
                        emptyState
                    } else {
                        HStack(spacing: 8) {
                            NavigationLink { HistoryView() } label: { libraryKey("HISTORY", icon: "clock.arrow.circlepath") }
                            NavigationLink { StatsView() } label: { libraryKey("STATS", icon: "chart.bar") }
                        }
                        .buttonStyle(KeyButtonStyle(radius: 8))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 3)

                        if !continuing.isEmpty {
                            sectionTitle("CONTINUE LISTENING", detail: "\(continuing.count) STARTED")
                            VStack(spacing: 10) {
                                ForEach(continuing) { episode in
                                    Button { player.play(episode) } label: {
                                        HistoryRow(episode: episode)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .deckCard()
                                    }
                                        .buttonStyle(.plain)
                                        .contextMenu { EpisodeMenuItems(episode: episode) }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        }

                        let cards = newCards
                        if !cards.isEmpty {
                            sectionTitle("NEW EPISODES", detail: "\(cards.count) UNPLAYED")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(cards) { episode in
                                        EpisodeCard(episode: episode)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            // Remembers which card is in view. After marking a
                            // lot played the carousel stayed scrolled past the
                            // cards that were left, showing an empty strip
                            // until a swipe: go back to the first card then.
                            .scrollPosition(id: $cardInView)
                            .onChange(of: cards.map(\.persistentModelID)) { _, ids in
                                if let shown = cardInView, !ids.contains(shown) {
                                    cardInView = ids.first
                                }
                            }
                            // Cards settle with their left edge on the page margin.
                            .contentMargins(.horizontal, 20, for: .scrollContent)
                            // The scroll view cut the cards' shadow off in a
                            // hard line (the "two tone" band under them).
                            .scrollClipDisabled()
                            // Settles on a card after a swipe, like Apple Podcasts.
                            .scrollTargetBehavior(.viewAligned)
                        }

                        HStack(alignment: .center) {
                            sectionTitle("YOUR SHOWS · \(shows.count)", detail: sort.short)
                            showsLayoutSwitch
                                .padding(.trailing, 20)
                        }
                        .padding(.top, 14)
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
            .tabTitle("LIBRARY")
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

    /// "Description only" was dropped (Paul, 10 Nov 2026); anyone who had
    /// it gets the cards.
    private var layout: String { showsLayout == "large" ? "large" : "card" }

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

    /// Large artwork tiles, or small cards with the description (Paul's
    /// choice, remembered and synced).
    @ViewBuilder private var yourShows: some View {
        let ordered = sortedShows
        if layout == "card" {
            // Rounded paper cards, like every other list (Paul after build 130).
            VStack(spacing: 10) {
                ForEach(ordered) { show in
                    NavigationLink(value: show) {
                        HStack(spacing: 12) {
                            ArtworkView(url: show.artworkURL, title: show.title, size: 56, radius: 10)
                            showText(show)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .deckCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(ordered) { show in
                    NavigationLink(value: show) {
                        ShowTile(show: show)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func showText(_ show: Podcast) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(show.title)
                .font(Theme.text(15, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            // TOP / BTM and how many new, like the large cards (Paul, 10 Nov 2026).
            ShowBadges(show: show)
                .padding(.top, 1)
        }
    }

    /// Sort key, then the two layout keys, on one paper strip.
    private var showsLayoutSwitch: some View {
        HStack(spacing: 2) {
            sortMenu
            layoutKey("large", icon: "square.grid.2x2.fill", label: "Large cards")
            layoutKey("card", icon: "list.bullet.below.rectangle", label: "Small cards with description")
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
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

    private func layoutKey(_ value: String, icon: String, label: String) -> some View {
        let on = layout == value
        return Button { showsLayout = value } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                .frame(width: 38, height: 32)
                .background(on ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func libraryKey(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(Theme.mono(12, .bold))
        }
        .frame(maxWidth: .infinity, minHeight: 40)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.mono(11, .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(detail)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 20)
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

/// A card in the New Episodes carousel, like Apple Podcasts': the artwork
/// fills the card and fades into its own colour, with the time ago, title,
/// description and keys in white over the colour.
private struct EpisodeCard: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

    // Option E (Paul, 5 Nov 2026): Apple Podcasts' proportions.
    private static let width: CGFloat = 248
    private static let height: CGFloat = 330
    /// How far down the card the artwork reaches before it has faded out.
    private static let artArea: CGFloat = 186

    var body: some View {
        let tint = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.podcast?.title ?? "")

        // Every layer is pinned to the card's size (overlays never resize
        // the card): a ZStack grew to its widest child, which pushed the
        // artwork sideways and left a strip of colour on one edge.
        tint
            .frame(width: Self.width, height: Self.height)
            .overlay(alignment: .top) {
                // Like Apple Podcasts' card (Paul's screenshot, 7 Nov 2026):
                // the artwork across the full width at the top, shown almost
                // whole, its lower part melting into the card's colour; the
                // text sits below it, not over it.
                CachedImage(url: episode.artwork) { Color.clear }
                    .frame(width: Self.width, height: Self.width)
                    .clipped()
                    .mask(
                        LinearGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black, location: 0.6),
                                               .init(color: .black.opacity(0), location: Self.artArea / Self.width)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                // The text fills the part below the artwork, keys at the
                // bottom; the notes give way first if space runs short.
                details(tint: tint)
                    .frame(width: Self.width, height: Self.height - Self.artArea + 14, alignment: .topLeading)
            }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { store.notesEpisode = episode }
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .padding(.bottom, 6)
        .task(id: episode.artwork) { await ArtworkColors.shared.load(episode.artwork) }
    }

    private func details(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // The artwork already says which show; just how new it is.
            Text(TimeFormat.ago(episode.published))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.displayText.opacity(0.6))
                .lineLimit(1)
            Text(episode.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.displayText)
                .lineLimit(1)
            // Up to three lines of the notes (it was one).
            Text(episode.summary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.displayText.opacity(0.92))
                .lineLimit(3)
                .layoutPriority(-1)
            Spacer(minLength: 0)
            // Fixed-size keys on the right and a pill that can shrink a
            // little: "54m left" pushed the ⋯ off the card's edge.
            HStack(spacing: 4) {
                playPill
                Spacer(minLength: 4)
                // Mark played straight from the card (Paul, 8 Nov 2026),
                // with the usual Undo bar.
                Button {
                    store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.displayText.opacity(0.75))
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark as played")
                DownloadButton(episode: episode, tint: Theme.displayText.opacity(0.75))
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.displayText.opacity(0.75))
                    .frame(width: 32, height: 36)
                Menu {
                    EpisodeMenuItems(episode: episode)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.displayText.opacity(0.75))
                        .frame(width: 28, height: 36)
                }
                .accessibilityLabel("More")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var isCurrent: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    /// Play, or (for the episode that's on) Playing / Paused with a moving
    /// wave, tapping to pause and carry on.
    private var playPill: some View {
        let current = isCurrent
        let playing = current && player.isPlaying
        return Button {
            if current { player.togglePlayPause() } else { player.play(episode) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                // The episode that's on shows its time left like the others
                // (with the light pill and wave); "Playing" got squashed
                // to "Pla…" (Paul, 9 Nov 2026).
                Text(playLabel)
                    .lineLimit(1)
                    .fixedSize()
                if current {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: playing)
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(current ? tintForCurrent : Theme.displayText)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(current ? AnyShapeStyle(Theme.displayText) : AnyShapeStyle(Color.white.opacity(0.22)), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(current ? (playing ? "Pause" : "Carry on playing") : "Play, \(playLabel)")
    }

    /// Text on the light pill of the episode that's on: the card's colour.
    private var tintForCurrent: Color {
        ArtworkColors.shared.background(for: episode.artwork) ?? Theme.ink
    }

    private var playLabel: String {
        // "1h 16m" like Apple's cards; a long clock (1:16:31) wrapped
        // onto two lines in the pill.
        guard let left = episode.timeLeft, left > 0 else { return "PLAY" }
        // Just the time, like Apple's ("53m"); the light pill says Playing.
        return TimeFormat.length(left)
    }
}

private struct ShowTile: View {
    let show: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ArtworkView(url: show.artworkURL, title: show.title, size: proxy.size.width, radius: 10)
            }
            .aspectRatio(1, contentMode: .fit)
            Text(show.title)
                .font(Theme.text(14, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            ShowBadges(show: show)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Where new episodes go (TOP / BTM / OFF) and how many are unplayed, under
/// each show in Your shows (both layouts).
private struct ShowBadges: View {
    let show: Podcast

    var body: some View {
        HStack(spacing: 6) {
            DeckTag(text: tag)
            Text("\(show.episodes.filter { !$0.played }.count) NEW")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.muted)
        }
    }

    private var tag: String {
        switch show.autoAdd {
        case .top: return "TOP"
        case .bottom: return "BTM"
        case .off: return "OFF"
        }
    }
}

/// How Your shows is ordered (Paul, 10 Nov 2026), saved as "showsSort".
enum ShowsSort: String {
    case az, za, newestEpisode, oldestEpisode, followedNewest, followedOldest

    /// Shown beside YOUR SHOWS.
    var short: String {
        switch self {
        case .az: return "A–Z"
        case .za: return "Z–A"
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
