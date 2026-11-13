import SwiftUI
import UIKit
import PodcastCore

/// Haar: a show opens as a sheet over whatever you're on (Paul, 13 Nov
/// 2026: "let's work the show page"), drawn as its own quiet page like the
/// prototype: the artwork, the name in the serif, Following / Play latest
/// as plain words, then Episodes / Settings as two words. Swipe it down to
/// go back where you were. The other colour schemes keep `ShowView` and
/// `ShowSettingsView`; this page doesn't use them.
struct HaarShowSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    /// The show's colour, fixed when the sheet opens so nothing changes
    /// colour while it's on screen (as ShowView's `pageColour`).
    @State private var colour: Color?
    /// "Twice a week · 592 episodes", worked out once.
    @State private var subtitle: String
    @State private var onSettings = false
    /// Episodes: unplayed only (default) or all.
    @State private var showAll = false
    @State private var confirmingUnfollow = false

    init(show: Podcast) {
        self.show = show
        _colour = State(initialValue: ArtworkColors.shared.background(for: show.artworkURL))
        _subtitle = State(initialValue: HaarShowHeader.subtitle(for: show))
    }

    private var tint: Color { colour ?? Theme.accentFill }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HaarShowHeader(show: show, subtitle: subtitle, tint: tint) { confirmingUnfollow = true }
                HaarShowTabs(onSettings: $onSettings)
                    .padding(.top, 24)
                page
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { closeButton }
        .overlay(alignment: .top) {
            UndoBar()
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .environment(\.showColour, colour)
        .environment(\.openShowSettings, { withAnimation(.easeOut(duration: 0.2)) { onSettings = true } })
        // An episode page opened from here sits over this sheet (the root
        // view can't show one while this is up).
        .sheet(item: Binding(get: { store.notesEpisode }, set: { store.notesEpisode = $0 })) { episode in
            EpisodeNotesView(episode: episode)
        }
        .alert("Unfollow \(show.title)?", isPresented: $confirmingUnfollow) {
            Button("Cancel", role: .cancel) {}
            Button("Unfollow", role: .destructive) { unfollow() }
        } message: {
            Text("Its episodes leave Up Next and your library.")
        }
        .task(id: show.artworkURL) { await ArtworkColors.shared.load(show.artworkURL) }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(36)
        .presentationBackground { HaarShowSheetBackground() }
    }

    @ViewBuilder private var page: some View {
        if onSettings {
            HaarShowSettings(show: show, tint: tint)
        } else {
            HaarShowEpisodes(show: show, tint: tint, showAll: $showAll)
        }
    }

    /// Swipe down closes the sheet; this quiet ✕ is there for anyone who
    /// can't swipe (and VoiceOver).
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.55)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.trailing, 12)
        .accessibilityLabel("Close")
    }

    private func unfollow() {
        player.stopIfPlaying(showFeedURL: show.feedURL)
        dismiss()
        // Delete once the sheet has closed, so it never shows a removed show.
        let show = show
        let store = store
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            store.unfollow(show)
        }
    }
}

/// The sheet's own see-through grey (prototype: rgba(240,241,240,.9) over
/// a blur), instead of the fog page.
private struct HaarShowSheetBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color(red: 240 / 255, green: 241 / 255, blue: 240 / 255).opacity(0.9)
        }
        .ignoresSafeArea()
    }
}

/// Artwork, name, how often it comes out · how many episodes, and
/// Following / Play latest as plain words.
struct HaarShowHeader: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let show: Podcast
    let subtitle: String
    let tint: Color
    let unfollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork
            Text(show.title)
                .font(Theme.serif(32))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
            actions
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ArtworkView(url: show.artworkURL, title: show.title, size: 88, radius: 24)
            .clipShape(shape)
            .background(shape.fill(Color.white.opacity(0.4)))
            .shadow(color: Color(red: 40 / 255, green: 50 / 255, blue: 60 / 255).opacity(0.18), radius: 13, y: 12)
    }

    private var actions: some View {
        HStack(spacing: 28) {
            // Every show on this page is one you follow (a show you don't
            // follow opens its preview instead), so the word is Following;
            // tap it to unfollow.
            Button(action: unfollow) {
                Text("Following ✓")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Following")
            .accessibilityHint("Unfollows this show, after asking")
            if let latest = store.latestEpisode(of: show) {
                Button { playLatest(latest) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: latestIsPlaying(latest) ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(latestIsPlaying(latest) ? "Pause latest" : "Play latest")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func latestIsPlaying(_ latest: PodcastEpisode) -> Bool {
        player.isPlaying && player.nowPlaying?.episodeID == latest.episodeID
    }

    private func playLatest(_ latest: PodcastEpisode) {
        if player.nowPlaying?.episodeID == latest.episodeID {
            player.togglePlayPause()
        } else {
            player.play(latest)
        }
    }

    /// "Twice a week · 592 episodes", or the publisher when there's no
    /// clear rhythm.
    static func subtitle(for show: Podcast) -> String {
        let episodes: [PodcastEpisode] = show.episodes
        let count: Int = episodes.count
        let lead: String = cadence(of: episodes) ?? show.author
        let total: String = "\(count) episode\(count == 1 ? "" : "s")"
        return lead.isEmpty ? total : "\(lead) · \(total)"
    }

    /// Daily / Twice a week / Weekly / Every two weeks / Monthly, from the
    /// typical gap between the newest few episodes (nil if it has no clear
    /// rhythm or hasn't had an episode for a while).
    static func cadence(of episodes: [PodcastEpisode]) -> String? {
        let dates: [Date] = Array(episodes.map(\.published).sorted(by: >).prefix(9))
        guard dates.count >= 4, let newest = dates.first,
              newest > Date().addingTimeInterval(-45 * 86_400) else { return nil }
        var gaps: [Double] = []
        for index in 1..<dates.count {
            gaps.append(dates[index - 1].timeIntervalSince(dates[index]) / 86_400)
        }
        gaps.sort()
        let typical: Double = gaps[gaps.count / 2]
        switch typical {
        case ..<1.6: return "Daily"
        case 2.5..<4.6: return "Twice a week"
        case 5.5..<8.6: return "Weekly"
        case 12..<16.5: return "Every two weeks"
        case 26..<35: return "Monthly"
        default: return nil
        }
    }
}

/// Episodes / Settings: two equal words, the chosen one ink and underlined.
private struct HaarShowTabs: View {
    @Binding var onSettings: Bool

    var body: some View {
        HStack(spacing: 0) {
            tab("Episodes", selected: !onSettings) { onSettings = false }
            tab("Settings", selected: onSettings) { onSettings = true }
        }
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            HaarShowHairline(inset: 0)
        }
    }

    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        HaarShowWord(title: title, selected: selected, size: 15, gap: 7) {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Episodes

/// A search box for the show's episodes, Unplayed / All, Mark all played,
/// and the episodes. On Unplayed, the played ones follow below, grouped by
/// month (Paul, 13 Nov 2026, C "Search and months" on
/// https://claude.ai/artifact/TQpmnvsJ7QjSMhXdm3JwY9: the page looked
/// empty with one unplayed episode).
private struct HaarShowEpisodes: View {
    @Environment(LibraryStore.self) private var store
    let show: Podcast
    let tint: Color
    @Binding var showAll: Bool
    @State private var confirmingMarkAll = false
    @State private var query = ""

    private struct Month: Identifiable {
        let id: String
        let title: String
        let episodes: [PodcastEpisode]
    }

    var body: some View {
        let all: [PodcastEpisode] = show.episodes.sorted { $0.published > $1.published }
        let searching: Bool = !query.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: 14) {
            searchBox(count: all.count)
            if searching {
                results(all)
            } else {
                filterRow(hasUnplayed: all.contains { !$0.played })
                if showAll {
                    if all.isEmpty { note("No episodes yet.") } else { list(all, all: all) }
                } else {
                    unplayedThenMonths(all)
                }
            }
        }
        .alert("Mark all \(show.episodes.count) episodes as played?", isPresented: $confirmingMarkAll) {
            Button("Mark all played") {
                let everything: [PodcastEpisode] = show.episodes
                store.undoable("Marked \(everything.count) played", episodes: everything) { store.markPlayed(everything) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They leave Up Next and stop showing as unplayed.")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func searchBox(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Search \(count) episodes", text: $query)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Titles and notes that contain every word typed.
    private func results(_ all: [PodcastEpisode]) -> some View {
        let words: [String] = query.lowercased().split(separator: " ").map(String.init)
        let found: [PodcastEpisode] = all.filter { episode in
            let text: String = (episode.title + " " + episode.summary).lowercased()
            return words.allSatisfy { text.contains($0) }
        }
        return Group {
            if found.isEmpty {
                note("Nothing matches “\(query)”.")
            } else {
                list(found, all: all)
            }
        }
    }

    /// Unplayed, then "That's everything unplayed", then the played ones
    /// by month, newest first.
    @ViewBuilder private func unplayedThenMonths(_ all: [PodcastEpisode]) -> some View {
        let unplayed: [PodcastEpisode] = all.filter { !$0.played }
        let played: [PodcastEpisode] = all.filter(\.played)
        // The most recent 60, so a 600-episode show still opens quickly;
        // All has the rest.
        let months: [Month] = Self.months(Array(played.prefix(60)))
        if unplayed.isEmpty {
            note(all.isEmpty ? "No episodes yet." : "You're all caught up.")
        } else {
            list(unplayed, all: all)
            if !months.isEmpty { note("That's everything unplayed.") }
        }
        ForEach(months) { month in
            VStack(alignment: .leading, spacing: 6) {
                Text(month.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
                list(month.episodes, all: all)
            }
        }
        if played.count > 60 {
            Button {
                withAnimation(LibraryStore.listChange) { showAll = true }
            } label: {
                Text("Older episodes are under All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// "November" (this year) or "March 2024".
    private static func months(_ played: [PodcastEpisode]) -> [Month] {
        let calendar = Calendar.current
        var order: [String] = []
        var groups: [String: [PodcastEpisode]] = [:]
        var titles: [String: String] = [:]
        for episode in played {
            let parts = calendar.dateComponents([.year, .month], from: episode.published)
            let key = "\(parts.year ?? 0)-\(parts.month ?? 0)"
            if groups[key] == nil {
                order.append(key)
                let sameYear: Bool = calendar.isDate(episode.published, equalTo: Date(), toGranularity: .year)
                titles[key] = episode.published.formatted(sameYear ? .dateTime.month(.wide) : .dateTime.month(.wide).year())
            }
            groups[key, default: []].append(episode)
        }
        return order.map { Month(id: $0, title: titles[$0] ?? "", episodes: groups[$0] ?? []) }
    }

    private func filterRow(hasUnplayed: Bool) -> some View {
        HStack(spacing: 18) {
            HaarShowWord(title: "Unplayed", selected: !showAll, size: 14, gap: 4) {
                withAnimation(LibraryStore.listChange) { showAll = false }
            }
            HaarShowWord(title: "All", selected: showAll, size: 14, gap: 4) {
                withAnimation(LibraryStore.listChange) { showAll = true }
            }
            Spacer(minLength: 8)
            if hasUnplayed {
                Button { confirmingMarkAll = true } label: {
                    Text("Mark all played")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func list(_ episodes: [PodcastEpisode], all: [PodcastEpisode]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(episodes.enumerated()), id: \.element.episodeID) { index, episode in
                HaarShowEpisodeRow(episode: episode, tint: tint, first: index == 0) {
                    markOlder(than: episode, in: all)
                }
            }
        }
        // The rows paint their own fill, so a swiped row slides off its
        // action block inside the card's rounded corners.
        .haarShowGroup(filled: false)
    }

    private func markOlder(than episode: PodcastEpisode, in all: [PodcastEpisode]) {
        let older: [PodcastEpisode] = all.filter { $0.published <= episode.published }
        store.undoable("Marked \(older.count) played", episodes: older) { store.markPlayed(older) }
    }
}

/// One episode: its state, title, length · download · time left, and a
/// play glyph. Tap plays (or pauses the one playing); hold for the menu;
/// swipe right Play next, left Played.
private struct HaarShowEpisodeRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    let tint: Color
    let first: Bool
    let markOlder: () -> Void

    var body: some View {
        let isCurrent: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let playingNow: Bool = isCurrent && player.isPlaying
        Button { tap(isCurrent: isCurrent) } label: {
            content(isCurrent: isCurrent, playingNow: playingNow)
        }
        .buttonStyle(.plain)
        .background { HaarShowCardFill() }
        .overlay(alignment: .top) {
            if !first { HaarShowHairline(inset: 16) }
        }
        .contentShape(.contextMenuPreview, Rectangle())
        .contextMenu {
            EpisodeMenuItems(episode: episode)
            Button("Mark this and older as played", systemImage: "text.badge.checkmark", action: markOlder)
        }
        .posterSwipe(leading: leadingSwipe, trailing: trailingSwipe)
        .accessibilityHint(playingNow ? "Pauses" : "Plays this episode")
    }

    private func tap(isCurrent: Bool) {
        if isCurrent {
            player.togglePlayPause()
        } else {
            player.play(episode)
        }
    }

    private func content(isCurrent: Bool, playingNow: Bool) -> some View {
        let state: (text: String, coloured: Bool) = stateLabel(isCurrent: isCurrent)
        let details: String = meta
        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.text)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(state.coloured ? tint : Theme.muted)
                Text(episode.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(episode.played && !isCurrent ? Theme.ink.opacity(0.55) : Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !details.isEmpty {
                    Text(details)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: playingNow ? "pause.circle" : "play.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(isCurrent ? tint : Theme.ink.opacity(0.8))
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    /// PLAYING NOW / IN UP NEXT / NEW in the show's colour; PLAYED or the
    /// date ("13 NOV") muted.
    private func stateLabel(isCurrent: Bool) -> (text: String, coloured: Bool) {
        if isCurrent { return ("PLAYING NOW", true) }
        if episode.played { return ("PLAYED", false) }
        if store.isQueued(episode) { return ("IN UP NEXT", true) }
        if episode.published > Date().addingTimeInterval(-7 * 86_400) { return ("NEW", true) }
        return (Self.dateLabel(episode.published), false)
    }

    static func dateLabel(_ date: Date) -> String {
        let sameYear: Bool = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        let style: Date.FormatStyle = sameYear
            ? .dateTime.day().month(.abbreviated)
            : .dateTime.day().month(.abbreviated).year()
        return date.formatted(style).uppercased()
    }

    /// "65 min · downloaded · 20 min left".
    private var meta: String {
        var parts: [String] = []
        if let duration = episode.duration, duration > 0 {
            parts.append("\(Self.minutes(duration)) min")
        }
        if let fraction = downloads.progress[episode.episodeID] {
            parts.append(fraction > 0 ? "downloading \(Int(fraction * 100))%" : "waiting to download")
        } else if episode.downloadFile != nil {
            parts.append("downloaded")
        }
        if !episode.played, episode.position > 30, let left = episode.timeLeft, left > 0 {
            parts.append("\(Self.minutes(left)) min left")
        }
        return parts.joined(separator: " · ")
    }

    private static func minutes(_ seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded()))
    }

    private var leadingSwipe: PosterSwipeAction {
        let episode = episode
        let store = store
        return PosterSwipeAction(title: "Play next", icon: "text.line.first.and.arrowtriangle.forward", colour: Poster.swipeAdd) {
            store.playNext(episode)
        }
    }

    private var trailingSwipe: PosterSwipeAction {
        let episode = episode
        let store = store
        if episode.played {
            return PosterSwipeAction(title: "Unplayed", icon: "circle", colour: Theme.muted) { store.markUnplayed(episode) }
        }
        return PosterSwipeAction(title: "Played", icon: "checkmark", colour: Poster.swipePlayed) {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }
}

// MARK: Shared with other files

private struct OpenShowSettingsKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct HaarGoHomeKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Set inside the Haar show sheet: the show page's settings key and
    /// "Show settings" menu item switch to its Settings page instead of
    /// opening another sheet.
    var openShowSettings: (() -> Void)? {
        get { self[OpenShowSettingsKey.self] }
        set { self[OpenShowSettingsKey.self] = newValue }
    }

    /// Set on Haar's Library layer: a swipe right on Library's first page
    /// goes back to Now.
    var haarGoHome: (() -> Void)? {
        get { self[HaarGoHomeKey.self] }
        set { self[HaarGoHomeKey.self] = newValue }
    }
}

/// A swipe to the right (only begins when the finger moves sideways, so
/// scrolling up and down isn't touched). Fires once it has gone 80 points
/// or is flicked.
struct SwipeRight: UIGestureRecognizerRepresentable {
    var isEnabled = true
    let action: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        let moved: CGFloat = recognizer.translation(in: nil).x
        let speed: CGFloat = recognizer.velocity(in: nil).x
        if moved > 80 || (moved > 30 && speed > 600) {
            action()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity: CGPoint = pan.velocity(in: nil)
            return velocity.x > 0 && velocity.x > abs(velocity.y) * 1.5
        }
    }
}
