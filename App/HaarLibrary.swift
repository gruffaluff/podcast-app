import SwiftUI
import SwiftData
import PodcastCore

/// Haar, phase 4: Library (Paul, 13 Nov 2026). New as an inbox by day
/// (Today / Yesterday / This week; + adds to Up next, ✓ marks played,
/// Add all / Mark all played), Carry on with progress rings, Your shows as
/// an artwork grid with ranked Top shows first (their rank in the corner),
/// then shelves: Downloads, Saved clips, History, Stats. Settings from the
/// gear at the top. Used by `LibraryView` when the Haar look is on.
struct HaarLibrarySections: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let newEpisodes: [PodcastEpisode]
    let continuing: [PodcastEpisode]
    /// In the chosen sort order; Top shows are pulled to the front here.
    let shows: [Podcast]
    let sortMenu: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            newSection
            if !continuing.isEmpty {
                title("Carry on")
                VStack(spacing: 0) {
                    ForEach(Array(continuing.enumerated()), id: \.element.episodeID) { index, episode in
                        if index > 0 { hairline(leading: 70) }
                        HaarCarryOnRow(episode: episode)
                    }
                }
                .padding(.vertical, 4)
                .frostedCard()
                .padding(.horizontal, 14)
            }
            HStack(alignment: .firstTextBaseline) {
                title("Your shows", detail: "\(shows.count)")
                sortMenu.padding(.trailing, 10)
            }
            showGrid
            title("Shelves")
            shelves
        }
    }

    private func title(_ text: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(Theme.big(24))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(Theme.text(13, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func hairline(leading: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.ink.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, leading)
    }

    // MARK: New

    private enum Day: Int, CaseIterable {
        case today, yesterday, week
        var label: String {
            switch self {
            case .today: "Today"
            case .yesterday: "Yesterday"
            case .week: "This week"
            }
        }
        static func of(_ date: Date) -> Day {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return .today }
            if calendar.isDateInYesterday(date) { return .yesterday }
            return .week
        }
    }

    @ViewBuilder private var newSection: some View {
        let total: TimeInterval = newEpisodes.reduce(0) { $0 + ($1.timeLeft ?? $1.duration ?? 0) }
        title("New", detail: newEpisodes.isEmpty ? nil : "\(newEpisodes.count) · \(TimeFormat.length(total))")
        if newEpisodes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("All caught up")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.ink)
                Text("New episodes land here as they come out, for a week.")
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 18)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Day.allCases, id: \.rawValue) { day in
                    let group: [PodcastEpisode] = newEpisodes.filter { Day.of($0.published) == day }
                    if !group.isEmpty {
                        Text(day.label)
                            .font(Theme.text(12, .semibold))
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.top, day == Day.of(newEpisodes[0].published) ? 10 : 14)
                            .padding(.bottom, 2)
                        ForEach(Array(group.enumerated()), id: \.element.episodeID) { index, episode in
                            if index > 0 { hairline(leading: 70) }
                            HaarInboxRow(episode: episode)
                        }
                    }
                }
                newActions
                    .padding(.top, 6)
            }
            .padding(.bottom, 4)
            .frostedCard()
            .padding(.horizontal, 14)
        }
    }

    /// Add all to Up next (only those not in it yet, oldest first) and
    /// Mark all played, both with Undo, as plain words.
    private var newActions: some View {
        let allQueued: Bool = newEpisodes.allSatisfy { store.isQueued($0) }
        return HStack(spacing: 0) {
            Button {
                let missing = newEpisodes.filter { !store.isQueued($0) }.sorted { $0.published < $1.published }
                guard !missing.isEmpty else { return }
                store.undoable("Added \(missing.count) to Up Next", episodes: []) {
                    store.commit(QueueEngine.playLast(missing.map(\.queueEpisode), in: store.queue, settings: store.queueSettings))
                }
            } label: {
                Label(allQueued ? "All in Up next" : "Add all to Up next", systemImage: allQueued ? "checkmark" : "plus")
                    .font(Theme.text(13, .semibold))
                    .foregroundStyle(allQueued ? Theme.muted : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(allQueued)
            Button {
                let list = newEpisodes
                store.undoable("Marked \(list.count) played", episodes: list) { store.markPlayed(list) }
            } label: {
                Label("Mark all played", systemImage: "checkmark.circle")
                    .font(Theme.text(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Your shows

    /// Top shows first, in rank order, then the rest in the chosen order.
    private struct Entry: Identifiable {
        let show: Podcast
        let rank: Int?
        var id: String { show.feedURL }
    }

    private var ordered: [Entry] {
        let top: [Podcast] = shows.filter { $0.autoAdd == .top }.sorted { $0.topRank < $1.topRank }
        let topKeys = Set(top.map(\.feedURL))
        var entries: [Entry] = []
        for (index, show) in top.enumerated() {
            entries.append(Entry(show: show, rank: index + 1))
        }
        for show in shows where !topKeys.contains(show.feedURL) {
            entries.append(Entry(show: show, rank: nil))
        }
        return entries
    }

    private var showGrid: some View {
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(ordered) { entry in
                Button { store.showSheet = entry.show } label: {
                    HaarShowTile(show: entry.show, rank: entry.rank)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: Shelves

    private var shelves: some View {
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            shelf("Downloads", icon: "arrow.down.circle") { StorageView() }
            shelf("Saved clips", icon: "quote.opening") { HaarSavedClipsView() }
            shelf("History", icon: "clock.arrow.circlepath") { HistoryView() }
            shelf("Stats", icon: "chart.bar") { StatsView() }
        }
        .padding(.horizontal, 14)
    }

    private func shelf<Destination: View>(_ name: String, icon: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 24)
                Text(name)
                    .font(Theme.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .frostedCard(radius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One new episode: artwork (tap to play), title and show · length (tap
/// for the episode page), then + (add to Up next) and ✓ (played, with
/// Undo). Touch and hold for the usual episode menu.
private struct HaarInboxRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        let inQueue: Bool = store.isQueued(episode)
        let isCurrent: Bool = player.nowPlaying?.episodeID == episode.episodeID
        var parts: [String] = [episode.showTitle]
        let length: TimeInterval = episode.timeLeft ?? episode.duration ?? 0
        if length > 0 { parts.append(TimeFormat.length(length)) }
        if isCurrent { parts.append("Playing") } else if inQueue { parts.append("In Up next") }
        return HStack(spacing: 12) {
            Button {
                if isCurrent { player.togglePlayPause() } else { player.play(episode) }
            } label: {
                ArtworkView(url: episode.artwork, title: episode.showTitle, size: 44, radius: 9)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCurrent && player.isPlaying ? "Pause" : "Play")
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2, reservesSpace: true)
                HStack(spacing: 6) {
                    Text(parts.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    EpisodeLights(episode: episode)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { store.notesEpisode = episode }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the episode page")
            Button { store.playLast(episode) } label: {
                Image(systemName: inQueue ? "checkmark" : "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(inQueue ? Theme.muted : Theme.ink)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(inQueue)
            .accessibilityLabel(inQueue ? "In Up next" : "Add to Up next")
            Button {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark as played")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .contextMenu { EpisodeMenuItems(episode: episode) }
    }
}

/// A started episode with a ring round its play key showing how far
/// through it is.
private struct HaarCarryOnRow: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    private var fraction: Double {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        return min(1, max(0.03, episode.position / duration))
    }

    var body: some View {
        let isCurrent: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let left: String = episode.timeLeft.map { "\(TimeFormat.length($0)) left" } ?? ""
        return Button {
            if isCurrent { player.togglePlayPause() } else { player.play(episode) }
        } label: {
            HStack(spacing: 12) {
                ArtworkView(url: episode.artwork, title: episode.showTitle, size: 44, radius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(Theme.text(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text([episode.showTitle, left].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().stroke(Theme.ink.opacity(0.14), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink)
                        .offset(x: isCurrent && player.isPlaying ? 0 : 1)
                }
                .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { EpisodeMenuItems(episode: episode) }
        .accessibilityLabel("\(isCurrent && player.isPlaying ? "Pause" : "Play") \(episode.title), \(left)")
    }
}

/// A show in the grid: its artwork, the rank in the corner for Top shows,
/// a count of new episodes, the name under it.
private struct HaarShowTile: View {
    let show: Podcast
    let rank: Int?

    var body: some View {
        let fresh: Int = ShowBadges.newCount(show)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ArtworkView(url: show.artworkURL, title: show.title, size: geometry.size.width, radius: 14)
                    .shadow(color: Color(hex: 0x28323C).opacity(0.14), radius: 8, y: 4)
                    // New this week: a solid dark pill with a white edge in
                    // the top corner, so it reads on any artwork (Paul,
                    // build 151: the counters were lost on the art).
                    .overlay(alignment: .topTrailing) {
                        if fresh > 0 {
                            Text("\(fresh) new")
                                .font(Theme.text(11, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .frame(minHeight: 20)
                                .background(Color(hex: 0x1F2328), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                                .padding(6)
                                .accessibilityLabel("\(fresh) new")
                        }
                    }
            }
            .aspectRatio(1, contentMode: .fit)
            // Top shows' rank sits beside the name in the serif, off the
            // artwork (Paul, build 151: the badges on the art didn't work).
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let rank {
                    Text("\(rank)")
                        .font(Theme.serif(19))
                        .foregroundStyle(Theme.muted)
                        .accessibilityLabel("Top show number \(rank)")
                }
                Text(show.title)
                    .font(Theme.text(12, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Saved clips (bookmarked lines and shared clips), newest first.
struct HaarSavedClipsView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Bookmark.created, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        let episodes = store.episodes(bookmarks.map(\.episodeID))
        List {
            if bookmarks.isEmpty {
                Text("Touch and hold a line in a transcript and choose Bookmark or Share a clip to save it here.")
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.rowBackground)
                    .listRowSeparator(.hidden)
            }
            ForEach(bookmarks) { bookmark in
                if let episode = episodes[bookmark.episodeID] {
                    ClipRow(bookmark: bookmark, episode: episode)
                        .listRowBackground(Theme.rowBackground)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.context.delete(bookmark)
                                store.save()
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .haarPage()
        .navigationTitle("Saved clips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ShowBadges {
    /// Unplayed episodes out in the last week (Library's New), for the
    /// count on a show's tile.
    static func newCount(_ show: Podcast) -> Int {
        let cutoff = Date().addingTimeInterval(-LibraryView.newFor)
        return show.episodes.filter { !$0.played && $0.published > cutoff }.count
    }
}
