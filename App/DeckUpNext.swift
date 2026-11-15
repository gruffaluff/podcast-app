import SwiftUI
import PodcastCore

// Deck: Up next (Paul, 14 Nov 2026: "I love it"). Prototype:
// design/deck/poddeck-prototype.html (topCard, renderDeck, renderFan).
// Up next is a deck of episode cards. The top card is the episode playing
// (or the top of Up next, paused); the next four peek out under it. Swipe
// the top card left when heard, right a little to put it next in line,
// right all the way to send it to the bottom. Tap the deck's edges (or
// the "n · done by" words) to fan it out into the full list.

/// Switches Deck's page (0 Up next, 1 Shows, 2 Find). DeckRoot sets it.
private struct DeckSelectTabKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    var deckSelectTab: (Int) -> Void {
        get { self[DeckSelectTabKey.self] }
        set { self[DeckSelectTabKey.self] = newValue }
    }
}

struct DeckUpNextView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.deckSelectTab) private var selectTab

    @State private var fanned = false
    @State private var showingSettings = false
    /// Up next suggestions, worked out when Up next or what's playing
    /// changes (not on every redraw). Empty unless Up next is nearly out.
    @State private var suggestions: [PodcastEpisode] = []
    /// Smoother scrolling (Paul, 15 Nov 2026): where the episode playing
    /// had got to, refreshed every 10 seconds (and on a jump or a new
    /// episode) by `DeckPlayheadWatch`. Reading the player's clock here
    /// redrew the whole of Up next, fan list included, and fetched every
    /// episode again twice a second. The top card and the playing row
    /// still follow the clock themselves.
    @State private var playhead: TimeInterval?

    var body: some View {
        let plan: DeckQueuePlan = DeckQueuePlan(store: store, player: player, playhead: playhead)
        VStack(spacing: 0) {
            DeckUpNextHeader(plan: plan, fanned: fanned,
                             fan: { openFan(plan) },
                             settings: { showingSettings = true })
            if fanned {
                DeckUpNextFan(plan: plan, suggestions: suggestions, close: closeFan)
                    .transition(.opacity)
            } else {
                deck(plan)
                    .transition(.opacity)
            }
        }
        .deckPage()
        .background { DeckPlayheadWatch { playhead = $0 } }
        .sheet(isPresented: $showingSettings) { settingsSheet }
        // "In Up next · 2nd" on an episode page opens the full list.
        .onChange(of: store.revealInUpNext, initial: true) { _, id in
            guard id != nil else { return }
            withAnimation(.easeOut(duration: 0.2)) { fanned = true }
        }
        .onChange(of: suggestionKey, initial: true) { _, _ in reloadSuggestions() }
        .onChange(of: store.lastChecked) { _, _ in reloadSuggestions() }
    }

    // Up next suggestions (Paul, 15 Nov 2026).

    /// What the suggestions depend on: Up next's order and what's playing.
    private var suggestionKey: [String] {
        store.queue.map(\.episode.id) + [player.nowPlaying?.episodeID ?? ""]
    }

    /// Suggestions only when one episode or none is left after the one
    /// playing (or after the top card, when nothing plays).
    private func reloadSuggestions() {
        let ids: [String] = store.queue.map(\.episode.id)
        let playing: String? = player.nowPlaying?.episodeID
        let left: Int = playing.map { id in ids.filter { $0 != id }.count } ?? max(0, ids.count - 1)
        guard left <= 1 else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }
        suggestions = store.deckSuggestions(excluding: playing)
    }

    @ViewBuilder private func deck(_ plan: DeckQueuePlan) -> some View {
        if let top = plan.top {
            DeckStack(plan: plan, top: top, suggestions: suggestions, fan: { openFan(plan) })
        } else if suggestions.isEmpty {
            DeckEmptyCard { selectTab(2) }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            // Empty, with suggestions under the card: scrolls if they don't fit.
            ScrollView {
                VStack(spacing: 16) {
                    DeckEmptyCard { selectTab(2) }
                    DeckSuggestionsSection(episodes: suggestions)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func openFan(_ plan: DeckQueuePlan) {
        guard plan.top != nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { fanned = true }
    }

    private func closeFan() {
        withAnimation(.easeOut(duration: 0.2)) { fanned = false }
    }

    private var settingsSheet: some View {
        // DeckSettingsView has its own navigation and Done button.
        DeckSettingsView()
    }
}

// MARK: - Header

/// The deck mark and "Poddeck"; on the right "6 · done by 21:25" (tap to
/// fan the deck) and the settings gear.
private struct DeckUpNextHeader: View {
    let plan: DeckQueuePlan
    let fanned: Bool
    let fan: () -> Void
    let settings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            DeckMark(size: 30)
            Text("Poddeck")
                .font(Theme.outfit(26, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !fanned && plan.count > 0 { countButton }
            gear
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .padding(.top, 8)
        .frame(height: 52)
    }

    private var countButton: some View {
        Button(action: fan) {
            Text("\(plan.count) · done by " + UpNextTimes.clock(plan.end))
                .font(Theme.outfit(13, .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows all of Up next")
    }

    private var gear: some View {
        Button(action: settings) {
            Image(systemName: "gearshape")
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

/// Poddeck's mark, the app icon "E · P card" (Paul, 14 Nov 2026; this was
/// still icon A's three cards until 15 Nov): a white P on an ink card with
/// a coral card tilted behind it. Measured off icon_deck_ep.svg.
struct DeckMark: View {
    var size: CGFloat = 26

    var body: some View {
        let k: CGFloat = size / 70
        ZStack {
            RoundedRectangle(cornerRadius: 9 * k, style: .continuous)
                .fill(Color(hex: 0xEC6550))
                .frame(width: 48 * k, height: 64 * k)
                .rotationEffect(.degrees(8))
                .offset(x: 4 * k, y: 2 * k)
            RoundedRectangle(cornerRadius: 9 * k, style: .continuous)
                .fill(Color(hex: 0x1E1D1B))
                .frame(width: 48 * k, height: 64 * k)
                .overlay {
                    Text("P")
                        .font(Theme.outfit(46 * k, .heavy))
                        .foregroundStyle(Color.white)
                        .offset(x: 0.5 * k, y: 1 * k)
                }
                .offset(x: -6 * k, y: -3 * k)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - The deck

/// The top card with the next four peeking out under it, 48 points apart.
private struct DeckStack: View {
    let plan: DeckQueuePlan
    let top: PodcastEpisode
    /// Up next suggestions to show under the deck (empty when there's
    /// enough in Up next).
    let suggestions: [PodcastEpisode]
    let fan: () -> Void

    private static let edgeStep: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let layout: DeckStackLayout = DeckStackLayout(available: geometry.size.height,
                                                          restCount: plan.rest.count,
                                                          suggestions: suggestions.count)
            let cardHeight: CGFloat = layout.cardHeight
            ZStack(alignment: .top) {
                edges(below: cardHeight)
                DeckTopCard(episode: top, plan: plan)
                    .frame(height: cardHeight)
                    .zIndex(10)
                if layout.fitting > 0 {
                    DeckSuggestionsSection(episodes: Array(suggestions.prefix(layout.fitting)))
                        .offset(y: layout.suggestionsTop)
                        .zIndex(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        // Paul, 15 Nov 2026: swipe up on the deck to fan out the whole of
        // Up next (tapping the cards under the top one still does too).
        // The top card's own sideways swipes only start when moving
        // sideways, so they don't clash.
        .contentShape(Rectangle())
        .simultaneousGesture(swipeUp)
    }

    private var swipeUp: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onEnded { (value: DragGesture.Value) in
                let up: CGFloat = -value.translation.height
                let sideways: CGFloat = abs(value.translation.width)
                let flick: Bool = -value.predictedEndTranslation.height > 120
                guard up > sideways, up > 40 || flick else { return }
                fan()
            }
    }

    /// 448 points on a big iPhone, shorter on small ones (at least 340).
    static func cardHeight(for available: CGFloat) -> CGFloat {
        min(448, max(340, available * 0.66))
    }

    /// How far the edges under the top card reach below it.
    static func edgesRoom(restCount: Int) -> CGFloat {
        guard restCount > 0 else { return 0 }
        // 14 pt gap, a 48 pt step per card but the last, which shows 84 pt whole.
        let shown: Int = min(restCount, 4)
        return 14 + CGFloat(shown - 1) * edgeStep + 84
    }

    private func edges(below cardHeight: CGFloat) -> some View {
        let rest: [PodcastEpisode] = Array(plan.rest.prefix(4))
        return ZStack(alignment: .top) {
            ForEach(Array(rest.enumerated()), id: \.element.episodeID) { index, episode in
                DeckEdgeCard(episode: episode,
                             label: plan.label(for: episode),
                             start: plan.starts[episode.episodeID],
                             last: index == rest.count - 1,
                             action: fan)
                    .offset(y: cardHeight + 14 + CGFloat(index) * Self.edgeStep)
                    .zIndex(Double(index + 1))
            }
        }
    }
}

/// Where the top card and the suggestions under the deck go: the top card
/// gives up some height (down to 340 pt) so up to three suggestions fit
/// above the tab pill; any that still don't fit are left for the full list.
private struct DeckStackLayout {
    let cardHeight: CGFloat
    let fitting: Int
    let suggestionsTop: CGFloat

    init(available: CGFloat, restCount: Int, suggestions: Int) {
        let natural: CGFloat = DeckStack.cardHeight(for: available)
        let edges: CGFloat = DeckStack.edgesRoom(restCount: restCount)
        // 8 pt above the deck, 16 pt above the suggestions, the pill below.
        let fixed: CGFloat = 8 + edges + 16 + DeckRoot.pillRoom
        guard suggestions > 0 else {
            cardHeight = natural
            fitting = 0
            suggestionsTop = 0
            return
        }
        let wanted: CGFloat = DeckSuggestionsSection.height(for: suggestions)
        let card: CGFloat = min(natural, max(340, available - fixed - wanted))
        var count: Int = suggestions
        while count > 0 && card + fixed + DeckSuggestionsSection.height(for: count) > available {
            count -= 1
        }
        cardHeight = card
        fitting = count
        suggestionsTop = card + edges + 16
    }
}

/// One of the cards under the top one: artwork, title, show · Top and when
/// it starts at the current speed. Tap to fan the deck.
private struct DeckEdgeCard: View {
    let episode: PodcastEpisode
    let label: String
    let start: Date?
    /// The bottom card shows whole, so it's shorter than the others (Paul,
    /// 14 Nov 2026: it was a big empty white card), but still a little
    /// taller than the 72 pt of the card above that shows below the step,
    /// so that card's foot never pokes out under it (build 156 screenshot).
    /// It has a third line (date · length) and the DL / TX letters, so its
    /// room isn't empty (Paul, 15 Nov 2026).
    var last: Bool = false
    let action: () -> Void

    var body: some View {
        let height: CGFloat = last ? 84 : 120
        return Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                DeckUpNextArtwork(episode: episode, size: 34, radius: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(episode.title)
                        .font(Theme.outfit(15, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(label)
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    if last {
                        Text(detail)
                            .font(Theme.outfit(12, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted.opacity(0.8))
                            .lineLimit(1)
                            .padding(.top, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                    if let start {
                        Text(UpNextTimes.clock(start))
                            .font(Theme.outfit(12, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                    }
                    if last {
                        EpisodeLights(episode: episode)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(edgeShape.fill(Theme.surface))
            .overlay(edgeShape.strokeBorder(Theme.cardEdge, lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.07), radius: 8, y: -6)
            .contentShape(edgeShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(episode.title + ", " + label)
        .accessibilityHint("Shows all of Up next")
    }

    private var edgeShape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    /// The bottom card's third line (Paul, 15 Nov 2026: fill its space):
    /// "9 Nov · 52m", or "9 Nov · 12m left" once started.
    private var detail: String {
        let date: String = episode.published.formatted(.dateTime.day().month(.abbreviated))
        guard let duration = episode.duration, duration > 0 else { return date }
        let left: TimeInterval = episode.timeLeft ?? duration
        let started: Bool = episode.position > 30 && left > 0
        let time: String = started
            ? DeckUpNextTime.length(left) + " left"
            : DeckUpNextTime.length(duration)
        return date + " · " + time
    }
}

/// Nothing in Up next.
private struct DeckEmptyCard: View {
    let find: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            DeckMark(size: 70).opacity(0.6)
            Text("The deck is empty")
                .font(Theme.outfit(24, .heavy))
                .foregroundStyle(Theme.ink)
            Text("New episodes from your shows are dealt in as they arrive.")
                .font(Theme.outfit(14, .medium))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button(action: find) {
                Text("Find something")
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .frame(height: 448)
        .deckPlainCard(radius: 28)
    }
}

/// Episode artwork, rounded, with the show's placeholder colour until it loads.
struct DeckUpNextArtwork: View {
    let episode: PodcastEpisode
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay {
                CachedImage(url: episode.artwork) { Theme.placeholderColor(for: episode.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Times and labels

/// Reports where the episode playing has got to every 10 seconds, on a
/// jump and when the episode changes. Only this empty view follows the
/// player's clock (twice a second), so Up next itself redraws rarely.
private struct DeckPlayheadWatch: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.deckPageShown) private var pageShown
    let changed: (TimeInterval) -> Void

    var body: some View {
        let id: String = player.nowPlaying?.episodeID ?? ""
        // Hidden behind Shows or Find: no need to follow the clock at all.
        let step: String = pageShown ? String(Int(player.currentTime / 10)) : "hidden"
        let key: String = id + "|" + step
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: key, initial: true) { _, _ in changed(player.currentTime) }
            .accessibilityHidden(true)
    }
}

/// Up next worked out once per redraw: the top card, the rest, when each
/// starts at the current speed and when it's all done.
@MainActor
struct DeckQueuePlan {
    /// The top card: what's playing, else the top of Up next.
    let top: PodcastEpisode?
    /// Up next after the top card, in order.
    let rest: [PodcastEpisode]
    /// Every episode in Up next, in order (the one playing included).
    let all: [PodcastEpisode]
    let items: [String: QueueItem]
    let starts: [String: Date]
    let end: Date
    /// Time to listen to it all, at the current speed.
    let total: TimeInterval
    let speed: Double
    let playingID: String?
    let settings: QueueSettings
    /// The snapshot of where the episode playing had got to.
    let playhead: TimeInterval?

    /// `playhead`: where the episode playing has got to, as a snapshot
    /// (see `DeckUpNextView.playhead`); nil uses its saved place.
    init(store: LibraryStore, player: PlayerModel, playhead: TimeInterval?) {
        let ids: [String] = store.queue.map(\.episode.id)
        let found: [String: PodcastEpisode] = store.episodes(ids)
        let queued: [PodcastEpisode] = ids.compactMap { found[$0] }
        let playing: String? = player.nowPlaying?.episodeID
        var topEpisode: PodcastEpisode? = queued.first
        if let playing { topEpisode = found[playing] ?? store.episode(playing) ?? topEpisode }
        let topID: String? = topEpisode?.episodeID
        var itemMap: [String: QueueItem] = [:]
        for item in store.queue { itemMap[item.episode.id] = item }
        let speedNow: Double = max(player.speed, 0.5)

        top = topEpisode
        rest = queued.filter { $0.episodeID != topID }
        all = queued
        items = itemMap
        speed = speedNow
        playingID = playing
        settings = store.queueSettings
        self.playhead = playhead

        // Starts: the top card first (from now), then the rest in order.
        var clock: Date = Date()
        var startMap: [String: Date] = [:]
        var seconds: TimeInterval = 0
        let order: [PodcastEpisode] = (topEpisode.map { [$0] } ?? []) + rest
        for episode in order {
            startMap[episode.episodeID] = clock
            let left: TimeInterval = Self.left(episode, player: player, playhead: playhead) / speedNow
            clock = clock.addingTimeInterval(left)
            seconds += left
        }
        starts = startMap
        end = clock
        total = seconds
    }

    /// How many episodes are in the deck (the one playing counts even when
    /// it isn't in Up next).
    var count: Int {
        guard let topID = top?.episodeID else { return all.count }
        let inQueue: Bool = all.contains(where: { $0.episodeID == topID })
        return inQueue ? all.count : all.count + 1
    }

    /// Time still to hear from a snapshot of the playhead (doesn't read
    /// the player's clock, so the view asking isn't redrawn by it).
    static func left(_ episode: PodcastEpisode, player: PlayerModel, playhead: TimeInterval?) -> TimeInterval {
        if let playhead, player.nowPlaying?.episodeID == episode.episodeID, player.duration > 0 {
            return max(0, player.duration - playhead)
        }
        return episode.timeLeft ?? episode.duration ?? 0
    }

    func isTop(_ episode: PodcastEpisode) -> Bool {
        settings.mode(for: episode.queueEpisode.showID) == .top
    }

    /// "Show · Top" for a Top show, else just the show.
    func label(for episode: PodcastEpisode) -> String {
        isTop(episode) ? episode.showTitle + " · Top" : episode.showTitle
    }
}

// MARK: - Moves (shared by the top card and the fanned list)

/// What the swipes do to Up next. Every change offers Undo.
@MainActor
struct DeckQueueMoves {
    let store: LibraryStore
    let player: PlayerModel

    /// Heard: marked played (the one playing finishes as if it ended).
    func played(_ episode: PodcastEpisode) {
        let label: String = "Played: " + episode.title
        if player.nowPlaying?.episodeID == episode.episodeID {
            let wasPlaying: Bool = player.isPlaying
            store.undoable(label, episodes: [episode]) { player.finishEarly() }
            comesBackOnTop(episode, playing: wasPlaying)
        } else {
            store.undoable(label, episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }

    /// Whether there's another episode to bring up in its place.
    func canMoveTop(_ episode: PodcastEpisode) -> Bool {
        store.queue.contains { $0.episode.id != episode.episodeID }
    }

    /// The top card goes second ("next in line") or to the bottom, placed
    /// by hand; the new top of Up next takes its place (playing if the old
    /// one was).
    func moveTop(_ episode: PodcastEpisode, toBottom: Bool) {
        guard canMoveTop(episode) else { return }
        let label: String = toBottom ? "Moved to the bottom" : "Back after the next one"
        let wasCurrent: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let wasPlaying: Bool = wasCurrent && player.isPlaying
        store.undoable(label, episodes: []) {
            var queue: [QueueItem] = store.queue.filter { $0.episode.id != episode.episodeID }
            let moved = QueueItem(episode: episode.queueEpisode, source: .manual)
            queue.insert(moved, at: toBottom ? queue.count : min(1, queue.count))
            store.commit(queue)
        }
        guard wasCurrent, let first = store.queue.first, let next = store.episode(first.episode.id) else { return }
        player.play(next, autoplay: wasPlaying)
        comesBackOnTop(episode, playing: wasPlaying)
    }

    /// Undo puts the swiped card back on top: Up next goes back as it was
    /// and the player loads that episode again where it was, playing if it
    /// was (Paul, 15 Nov 2026: after Undo it only rejoined the queue and
    /// the next episode stayed on top).
    private func comesBackOnTop(_ episode: PodcastEpisode, playing: Bool) {
        guard let undo = store.undoAction else { return }
        let id: String = episode.episodeID
        let store: LibraryStore = store
        let player: PlayerModel = player
        store.undoAction = UndoAction(label: undo.label) {
            undo.restore()
            guard let back = store.episode(id) else { return }
            player.play(back, autoplay: playing)
        }
    }

    /// Plays next, straight after the episode playing.
    func playNext(_ episode: PodcastEpisode) {
        store.undoable("Plays next", episodes: []) { store.playNext(episode) }
    }

    /// To the bottom of Up next, placed by hand.
    func toBottom(_ episode: PodcastEpisode) {
        store.undoable("Moved to the bottom", episodes: []) {
            var queue: [QueueItem] = store.queue.filter { $0.episode.id != episode.episodeID }
            queue.append(QueueItem(episode: episode.queueEpisode, source: .manual))
            store.commit(queue)
        }
    }

    /// Play now (or pause / carry on if it's the one on).
    func playNow(_ episode: PodcastEpisode) {
        if player.nowPlaying?.episodeID == episode.episodeID {
            player.togglePlayPause()
        } else {
            player.play(episode)
        }
    }
}
