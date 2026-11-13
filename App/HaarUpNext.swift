import SwiftUI
import PodcastCore

/// Haar's Up next (prototype, Paul 13 Nov 2026): the same 76-point frosted
/// cards as the stack under the player, opened in place over the player
/// (the artwork goes to the corner, the cards fly in from the stack).
/// Hold a card to move it; swipe right to play next, left when played.

// MARK: - Card look

/// The frosted Up next card: white over a thin material, a fine white
/// edge and a soft shadow.
struct HaarQueueCardBackground: View {
    var radius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(Color.white.opacity(0.52)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.75), lineWidth: 1))
            .shadow(color: Color(hex: 0x1F2328).opacity(0.10), radius: 15, y: 10)
    }
}

extension View {
    /// Sits the view on Haar's frosted Up next card.
    func haarQueueCard(radius: CGFloat = 24) -> some View {
        background { HaarQueueCardBackground(radius: radius) }
    }
}

// MARK: - Card words

enum HaarQueueText {
    /// "47 min left", "1 h 12 min left".
    static func left(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let minutes: Int = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min left" }
        let rest: Int = minutes % 60
        return rest == 0 ? "\(minutes / 60) h left" : "\(minutes / 60) h \(rest) min left"
    }

    /// "47 min left · skips 2 ads · words ready" (time at the current
    /// speed; ads only when breaks are known; words only when ready or on
    /// their way).
    @MainActor
    static func meta(_ episode: PodcastEpisode, speed: Double, transcripts: TranscriptService) -> String {
        var parts: [String] = []
        let seconds: TimeInterval = episode.timeLeft ?? episode.duration ?? 0
        let time: String = left(seconds / max(speed, 0.5))
        if !time.isEmpty { parts.append(time) }
        let ads: Int = episode.adBreaksData == nil ? 0 : episode.adBreaks.count
        if ads > 0 { parts.append(ads == 1 ? "skips 1 ad" : "skips \(ads) ads") }
        switch episode.transcriptState {
        case .ready: parts.append("words ready")
        case .transcribing: parts.append("transcribing")
        case .waiting where transcripts.isQueued(episode): parts.append("transcribing")
        default: break
        }
        return parts.joined(separator: " · ")
    }

    /// "AUTO #2" for a ranked Top show, "AUTO" for other shows that add
    /// themselves, nothing for episodes added by hand.
    static func source(_ item: QueueItem, settings: QueueSettings) -> String? {
        guard item.source == .auto else { return nil }
        if settings.mode(for: item.episode.showID) == .top {
            let rank: Int = settings.rank(of: item.episode.showID)
            return rank == Int.max ? "AUTO" : "AUTO #\(rank + 1)"
        }
        return "AUTO"
    }
}

/// One Up next card's insides: artwork, a small label, the title on one
/// line and the meta line; an optional "#n" pill on the right.
struct HaarQueueCardContent: View {
    let episode: PodcastEpisode
    let label: String
    let labelColour: Color
    let meta: String
    var rank: Int?
    var rankColour: Color = .clear

    var body: some View {
        HStack(spacing: 12) {
            artwork
            texts
            Spacer(minLength: 0)
            if let rank { rankPill(rank) }
        }
        .padding(.horizontal, 12)
        .frame(height: 76)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var artwork: some View {
        Color.clear
            .frame(width: 52, height: 52)
            .overlay {
                CachedImage(url: episode.artwork) { Theme.placeholderColor(for: episode.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .accessibilityHidden(true)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(labelColour)
                .lineLimit(1)
            Text(episode.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
    }

    private func rankPill(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .frame(minWidth: 30, minHeight: 22)
            .background(Capsule().fill(rankColour))
            .accessibilityLabel("Number \(rank) in Up next")
    }
}

// MARK: - Up next stack (under the player)

/// What's up next under the player: the front card with two card edges
/// peeking above it; tap (or swipe up on the player) for all of Up next.
struct HaarUpNextStack: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    let open: () -> Void
    let openFind: () -> Void
    /// With nothing playing, the first in Up Next is already shown big.
    var skipFirst = false

    static let height: CGFloat = 100

    var body: some View {
        let playingID: String? = player.nowPlaying?.episodeID
        let waiting: [QueueItem] = store.queue.filter { $0.episode.id != playingID }
        let shown: [QueueItem] = Array(waiting.dropFirst(skipFirst ? 1 : 0))
        let next: PodcastEpisode? = shown.first.flatMap { store.episode($0.episode.id) }
        if let next {
            Button(action: open) { stack(next: next, count: shown.count) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Up next: \(next.title). \(shown.count) waiting")
                .accessibilityHint("Opens Up next")
        } else if !skipFirst {
            empty
        }
    }

    private func stack(next: PodcastEpisode, count: Int) -> some View {
        ZStack(alignment: .bottom) {
            if count > 2 {
                peek.scaleEffect(0.88).offset(y: -24).opacity(0.3)
            }
            if count > 1 {
                peek.scaleEffect(0.94).offset(y: -12).opacity(0.6)
            }
            HaarQueueCardContent(episode: next,
                                 label: "UP NEXT · SWIPE UP FOR ALL \(count)",
                                 labelColour: Theme.accentText,
                                 meta: HaarQueueText.meta(next, speed: player.speed, transcripts: transcripts))
                .haarQueueCard()
        }
        .frame(height: Self.height, alignment: .bottom)
    }

    private var peek: some View {
        Color.clear
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .haarQueueCard()
    }

    private var empty: some View {
        Button(action: openFind) {
            HStack(spacing: 6) {
                Text("Up next is empty")
                    .foregroundStyle(Theme.muted)
                Text("·")
                    .foregroundStyle(Theme.muted)
                Text("Find something")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accentText)
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Up next, opened in place

/// All of Up next over the player (not the episode playing): a serif
/// heading with the count and when it clears, then the cards. Hold a card
/// to move it, swipe right to play next, left when played (both with
/// Undo). Keep playing new episodes at the end. Swipe down on the heading
/// (or right) to go back.
struct HaarUpNextList: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let close: () -> Void
    let openFind: () -> Void

    /// The cards fly in from the stack, one after another.
    @State private var appeared = false

    static let playedColour = Color(hex: 0x6B7178)

    var body: some View {
        let playingID: String? = player.nowPlaying?.episodeID
        let waiting: [QueueItem] = store.queue.filter { $0.episode.id != playingID }
        let episodes: [String: PodcastEpisode] = store.episodes(store.queue.map(\.episode.id))
        VStack(alignment: .leading, spacing: 0) {
            heading(waiting: waiting, episodes: episodes, playingID: playingID)
            list(waiting: waiting, episodes: episodes)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                // A beat later, so the cards rise from where the stack was.
                DispatchQueue.main.async { appeared = true }
            }
        }
    }

    // MARK: Heading

    private func heading(waiting: [QueueItem], episodes: [String: PodcastEpisode], playingID: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Up next")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(summary(waiting: waiting, episodes: episodes, playingID: playingID))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Text("Hold a card to move it · swipe right to play next, left when played")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(headingSwipe)
        .accessibilityAction(named: "Back to the player", close)
    }

    /// Down or right on the heading goes back to the player.
    private var headingSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dx: CGFloat = value.translation.width
                let dy: CGFloat = value.translation.height
                if dy > 48 || dx > 48 { close() }
            }
    }

    /// "5 episodes · clears by 17:28" (at the current speed, after what's
    /// playing now).
    private func summary(waiting: [QueueItem], episodes: [String: PodcastEpisode], playingID: String?) -> String {
        let count: Int = waiting.count
        let words: String = count == 1 ? "1 episode" : "\(count) episodes"
        let lengths: [TimeInterval] = UpNextView.lengths(of: waiting, episodes: episodes)
        let playingLeft: TimeInterval = playingID.flatMap { episodes[$0]?.timeLeft } ?? 0
        let total: TimeInterval = lengths.reduce(0, +) + playingLeft
        guard total > 0, count > 0 else { return words }
        let clears: Date = Date().addingTimeInterval(total / max(player.speed, 0.5))
        return words + " · clears by " + UpNextTimes.clock(clears)
    }

    // MARK: Cards

    private func list(waiting: [QueueItem], episodes: [String: PodcastEpisode]) -> some View {
        List {
            ForEach(Array(waiting.enumerated()), id: \.element.episode.id) { index, item in
                if let episode = episodes[item.episode.id] {
                    row(index: index, item: item, episode: episode)
                }
            }
            .onMove { from, to in move(from: from, to: to, waiting: waiting) }
            if waiting.isEmpty {
                emptyRow
            }
            keepPlayingRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private func row(index: Int, item: QueueItem, episode: PodcastEpisode) -> some View {
        let colour: Color = showColour(episode)
        let showName: String = episode.podcast?.title ?? episode.showTitle
        let source: String? = HaarQueueText.source(item, settings: store.queueSettings)
        let label: String = (source.map { showName + " · " + $0 } ?? showName).uppercased()
        let delay: Double = Double(min(index, 12)) * 0.045
        return HaarQueueCardContent(episode: episode, label: label, labelColour: colour,
                                    meta: HaarQueueText.meta(episode, speed: player.speed, transcripts: transcripts),
                                    rank: index + 1, rankColour: colour)
            .haarQueueCard()
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture { play(episode) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Plays it now")
            .posterSwipe(leading: playNextAction(episode), trailing: playedAction(episode))
            .offset(y: appeared ? 0 : 240 + CGFloat(index) * 14)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : HaarNowView.morph.delay(delay), value: appeared)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4.5, leading: 20, bottom: 4.5, trailing: 20))
            .task(id: episode.podcast?.artworkURL) { await ArtworkColors.shared.load(episode.podcast?.artworkURL) }
    }

    /// The show's own colour when it's been measured, else the accent.
    private func showColour(_ episode: PodcastEpisode) -> Color {
        ArtworkColors.shared.background(for: episode.podcast?.artworkURL) ?? Theme.accentText
    }

    private func playNextAction(_ episode: PodcastEpisode) -> PosterSwipeAction {
        PosterSwipeAction(title: "Play next", icon: "text.line.first.and.arrowtriangle.forward", colour: Theme.accentFill) {
            store.undoable("Moved to play next", episodes: []) { store.playNext(episode) }
        }
    }

    private func playedAction(_ episode: PodcastEpisode) -> PosterSwipeAction {
        PosterSwipeAction(title: "Played", icon: "checkmark", colour: Self.playedColour) {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }

    private func play(_ episode: PodcastEpisode) {
        player.play(episode)
        close()
    }

    /// Moves within the cards shown (the episode playing is left out), as
    /// places in the whole of Up Next.
    private func move(from source: IndexSet, to destination: Int, waiting: [QueueItem]) {
        let ids: [String] = store.queue.map(\.episode.id)
        var full = IndexSet()
        for index in source where waiting.indices.contains(index) {
            if let place = ids.firstIndex(of: waiting[index].episode.id) { full.insert(place) }
        }
        guard !full.isEmpty else { return }
        let target: Int
        if destination < waiting.count {
            target = ids.firstIndex(of: waiting[destination].episode.id) ?? ids.count
        } else {
            let last: Int? = waiting.last.flatMap { ids.firstIndex(of: $0.episode.id) }
            target = (last ?? ids.count - 1) + 1
        }
        store.moveQueue(from: full, to: target)
    }

    private var emptyRow: some View {
        Button(action: openFind) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing waiting")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("Find something")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .haarQueueCard()
        }
        .buttonStyle(.plain)
        .moveDisabled(true)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4.5, leading: 20, bottom: 4.5, trailing: 20))
    }

    private var keepPlayingRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep playing new episodes")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("When Up next runs out, carry on with this week's")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Toggle("Keep playing new episodes", isOn: Binding(get: { store.keepPlayingNew }, set: { store.keepPlayingNew = $0 }))
                .labelsHidden()
                .tint(Theme.accentFill)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .haarQueueCard(radius: 20)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : HaarNowView.morph.delay(0.2), value: appeared)
        .moveDisabled(true)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 24, trailing: 20))
    }
}
