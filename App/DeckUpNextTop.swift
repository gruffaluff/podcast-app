import SwiftUI
import UIKit
import PodcastCore

// Deck's top card (prototype: topCard, swipe / zoneOf / swiped). It follows
// the finger and tilts; a stamp says what letting go will do:
// left past 90 points PLAYED, right 90-200 NEXT IN LINE, right past 200
// TO THE BOTTOM. Under 90 it springs back. A tick under the finger at
// each line.

/// Where a sideways swipe has got to.
enum DeckUpNextSwipeZone: Equatable {
    case left, near, far

    static let line: CGFloat = 90
    static let farLine: CGFloat = 200

    static func of(_ dx: CGFloat, allowRight: Bool = true) -> DeckUpNextSwipeZone? {
        if dx <= -line { return .left }
        guard allowRight else { return nil }
        if dx >= farLine { return .far }
        if dx >= line { return .near }
        return nil
    }

    static let green = Color(hex: 0x1F8A4A)
    static let blue = Color(hex: 0x2F6FE0)
}

/// What the top card shows, worked out once per redraw.
struct DeckTopInfo {
    let episode: PodcastEpisode
    let isCurrent: Bool
    let isPlaying: Bool
    let time: TimeInterval
    let duration: TimeInterval
    let ads: [AdBreak]
    let chapter: String?
    let colour: Color
    let speed: Double

    var left: TimeInterval { max(0, duration - time) }
    var fraction: Double { duration > 0 ? min(1, max(0, time / duration)) : 0 }
    var showLine: String { chapter.map { episode.showTitle + " · " + $0 } ?? episode.showTitle }
    var dark: Color { colour.mix(with: .black, by: 0.45) }

    /// "34m left" at the current speed.
    var leftWords: String {
        let minutes: Int = max(1, Int((left / max(speed, 0.5) / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes)m left" }
        return "\(minutes / 60)h \(minutes % 60)m left"
    }
}

enum DeckUpNextTime {
    /// "16:40", "1:02:03".
    static func stamp(_ seconds: TimeInterval) -> String {
        let total: Int = max(0, Int(seconds.rounded()))
        let h: Int = total / 3600
        let m: Int = total % 3600 / 60
        let s: Int = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// "26m", "1h 12m".
    static func length(_ seconds: TimeInterval) -> String {
        let minutes: Int = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

struct DeckTopCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.deckOpenPlayer) private var openPlayer
    @AppStorage(DeckLayout.key) private var layoutRaw: String = DeckLayout.standard.rawValue
    /// Artwork or the words being said in the top card's picture area
    /// (Paul, 14 Nov 2026: "a button to switch between artwork and transcript").
    @AppStorage("deckTopWords") private var showWords = false

    let episode: PodcastEpisode
    let plan: DeckQueuePlan

    @State private var offset: CGFloat = 0
    @State private var zone: DeckUpNextSwipeZone?
    @State private var showingOptions = false
    @State private var lines: [TranscriptLayout.Line] = []

    private var moves: DeckQueueMoves { DeckQueueMoves(store: store, player: player) }

    private var layout: DeckLayout {
        let chosen: DeckLayout = DeckLayout(rawValue: layoutRaw) ?? .standard
        // Read along with no words yet shows the standard card.
        return chosen == .read && lines.isEmpty ? .standard : chosen
    }

    var body: some View {
        let info: DeckTopInfo = makeInfo()
        cardContent(info)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { cardBackground }
            // Paul, 14 Nov 2026: tap anywhere on the card for the player
            // (its own keys still do their own thing).
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture { open() }
            .accessibilityHint("Opens the player")
            .overlay(alignment: .topTrailing) { adChip.padding(28) }
            .overlay(alignment: .topTrailing) { playedStamp }
            .overlay(alignment: .topLeading) { moveStamp }
            .offset(x: offset)
            .rotationEffect(.degrees(Double(offset / 22)))
            .gesture(DeckUpNextPan(isEnabled: true, changed: moved, ended: released))
            .accessibilityActions { accessibilityMoves }
            .sheet(isPresented: $showingOptions) { PlayerOptionsSheet() }
            .task(id: lineKey) { loadLines() }
            .task(id: episode.podcast?.artworkURL) { await ArtworkColors.shared.load(episode.podcast?.artworkURL) }
            // The player's colour comes from the episode's own artwork:
            // measure it ahead so the player opens in colour, not dark grey.
            .task(id: episode.artwork) { await ArtworkColors.shared.load(episode.artwork) }
    }

    // MARK: Look

    @ViewBuilder private func cardContent(_ info: DeckTopInfo) -> some View {
        let actions = DeckTopActions(play: play, open: open, options: { showingOptions = true },
                                     toggleWords: { showWords.toggle() })
        let words = DeckTopWords(showing: showWords, line: currentLine(info), ready: !lines.isEmpty)
        switch layout {
        case .standard: DeckStandardTop(info: info, actions: actions, calm: false, words: words)
        case .calm: DeckStandardTop(info: info, actions: actions, calm: true, words: words)
        case .big: DeckBigTop(info: info, actions: actions)
        case .read: DeckReadTop(info: info, actions: actions, line: currentLine(info))
        }
    }

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let fill: Color = layout == .calm ? Theme.surface.mix(with: Theme.background, by: 0.45) : Theme.surface
        return shape.fill(fill)
            .overlay(shape.strokeBorder(Theme.cardEdge, lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.16), radius: 20, y: 18)
    }

    private func makeInfo() -> DeckTopInfo {
        let current: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let duration: TimeInterval = current && player.duration > 0 ? player.duration : (episode.duration ?? 0)
        let time: TimeInterval = current ? player.currentTime : episode.position
        let ads: [AdBreak] = current ? player.adBreaks : episode.adBreaks
        var chapter: String?
        if current, let index = player.currentChapterIndex, player.chapters.indices.contains(index) {
            chapter = player.chapters[index].title
        }
        let artURL: URL? = episode.podcast?.artworkURL ?? episode.artwork
        let colour: Color = ArtworkColors.shared.background(for: artURL) ?? Theme.placeholderColor(for: episode.showTitle)
        return DeckTopInfo(episode: episode, isCurrent: current, isPlaying: current && player.isPlaying,
                           time: time, duration: duration, ads: ads, chapter: chapter,
                           colour: colour, speed: player.speed)
    }

    private func play() {
        moves.playNow(episode)
    }

    /// Opens the full player on this episode. When nothing is loaded yet
    /// (e.g. just after opening the app) it's loaded first, ready to play
    /// but not started: the player closed itself with nothing loaded, which
    /// showed as a brief black screen (Paul, 14 Nov 2026).
    private func open() {
        if player.nowPlaying?.episodeID != episode.episodeID {
            player.play(episode, autoplay: false)
        }
        openPlayer()
    }

    /// Skip ad, while an ad plays (the same call as the players' ad pill).
    @ViewBuilder private var adChip: some View {
        if player.nowPlaying?.episodeID == episode.episodeID, player.currentAd != nil {
            Button { player.skipCurrentAd() } label: {
                HStack(spacing: 4) {
                    Text("Skip ad")
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                }
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(Color(hex: 0x1C1B1A))
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Capsule().fill(Theme.deckAd))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Stamps

    private var playedStamp: some View {
        DeckStamp(text: "PLAYED", colour: DeckUpNextSwipeZone.green, tilt: 8)
            .opacity(Double(min(1, max(0, -offset / DeckUpNextSwipeZone.line))))
            .offset(x: max(0, -offset - 40))
            .padding(.trailing, 22)
            .padding(.top, 26)
    }

    private var moveStamp: some View {
        let far: Bool = offset >= DeckUpNextSwipeZone.farLine
        return DeckStamp(text: far ? "TO THE BOTTOM" : "NEXT IN LINE",
                         colour: far ? Theme.muted : DeckUpNextSwipeZone.blue, tilt: -8)
            .opacity(moves.canMoveTop(episode) ? Double(min(1, max(0, offset / DeckUpNextSwipeZone.line))) : 0)
            .offset(x: -max(0, offset - 40))
            .padding(.leading, 22)
            .padding(.top, 26)
    }

    // MARK: Swipe

    private func moved(_ x: CGFloat) {
        offset = x
        let now: DeckUpNextSwipeZone? = DeckUpNextSwipeZone.of(x, allowRight: moves.canMoveTop(episode))
        if now != zone {
            if now != nil { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            zone = now
        }
    }

    private func released(_ velocity: CGFloat) {
        let fire: DeckUpNextSwipeZone? = zone
        zone = nil
        guard let fire else {
            withAnimation(.spring(duration: 0.3)) { offset = 0 }
            return
        }
        let direction: CGFloat = offset > 0 ? 1 : -1
        withAnimation(.easeIn(duration: 0.22)) { offset = direction * 480 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            perform(fire)
            // The next card is already in place underneath: no fly-back.
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { offset = 0 }
        }
    }

    private func perform(_ fire: DeckUpNextSwipeZone) {
        switch fire {
        case .left: moves.played(episode)
        case .near: moves.moveTop(episode, toBottom: false)
        case .far: moves.moveTop(episode, toBottom: true)
        }
    }

    @ViewBuilder private var accessibilityMoves: some View {
        Button("Played") { moves.played(episode) }
        if moves.canMoveTop(episode) {
            Button("Next in line") { moves.moveTop(episode, toBottom: false) }
            Button("To the bottom") { moves.moveTop(episode, toBottom: true) }
        }
    }

    // MARK: Read along

    private var lineKey: String {
        wantsLines ? episode.episodeID + "|" + episode.transcriptStateRaw : ""
    }

    private func loadLines() {
        guard wantsLines, let transcript = transcripts.transcript(for: episode) else {
            lines = []
            return
        }
        lines = TranscriptLayout.lines(from: TranscriptAlign.aligned(transcript, anchors: episode.syncAnchors).segments)
    }

    /// Lines are read only when something shows them.
    private var wantsLines: Bool { layoutRaw == DeckLayout.read.rawValue || showWords }

    private func currentLine(_ info: DeckTopInfo) -> TranscriptLayout.Line? {
        let time: TimeInterval = info.time + 0.2
        return lines.last(where: { $0.start <= time }) ?? lines.first
    }
}

/// The rubber stamp on the top card while it's swiped.
private struct DeckStamp: View {
    let text: String
    let colour: Color
    let tilt: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Text(text)
            .font(Theme.outfit(18, .heavy))
            .foregroundStyle(colour)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(shape.fill(Theme.surface))
            .overlay(shape.strokeBorder(colour, lineWidth: 3))
            .rotationEffect(.degrees(tilt))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// What the keys on the top card do.
struct DeckTopActions {
    let play: () -> Void
    let open: () -> Void
    let options: () -> Void
    var toggleWords: () -> Void = {}
}

/// What the top card's picture area shows: the artwork, or the line being
/// said (`ready` false when the episode has no words yet).
struct DeckTopWords {
    var showing: Bool = false
    var line: TranscriptLayout.Line? = nil
    var ready: Bool = false
}

// MARK: - Shared pieces

/// The progress line: ink played, amber ad sections, on the card's line colour.
struct DeckUpNextProgressLine: View {
    let fraction: Double
    let ads: [AdBreak]
    let duration: TimeInterval
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardLine)
                ForEach(Array(ads.enumerated()), id: \.offset) { _, ad in
                    adBlock(ad, width: width)
                }
                Capsule().fill(Theme.ink).frame(width: width * CGFloat(fraction))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func adBlock(_ ad: AdBreak, width: CGFloat) -> some View {
        let length: TimeInterval = max(duration, 1)
        let start: CGFloat = width * CGFloat(max(0, ad.start) / length)
        let size: CGFloat = width * CGFloat(max(0, ad.end - ad.start) / length)
        return Rectangle().fill(Theme.deckAd).frame(width: size).offset(x: start)
    }
}

/// "16:40 · ends 21:25 · −34:27" under the line.
struct DeckUpNextTimesRow: View {
    let info: DeckTopInfo

    var body: some View {
        let ends: Date = Date().addingTimeInterval(info.left / max(info.speed, 0.5))
        HStack {
            Text(DeckUpNextTime.stamp(info.time))
            Spacer(minLength: 4)
            Text("ends " + UpNextTimes.clock(ends))
            Spacer(minLength: 4)
            Text("−" + DeckUpNextTime.stamp(info.left))
        }
        .font(Theme.outfit(12, .medium))
        .monospacedDigit()
        .foregroundStyle(Theme.muted)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}

/// The round play / pause key.
struct DeckUpNextPlayKey: View {
    let isPlaying: Bool
    var fill: Color = Theme.ink
    var size: CGFloat = 62
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.38))
                .foregroundStyle(Theme.background)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

/// Skip back, play / pause, skip forward (skips only for the episode on).
struct DeckUpNextTransport: View {
    let info: DeckTopInfo
    let actions: DeckTopActions

    var body: some View {
        HStack(spacing: 34) {
            SkipButton(direction: .back, iconSize: 34, frame: 52)
                .disabled(!info.isCurrent)
            DeckUpNextPlayKey(isPlaying: info.isPlaying, action: actions.play)
            SkipButton(direction: .forward, iconSize: 34, frame: 52)
                .disabled(!info.isCurrent)
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
    }
}

/// A UIKit pan that only starts when the finger moves sideways, so the
/// keys and long presses underneath keep working (as Poster's swipes).
struct DeckUpNextPan: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let changed: (CGFloat) -> Void
    let ended: (CGFloat) -> Void

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
        switch recognizer.state {
        // Against the window: the card moves with the finger.
        case .changed:
            changed(recognizer.translation(in: nil).x)
        case .ended:
            ended(recognizer.velocity(in: nil).x)
        case .cancelled, .failed:
            ended(0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity: CGPoint = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}
