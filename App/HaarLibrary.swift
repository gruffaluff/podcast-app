import SwiftUI
import SwiftData
import PodcastCore

/// Haar, phase 4: Library (Paul, 13 Nov 2026), reworked to the prototype
/// ("Real · Library"). Small capital labels instead of big headings: NEW
/// (one frosted card by day, Clear all), CARRY ON (plain rows with a ring
/// in the show's colour), YOUR SHOWS (artwork grid, Top shows first with
/// their rank beside the name), then one card of shelves: Downloads, Saved
/// clips, History, Stats, Finished. The title, + and settings sit in
/// `LibraryView`'s Haar header. Used by `LibraryView` in the Haar look.
struct HaarLibrarySections: View {
    @Environment(LibraryStore.self) private var store
    let newEpisodes: [PodcastEpisode]
    let continuing: [PodcastEpisode]
    /// In the chosen sort order; Top shows are pulled to the front here.
    let shows: [Podcast]
    let sortMenu: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            newSection
            if !continuing.isEmpty {
                carryOnSection
            }
            yourShowsSection
            // Plain rows: their words line up with the section labels (18).
            HaarShelves()
                .padding(.horizontal, 2)
                .padding(.top, 24)
        }
    }

    // MARK: New

    private enum Day: Int, CaseIterable {
        case today, yesterday, week
        var label: String {
            switch self {
            case .today: "TODAY"
            case .yesterday: "YESTERDAY"
            case .week: "THIS WEEK"
            }
        }
        static func of(_ date: Date) -> Day {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return .today }
            if calendar.isDateInYesterday(date) { return .yesterday }
            return .week
        }
    }

    private struct DayGroup: Identifiable {
        let day: Day
        let episodes: [PodcastEpisode]
        var id: Int { day.rawValue }
    }

    private var newSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HaarSectionLabel(text: newEpisodes.isEmpty ? "New" : "New · \(newEpisodes.count)") {
                if !newEpisodes.isEmpty { clearAllButton }
            }
            if newEpisodes.isEmpty {
                Text("All caught up.")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
            } else {
                newCard
            }
        }
        .padding(.top, 14)
    }

    /// Marks everything in New played, with Undo.
    private var clearAllButton: some View {
        Button {
            let list: [PodcastEpisode] = newEpisodes
            store.undoable("Marked \(list.count) played", episodes: list) { store.markPlayed(list) }
        } label: {
            Text("Clear all")
                .font(Theme.text(13, .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Marks every new episode as played")
    }

    private var newCard: some View {
        let groups: [DayGroup] = Day.allCases.compactMap { day in
            let group: [PodcastEpisode] = newEpisodes.filter { Day.of($0.published) == day }
            return group.isEmpty ? nil : DayGroup(day: day, episodes: group)
        }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                newGroup(group.day, group.episodes)
            }
        }
        // Plain rows straight on the fog, no card (Paul, 13 Nov 2026,
        // after build 152: "the new box looks a bit odd").
        .padding(.horizontal, 2)
    }

    private func newGroup(_ day: Day, _ episodes: [PodcastEpisode]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Theme.muted.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(episodes.enumerated()), id: \.element.episodeID) { index, episode in
                if index > 0 { HaarHairline() }
                HaarInboxRow(episode: episode)
            }
        }
    }

    // MARK: Carry on

    private var carryOnSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HaarSectionLabel(text: "Carry on · \(continuing.count)") {
                Text(carryOnLeft)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(Array(continuing.enumerated()), id: \.element.episodeID) { index, episode in
                if index > 0 { HaarHairline().padding(.leading, 2) }
                HaarCarryOnRow(episode: episode)
            }
        }
        .padding(.top, 22)
    }

    /// "1 h 31 m left" across everything in Carry on.
    private var carryOnLeft: String {
        let seconds: TimeInterval = continuing.reduce(0) { $0 + ($1.timeLeft ?? 0) }
        guard seconds > 0 else { return "" }
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) m left" : "\(max(1, minutes)) min left"
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

    private var yourShowsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HaarSectionLabel(text: "Your shows") { sortMenu }
            showList
        }
        .padding(.top, 22)
    }

    /// One show per line (Paul, 13 Nov 2026, after build 152; was a
    /// 3-across artwork grid).
    private var showList: some View {
        let entries: [Entry] = ordered
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { HaarHairline().padding(.leading, 2) }
                Button { store.showSheet = entry.show } label: {
                    HaarShowLine(show: entry.show, rank: entry.rank)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pieces

/// A section label: small spaced capitals in muted ink, with anything
/// (Clear all, the sort key) on the right.
private struct HaarSectionLabel<Trailing: View>: View {
    let text: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 32)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.bottom, 6)
    }
}

/// A fine line between rows in a card, inset 16.
private struct HaarHairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.ink.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

/// A show's own colour (measured from its artwork), the accent until known.
@MainActor
private func haarShowColour(_ url: URL?) -> Color {
    ArtworkColors.shared.background(for: url) ?? Theme.accentText
}

/// "65 min".
private func haarMinutes(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "" }
    return "\(max(1, Int((seconds / 60).rounded()))) min"
}

/// One new episode: artwork (tap to play), the show in its colour, title,
/// length and where it is in Up next; + (add to Up next, when it isn't
/// there) and ✓ (played, with Undo). Tap the row for the episode page;
/// touch and hold for the usual episode menu.
private struct HaarInboxRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    private var showArtwork: URL? { episode.podcast?.artworkURL ?? episode.artwork }

    private var isCurrent: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    /// "65 min · In Up next, auto #1" or "65 min · Waiting for you".
    private var meta: String {
        let length: String = haarMinutes(episode.timeLeft ?? episode.duration ?? 0)
        var place = "Waiting for you"
        if isCurrent {
            place = "Playing"
        } else if let index = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) {
            let auto: Bool = store.queue[index].source == .auto
            place = "In Up next, \(auto ? "auto " : "")#\(index + 1)"
        }
        return [length, place].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        let inQueue: Bool = store.isQueued(episode)
        return HStack(spacing: 12) {
            playButton
            text
            if !inQueue && !isCurrent { addButton }
            playedButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
        .contextMenu { EpisodeMenuItems(episode: episode) }
        .task { await ArtworkColors.shared.load(showArtwork) }
    }

    private var playButton: some View {
        Button {
            if isCurrent { player.togglePlayPause() } else { player.play(episode) }
        } label: {
            ArtworkView(url: episode.artwork, title: episode.showTitle, size: 40, radius: 0)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrent && player.isPlaying ? "Pause" : "Play")
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(episode.showTitle.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(haarShowColour(showArtwork))
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.text(14, .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(meta)
                .font(Theme.text(12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { store.notesEpisode = episode }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the episode page")
    }

    private var addButton: some View {
        Button { store.playLast(episode) } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to Up next")
    }

    private var playedButton: some View {
        Button {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark as played")
    }
}

/// A started episode: a ring in the show's colour showing how far through
/// it is (play / pause inside), the title, show and time left. Tap plays
/// or pauses.
private struct HaarCarryOnRow: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    private var fraction: Double {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        return min(1, max(0.03, episode.position / duration))
    }

    private var showArtwork: URL? { episode.podcast?.artworkURL ?? episode.artwork }

    var body: some View {
        let isCurrent: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let playing: Bool = isCurrent && player.isPlaying
        let left: String = episode.timeLeft.map { haarMinutes($0) }.map { $0.isEmpty ? "" : "\($0) left" } ?? ""
        let meta: String = [episode.showTitle, left].filter { !$0.isEmpty }.joined(separator: " · ")
        return Button {
            if isCurrent { player.togglePlayPause() } else { player.play(episode) }
        } label: {
            HStack(spacing: 12) {
                HaarRing(fraction: fraction, colour: haarShowColour(showArtwork), playing: playing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.showTitle.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(haarShowColour(showArtwork))
                        .lineLimit(1)
                    Text(episode.title)
                        .font(Theme.text(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(left.isEmpty ? " " : left)
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ArtworkView(url: episode.artwork, title: episode.showTitle, size: 40, radius: 0)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { EpisodeMenuItems(episode: episode) }
        .task { await ArtworkColors.shared.load(showArtwork) }
        .accessibilityLabel("\(playing ? "Pause" : "Play") \(episode.title), \(meta)")
    }
}

/// A 36-point progress ring with a play / pause glyph inside.
private struct HaarRing: View {
    let fraction: Double
    let colour: Color
    let playing: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(colour, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 11))
                .foregroundStyle(colour)
                .offset(x: playing ? 0 : 1)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

/// A show in the list: small artwork, the rank as a rounded number in
/// front of the name for Top shows, where its new episodes go, and an
/// "n new" pill.
private struct HaarShowLine: View {
    let show: Podcast
    let rank: Int?

    private var goesTo: String {
        switch show.autoAdd {
        case .top: "Top of Up next"
        case .bottom: "Bottom of Up next"
        case .off: "Not added to Up next"
        }
    }

    var body: some View {
        let fresh: Int = ShowBadges.newCount(show)
        HStack(spacing: 12) {
            ArtworkView(url: show.artworkURL, title: show.title, size: 46, radius: 0)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                nameLine
                Text(goesTo)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if fresh > 0 { newPill(fresh) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func newPill(_ count: Int) -> some View {
        Text("\(count) new")
            .font(Theme.text(11, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(minHeight: 20)
            .background(Color(hex: 0x1F2328), in: Capsule())
            .accessibilityLabel("\(count) new")
    }

    private var nameLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let rank {
                Text("\(rank)")
                    .font(Theme.rounded(17))
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel("Top show number \(rank)")
            }
            Text(show.title)
                .font(Theme.text(15, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
    }
}

// MARK: - Shelves

/// The shelves, as plain rows: Downloads, Saved clips, History, Stats, Finished,
/// each with a line of what's there (worked out when Library appears).
private struct HaarShelves: View {
    @Environment(LibraryStore.self) private var store
    @State private var info = Info()

    struct Info {
        var downloads = 0
        var downloadBytes: Int64 = 0
        var clips = 0
        var month: TimeInterval = 0
        var week: TimeInterval = 0
        var finished = 0
    }

    var body: some View {
        VStack(spacing: 0) {
            shelf("Downloads", icon: "arrow.down.circle", meta: downloadsMeta) { StorageView() }
            HaarMenuHairline(inset: HaarShelfRow.textInset)
            shelf("Saved clips", icon: "quote.opening", meta: "\(info.clips) clip\(info.clips == 1 ? "" : "s"), searchable") { HaarSavedClipsView() }
            HaarMenuHairline(inset: HaarShelfRow.textInset)
            shelf("History", icon: "clock.arrow.circlepath", meta: historyMeta) { HistoryView() }
            HaarMenuHairline(inset: HaarShelfRow.textInset)
            shelf("Stats", icon: "chart.bar", meta: statsMeta) { StatsView() }
            HaarMenuHairline(inset: HaarShelfRow.textInset)
            shelf("Finished", icon: "checkmark.circle", meta: "\(info.finished) episode\(info.finished == 1 ? "" : "s")") { HaarFinishedView() }
        }
        // Menu rows, not content: plain text on the page with hairlines
        // between (Paul, 13 Nov 2026: "just text in the mockup. No white card").
        .onAppear { info = load() }
    }

    private var downloadsMeta: String {
        let count = "\(info.downloads) episode\(info.downloads == 1 ? "" : "s")"
        guard info.downloadBytes > 0 else { return count }
        let size: String = ByteCountFormatter.string(fromByteCount: info.downloadBytes, countStyle: .file)
        return "\(count) · \(size)"
    }

    private var historyMeta: String {
        guard info.month >= 60 else { return "Everything you've played" }
        let hours = Int(info.month / 3600)
        let amount: String = hours >= 1 ? "\(hours) hour\(hours == 1 ? "" : "s")" : TimeFormat.length(info.month)
        return "Last 30 days · \(amount)"
    }

    private var statsMeta: String {
        guard info.week >= 60 else { return "Listening time and top shows" }
        return "This week \(TimeFormat.length(info.week))"
    }

    private func load() -> Info {
        var result = Info()
        let storage = store.storageByShow()
        result.downloads = storage.reduce(0) { $0 + $1.count }
        result.downloadBytes = storage.reduce(Int64(0)) { $0 + $1.bytes }
        result.clips = (try? store.context.fetchCount(FetchDescriptor<Bookmark>())) ?? 0
        let stats = store.listeningStats()
        result.month = stats.month
        result.week = stats.week
        let played = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == true })
        result.finished = (try? store.context.fetchCount(played)) ?? 0
        return result
    }

    private func shelf<Destination: View>(_ name: String, icon: String, meta: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HaarShelfRow(name: name, icon: icon, meta: meta)
        }
        .buttonStyle(.plain)
    }
}

private struct HaarShelfRow: View {
    static let iconWidth: CGFloat = 26
    /// Where the words start, for the hairlines between rows.
    static let textInset: CGFloat = 16 + iconWidth + 12

    let name: String
    let icon: String
    let meta: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: HaarShelfRow.iconWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.text(16, .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Every played episode, most recently played first (Library's Finished
/// shelf). Tap to play again.
struct HaarFinishedView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @State private var episodes: [PodcastEpisode] = []

    var body: some View {
        List {
            if episodes.isEmpty {
                Text("Episodes you finish will appear here.")
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.rowBackground)
            }
            ForEach(episodes) { episode in
                Button { player.play(episode) } label: {
                    HistoryRow(episode: episode, showsProgress: false)
                        .showCard(episode.showArtwork, title: episode.showTitle)
                }
                .buttonStyle(.plain)
                .contextMenu { EpisodeMenuItems(episode: episode) }
                .deckCardRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .haarPage()
        .navigationTitle("Finished")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { episodes = load() }
    }

    private func load() -> [PodcastEpisode] {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == true },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 300
        return (try? store.context.fetch(descriptor)) ?? []
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
