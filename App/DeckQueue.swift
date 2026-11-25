import SwiftUI
import PodcastCore

// Shared by Up next's tabs, the bottom bar and an open tab's page: the
// page switch, Poddeck's mark, the queue worked out (count, done by) and
// what the swipes do to Up next.

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

/// "26m", "1h 12m" for Up next.
enum DeckUpNextTime {
    /// "26m", "1h 12m".
    static func length(_ seconds: TimeInterval) -> String {
        let minutes: Int = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

/// Up next worked out once per redraw: how many there are and when it's
/// all done at the current speed (the Tabs header's "n · done by").
@MainActor
struct DeckQueuePlan {
    /// What's playing, else the top of Up next.
    let top: PodcastEpisode?
    /// Every episode in Up next, in order (the one playing included).
    let all: [PodcastEpisode]
    /// When it's all done, at the current speed.
    let end: Date

    /// `playhead`: where the episode playing has got to, as a snapshot;
    /// nil uses its saved place.
    init(store: LibraryStore, player: PlayerModel, playhead: TimeInterval?) {
        let ids: [String] = store.queue.map(\.episode.id)
        let found: [String: PodcastEpisode] = store.episodes(ids)
        let queued: [PodcastEpisode] = ids.compactMap { found[$0] }
        let playing: String? = player.nowPlaying?.episodeID
        var topEpisode: PodcastEpisode? = queued.first
        if let playing { topEpisode = found[playing] ?? store.episode(playing) ?? topEpisode }
        let topID: String? = topEpisode?.episodeID
        let speedNow: Double = max(player.speed, 0.5)
        let rest: [PodcastEpisode] = queued.filter { $0.episodeID != topID }

        top = topEpisode
        all = queued

        // The top first (from now), then the rest in order.
        var clock: Date = Date()
        let order: [PodcastEpisode] = (topEpisode.map { [$0] } ?? []) + rest
        for episode in order {
            let left: TimeInterval = Self.left(episode, player: player, playhead: playhead) / speedNow
            clock = clock.addingTimeInterval(left)
        }
        end = clock
    }

    /// How many episodes there are (the one playing counts even when it
    /// isn't in Up next).
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
}

/// What the tabs' swipes and keys do to Up next. Every change offers Undo.
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

    /// Undo puts the played episode back on: Up next goes back as it was
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

    /// Play now (or pause / carry on if it's the one on).
    func playNow(_ episode: PodcastEpisode) {
        if player.nowPlaying?.episodeID == episode.episodeID {
            player.togglePlayPause()
        } else {
            player.play(episode)
        }
    }
}
