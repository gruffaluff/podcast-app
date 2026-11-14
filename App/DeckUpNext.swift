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

    var body: some View {
        let plan: DeckQueuePlan = DeckQueuePlan(store: store, player: player)
        VStack(spacing: 0) {
            DeckUpNextHeader(plan: plan, fanned: fanned,
                             fan: { openFan(plan) },
                             settings: { showingSettings = true })
            if fanned {
                DeckUpNextFan(plan: plan, close: closeFan)
                    .transition(.opacity)
            } else {
                deck(plan)
                    .transition(.opacity)
            }
        }
        .deckPage()
        .sheet(isPresented: $showingSettings) { settingsSheet }
        // "In Up next · 2nd" on an episode page opens the full list.
        .onChange(of: store.revealInUpNext, initial: true) { _, id in
            guard id != nil else { return }
            withAnimation(.easeOut(duration: 0.2)) { fanned = true }
        }
    }

    @ViewBuilder private func deck(_ plan: DeckQueuePlan) -> some View {
        if let top = plan.top {
            DeckStack(plan: plan, top: top, fan: { openFan(plan) })
        } else {
            DeckEmptyCard { selectTab(2) }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
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
            DeckMark(size: 26)
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

/// Poddeck's mark: three cards, blue back left, red back right, and a
/// white front card with an ink edge and an ink play triangle.
struct DeckMark: View {
    var size: CGFloat = 26

    var body: some View {
        let w: CGFloat = size * 0.4
        let h: CGFloat = size * 0.53
        let r: CGFloat = size * 0.09
        ZStack {
            card(Color(hex: 0x4C8DFF), w: w, h: h, r: r).rotationEffect(.degrees(-14))
            card(Color(hex: 0xFF5A45), w: w, h: h, r: r).rotationEffect(.degrees(10))
            front(w: w, h: h, r: r)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func card(_ colour: Color, w: CGFloat, h: CGFloat, r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(colour)
            .frame(width: w, height: h)
    }

    private func front(w: CGFloat, h: CGFloat, r: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        return shape.fill(Color.white)
            .overlay(shape.strokeBorder(Color(hex: 0x1C1B1A), lineWidth: max(1, size * 0.03)))
            .overlay {
                DeckPlayTriangle()
                    .fill(Color(hex: 0x1C1B1A))
                    .frame(width: w * 0.4, height: h * 0.38)
                    .offset(x: w * 0.04)
            }
            .frame(width: w, height: h)
    }
}

private struct DeckPlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - The deck

/// The top card with the next four peeking out under it, 48 points apart.
private struct DeckStack: View {
    let plan: DeckQueuePlan
    let top: PodcastEpisode
    let fan: () -> Void

    private static let edgeStep: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let cardHeight: CGFloat = Self.cardHeight(for: geometry.size.height)
            ZStack(alignment: .top) {
                edges(below: cardHeight)
                DeckTopCard(episode: top, plan: plan)
                    .frame(height: cardHeight)
                    .zIndex(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    /// 448 points on a big iPhone, shorter on small ones (at least 340).
    static func cardHeight(for available: CGFloat) -> CGFloat {
        min(448, max(340, available * 0.66))
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

/// One of the cards under the top one: artwork, title, show · Top and when
/// it starts at the current speed. Tap to fan the deck.
private struct DeckEdgeCard: View {
    let episode: PodcastEpisode
    let label: String
    let start: Date?
    /// The bottom card shows whole, so it's only as tall as its row (Paul,
    /// 14 Nov 2026: it was a big empty white card).
    var last: Bool = false
    let action: () -> Void

    var body: some View {
        let height: CGFloat = last ? 62 : 120
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let start {
                    Text(UpNextTimes.clock(start))
                        .font(Theme.outfit(12, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 2)
                }
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

    init(store: LibraryStore, player: PlayerModel) {
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

        // Starts: the top card first (from now), then the rest in order.
        var clock: Date = Date()
        var startMap: [String: Date] = [:]
        var seconds: TimeInterval = 0
        let order: [PodcastEpisode] = (topEpisode.map { [$0] } ?? []) + rest
        for episode in order {
            startMap[episode.episodeID] = clock
            let left: TimeInterval = Self.left(episode, player: player) / speedNow
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

    /// Episode time still to hear (live for the one playing).
    static func left(_ episode: PodcastEpisode, player: PlayerModel) -> TimeInterval {
        if player.nowPlaying?.episodeID == episode.episodeID, player.duration > 0 {
            return max(0, player.duration - player.currentTime)
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
            store.undoable(label, episodes: [episode]) { player.finishEarly() }
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
        player.play(next)
        if !wasPlaying { player.pause() }
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
