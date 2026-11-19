import SwiftUI
import UIKit
import SwiftData
import Observation
import PodcastCore

// The dial (Paul, 15 Nov 2026: dial, from "Dials and tabs!",
// https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7, "Player: the dial").
// The player's artwork is round inside a white ring that shows how far
// through the episode you are: chapter ticks, ad breaks in amber (paler
// ahead), your clips as small white dots, a knob at the play point.
// Drag round the ring to scrub like a jog dial; slide in towards the
// middle for finer. While dragging, the middle shows the time and the
// words said at that point. Tap the artwork to turn it over to the line
// being said now; tap again for the artwork. In Read along the same
// picture slides into the corner with a small ring round it.

/// Where a drag round the dial has got to, shared by the dial and the
/// times row under the title (only views that read it redraw).
@Observable
final class DeckDialScrub {
    var time: TimeInterval?
    /// While the straight line in Read along is dragged: how fine ("Half
    /// speed"), shown in the middle of the times row.
    var hint: String?
}

/// One drag round the dial.
private struct DeckDialDrag {
    var startTime: TimeInterval
    /// The finger's last place round the dial, 0...1 from twelve o'clock.
    var lastTurn: Double
    var factor: Double
    var chapter: Int?
}

/// Sums for the dial, kept apart (with explicit types) so the compiler
/// checks them quickly.
enum DeckDialMath {
    /// 0...1 round the dial from twelve o'clock, clockwise.
    static func turn(dx: Double, dy: Double) -> Double {
        let angle: Double = atan2(dy, dx) + Double.pi / 2
        let full: Double = 2 * Double.pi
        let wrapped: Double = (angle + full).truncatingRemainder(dividingBy: full)
        return wrapped / full
    }

    /// A change in turn, wrapped so passing twelve o'clock never jumps.
    static func wrapped(_ change: Double) -> Double {
        if change > 0.5 { return change - 1 }
        if change < -0.5 { return change + 1 }
        return change
    }

    /// Full speed near the ring, half and a quarter further in
    /// (`distance` is the finger's distance from the centre over the
    /// dial's half width; the prototype's 95 / 65 of 124).
    static func factor(_ distance: Double) -> Double {
        if distance > 0.77 { return 1 }
        if distance > 0.52 { return 0.5 }
        return 0.25
    }

    static func hint(_ factor: Double) -> String {
        if factor >= 1 { return "Drag in for finer" }
        if factor >= 0.5 { return "Half speed" }
        return "Quarter speed"
    }

    static func point(_ centre: CGPoint, _ radius: CGFloat, at fraction: Double) -> CGPoint {
        let angle: Double = fraction * 2 * Double.pi - Double.pi / 2
        let x: CGFloat = centre.x + radius * CGFloat(cos(angle))
        let y: CGFloat = centre.y + radius * CGFloat(sin(angle))
        return CGPoint(x: x, y: y)
    }

    /// The line said at `time` (the last one started by then).
    static func line(at time: TimeInterval, in lines: [TranscriptLayout.Line]) -> TranscriptLayout.Line? {
        guard !lines.isEmpty else { return nil }
        var low: Int = 0
        var high: Int = lines.count - 1
        var found: Int = 0
        while low <= high {
            let middle: Int = (low + high) / 2
            if lines[middle].start <= time {
                found = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return lines[found]
    }
}

/// The ring's sizes for a dial `side` points across. Everything follows
/// the size, so the ring shrinks smoothly into Read along's corner.
struct DeckDialGeometry {
    let side: CGFloat

    var big: Bool { side > 90 }
    var lineWidth: CGFloat { min(9, max(3, side * 0.032)) }
    /// 0 in Read along's corner, 1 at full size: the knob, ticks and clip
    /// dots grow in with it.
    var presence: CGFloat { min(1, max(0, (side - 60) / 120)) }
    var knob: CGFloat { lineWidth * 1.3 * presence }
    var ringRadius: CGFloat { side / 2 - max(lineWidth / 2, knob) }
    var gap: CGFloat { big ? 8 : 3 }
    var artwork: CGFloat { max(10, 2 * (ringRadius - lineWidth / 2 - gap)) }
}

/// Seeks after a scrub; a jump of 2 minutes or more offers Undo (shared
/// by the progress line and the dial).
enum DeckScrubJump {
    @MainActor
    static func commit(to target: TimeInterval, from start: TimeInterval, player: PlayerModel, store: LibraryStore) {
        guard abs(target - start) > 0.5 else { return }
        player.seek(to: target)
        guard abs(target - start) >= 120 else { return }
        store.undoAction = UndoAction(label: "Jumped to \(TimeFormat.clock(target))") {
            player.seek(to: start)
            store.undoAction = nil
        }
    }
}

// MARK: - The dial

/// Drawn over the player at the artwork's spot (`DeckArtworkSpot`): the
/// whole dial when big, round artwork with a small ring in Read along's
/// corner (it only takes touches when big).
struct DeckPlayerDial: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tap the artwork for the words (remembered on this iPhone).
    @AppStorage("deckDialWords") private var showWords = false

    let item: PlayerModel.NowPlaying
    let episode: PodcastEpisode?
    let rect: CGRect
    /// The player's colour (the middle uses its deep shade).
    let colour: Color
    let scrub: DeckDialScrub

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var linesFor: String = ""
    @State private var clipTimes: [TimeInterval] = []
    @State private var drag: DeckDialDrag?
    @State private var dragEnded: Date = .distantPast

    private static let space: String = "deckDial"

    var body: some View {
        let geometry = DeckDialGeometry(side: min(rect.width, rect.height))
        return dial(geometry)
            .frame(width: geometry.side, height: geometry.side)
            .contentShape(Circle())
            .coordinateSpace(.named(Self.space))
            .gesture(dragGesture(side: geometry.side))
            .onTapGesture { tapped() }
            .modifier(DeckDialAccessibility(big: geometry.big, value: accessibilityValue,
                                            words: showWords, canTranscribe: canStartWords,
                                            toggle: toggleWords, transcribe: transcribe,
                                            forward: { player.skipForwardBy() },
                                            back: { player.skipBackward() }))
            // Search hits (Paul, 17 Nov 2026): a phrase found in Find's
            // "Said in your episodes" shows as yellow dots on the ring
            // wherever it's said in this episode; the pill names it and
            // clears it.
            .overlay(alignment: .topLeading) {
                if geometry.big, !searchHits.isEmpty, let term = search.term { searchPill(term) }
            }
            .allowsHitTesting(geometry.big)
            .position(x: rect.midX, y: rect.midY)
            .task(id: lineKey) { await load() }
    }

    private var faceShown: Bool { scrub.time != nil || showWords }

    private var search: DeckDialSearch { DeckDialSearch.shared }

    /// Times of the lines in this episode that say the searched phrase.
    private var searchHits: [TimeInterval] {
        guard search.episodeID == item.episodeID, let term = search.term else { return [] }
        return search.hits(of: term, in: lines)
    }

    private func searchPill(_ term: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { search.clear() }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(DeckDialSearch.dotColour).frame(width: 7, height: 7)
                Text("\u{201C}\(term)\u{201D} \u{00B7} \(searchHits.count)")
                    .font(Theme.outfit(12, .semibold))
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .frame(maxWidth: 170, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search marks for \(term), \(searchHits.count). Clear")
    }

    private func dial(_ geometry: DeckDialGeometry) -> some View {
        let shown: TimeInterval = scrub.time ?? player.currentTime
        let duration: TimeInterval = max(player.duration, 1)
        let face: Bool = geometry.big && faceShown
        return ZStack {
            artwork(geometry)
            if face {
                faceView(geometry, time: shown)
                    .transition(.opacity)
            }
            DeckDialRing(side: geometry.side, spec: ringSpec(geometry, progress: shown / duration))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: face)
    }

    private func artwork(_ geometry: DeckDialGeometry) -> some View {
        let diameter: CGFloat = geometry.artwork
        return Color.clear
            .frame(width: diameter, height: diameter)
            .overlay {
                CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.showTitle) }
            }
            .clipShape(Circle())
            .background {
                Circle()
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(geometry.big ? 0.35 : 0), radius: 28, y: 20)
                    .opacity(geometry.big ? 1 : 0)
            }
    }

    private func ringSpec(_ geometry: DeckDialGeometry, progress: Double) -> DeckDialRingSpec {
        let duration: TimeInterval = player.duration
        var chapters: [Double] = []
        var ads: [ClosedRange<Double>] = []
        var clips: [Double] = []
        if duration > 0 {
            chapters = player.chapters.map { (chapter: Chapter) -> Double in chapter.start / duration }
            ads = player.adBreaks.compactMap { (ad: AdBreak) -> ClosedRange<Double>? in
                let start: Double = ad.start / duration
                let end: Double = ad.end / duration
                return start <= end ? start...end : nil
            }
            clips = clipTimes.map { (time: TimeInterval) -> Double in time / duration }
        }
        let hits: [Double] = duration > 0 ? searchHits.map { (time: TimeInterval) -> Double in time / duration } : []
        return DeckDialRingSpec(progress: min(1, max(0, progress)), chapters: chapters, ads: ads,
                                clips: clips, deep: DeckPlayerBackground.shade(colour), hits: hits)
    }

    // MARK: Middle of the dial

    private func faceView(_ geometry: DeckDialGeometry, time: TimeInterval) -> some View {
        let diameter: CGFloat = geometry.artwork
        let lineSize: CGFloat = max(13, min(19, diameter * 0.068))
        return Circle()
            .fill(DeckPlayerBackground.shade(colour).opacity(0.9))
            .frame(width: diameter, height: diameter)
            .overlay {
                faceText(time: time, lineSize: lineSize)
                    .padding(diameter * 0.15)
            }
    }

    @ViewBuilder private func faceText(time: TimeInterval, lineSize: CGFloat) -> some View {
        if let drag {
            // Scrubbing: the time, what's said there, how fine.
            DeckDialFaceText(time: TimeFormat.clock(time),
                             line: DeckDialMath.line(at: time + 0.2, in: lines)?.text,
                             hint: DeckDialMath.hint(drag.factor), lineSize: lineSize)
        } else if let line = DeckDialMath.line(at: player.currentTime + 0.2, in: lines) {
            DeckDialFaceText(time: nil, line: line.text, hint: "Tap for the artwork", lineSize: lineSize)
                .id(line.start)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: line.start)
        } else {
            noWords
        }
    }

    /// Before there are words: "No words yet" and a Transcribe key, or how
    /// far the transcript has got.
    @ViewBuilder private var noWords: some View {
        if let episode, episode.transcriptState == .ready {
            // Ready but still loading: nothing rather than a wrong note.
            Color.clear
        } else {
            VStack(spacing: 8) {
                Text(workingText ?? "No words yet")
                    .font(Theme.outfit(16, .bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                if workingText == nil, canStartWords {
                    Button(action: transcribe) {
                        Text("Transcribe")
                            .font(Theme.outfit(13, .bold))
                            .foregroundStyle(DeckPlayerColours.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
                Text("Tap for the artwork")
                    .font(Theme.outfit(11, .medium))
                    .opacity(0.7)
            }
        }
    }

    /// "Transcribing 62%" / "Downloading first 40%" while on its way.
    private var workingText: String? {
        guard let episode else { return nil }
        let id: String = episode.episodeID
        guard transcripts.isQueued(episode) || episode.transcriptState == .transcribing else { return nil }
        if episode.transcriptState == .transcribing {
            let fraction: Double = transcripts.progress[id] ?? 0
            return "Transcribing \(Int(fraction * 100))%"
        }
        if let fraction = downloads.progress[id] {
            return "Downloading first \(Int(fraction * 100))%"
        }
        return "Waiting to transcribe"
    }

    private var canStartWords: Bool {
        guard let episode, episode.transcriptState != .ready else { return false }
        return transcripts.canTranscribeNow(episode)
    }

    /// The same as the top card's Transcribe now.
    private func transcribe() {
        guard let episode else { return }
        transcripts.transcribeNow(episode)
    }

    // MARK: Touches

    private func tapped() {
        // A short drag can also end as a tap: ignore it.
        guard drag == nil, Date().timeIntervalSince(dragEnded) > 0.35 else { return }
        toggleWords()
    }

    private func toggleWords() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { showWords.toggle() }
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { (value: DragGesture.Value) in
                dragChanged(value, side: side)
            }
            .onEnded { (_: DragGesture.Value) in
                dragFinished()
            }
    }

    /// The playhead moves by how far the finger turns round the centre
    /// (one full turn = the whole episode at full speed), measured in the
    /// dial's own space, which never moves.
    private func dragChanged(_ value: DragGesture.Value, side: CGFloat) {
        let duration: TimeInterval = player.duration
        guard duration > 1 else { return }
        let half: Double = Double(side / 2)
        let dx: Double = Double(value.location.x) - half
        let dy: Double = Double(value.location.y) - half
        let distance: Double = (dx * dx + dy * dy).squareRoot() / max(half, 1)
        let turn: Double = DeckDialMath.turn(dx: dx, dy: dy)
        var state: DeckDialDrag = drag ?? begin(value, half: half)
        state.factor = DeckDialMath.factor(distance)
        // Right in the middle the angle swings wildly: just follow it.
        if distance > 0.12 {
            let change: Double = DeckDialMath.wrapped(turn - state.lastTurn)
            let current: TimeInterval = scrub.time ?? state.startTime
            let next: TimeInterval = min(duration, max(0, current + change * duration * state.factor))
            scrub.time = next
            let chapter: Int? = Chapters.index(at: next, in: player.chapters)
            if chapter != state.chapter {
                UISelectionFeedbackGenerator().selectionChanged()
                state.chapter = chapter
            }
        }
        state.lastTurn = turn
        drag = state
    }

    private func begin(_ value: DragGesture.Value, half: Double) -> DeckDialDrag {
        let dx: Double = Double(value.startLocation.x) - half
        let dy: Double = Double(value.startLocation.y) - half
        let now: TimeInterval = player.currentTime
        scrub.time = now
        return DeckDialDrag(startTime: now, lastTurn: DeckDialMath.turn(dx: dx, dy: dy), factor: 1,
                            chapter: Chapters.index(at: now, in: player.chapters))
    }

    private func dragFinished() {
        if let target = scrub.time, let state = drag {
            DeckScrubJump.commit(to: target, from: state.startTime, player: player, store: store)
        }
        dragEnded = Date()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            drag = nil
            scrub.time = nil
        }
    }

    // MARK: Words and clips

    private var lineKey: String {
        guard let episode else { return "" }
        let anchors: Int = episode.syncAnchorsData?.count ?? 0
        return episode.episodeID + "|" + episode.transcriptStateRaw + "|" + String(anchors)
    }

    /// The episode's lines, read once per episode (and when its transcript
    /// changes) off the main thread; its clips from the saved bookmarks.
    private func load() async {
        guard let episode else {
            lines = []
            clipTimes = []
            return
        }
        let id: String = episode.episodeID
        if linesFor != id {
            lines = []
            linesFor = id
        }
        clipTimes = clips(for: id)
        guard episode.transcriptState == .ready, let name = episode.transcriptFile else {
            lines = []
            return
        }
        let anchors: [SyncAnchor] = episode.syncAnchors
        let loaded: [TranscriptLayout.Line] = await Task.detached(priority: .userInitiated) { () -> [TranscriptLayout.Line] in
            guard let transcript = TranscriptFiles.load(name) else { return [] }
            let aligned: Transcript = TranscriptAlign.aligned(transcript, anchors: anchors)
            return TranscriptLayout.lines(from: aligned.segments)
        }.value
        guard !Task.isCancelled, linesFor == id else { return }
        lines = loaded
    }

    private func clips(for id: String) -> [TimeInterval] {
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate<Bookmark> { $0.episodeID == id })
        let found: [Bookmark] = (try? store.context.fetch(descriptor)) ?? []
        return found.map { (bookmark: Bookmark) -> TimeInterval in bookmark.time }
    }

    private var accessibilityValue: String {
        let shown: TimeInterval = scrub.time ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        return "\(TimeFormat.clock(shown)), \(TimeFormat.clock(left)) left"
    }
}

/// The dial for VoiceOver: an adjustable position (skips), plus actions to
/// turn the artwork over to the words and to transcribe.
private struct DeckDialAccessibility: ViewModifier {
    let big: Bool
    let value: String
    let words: Bool
    let canTranscribe: Bool
    let toggle: () -> Void
    let transcribe: () -> Void
    let forward: () -> Void
    let back: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position")
            .accessibilityValue(value)
            .accessibilityHint("Drag round the ring to move through the episode")
            .accessibilityAdjustableAction { (direction: AccessibilityAdjustmentDirection) in
                switch direction {
                case .increment: forward()
                case .decrement: back()
                @unknown default: break
                }
            }
            .accessibilityActions {
                Button(words ? "Show the artwork" : "Show the words", action: toggle)
                if canTranscribe {
                    Button("Transcribe now", action: transcribe)
                }
            }
            .accessibilityHidden(!big)
    }
}

/// The middle's words: a time, a line and a hint, centred.
private struct DeckDialFaceText: View {
    let time: String?
    let line: String?
    let hint: String
    let lineSize: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            if let time {
                Text(time)
                    .font(Theme.outfit(13, .bold))
                    .monospacedDigit()
                    .opacity(0.7)
            }
            if let line, !line.isEmpty {
                Text("\u{201C}" + line + "\u{201D}")
                    .font(Theme.outfit(lineSize, .bold))
                    .lineSpacing(1)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                    .minimumScaleFactor(0.7)
            }
            Text(hint)
                .font(Theme.outfit(11, .medium))
                .opacity(0.7)
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - The ring

struct DeckDialRingSpec {
    let progress: Double
    let chapters: [Double]
    let ads: [ClosedRange<Double>]
    let clips: [Double]
    let deep: Color
    /// Where a searched phrase is said (0–1 round the ring).
    var hits: [Double] = []
}

/// The phrase last opened from Find's "Said in your episodes", and which
/// episode it was in: that episode's dial marks every line saying it.
@MainActor
@Observable
final class DeckDialSearch {
    static let shared = DeckDialSearch()
    nonisolated static let dotColour = Color(red: 1, green: 0.84, blue: 0.42)
    private(set) var term: String?
    private(set) var episodeID: String?

    func set(_ term: String, episodeID: String) {
        let trimmed: String = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.term = trimmed.isEmpty ? nil : trimmed
        self.episodeID = trimmed.isEmpty ? nil : episodeID
    }

    func clear() {
        term = nil
        episodeID = nil
    }

    /// Worked out once per phrase and transcript, not on every redraw
    /// (Paul, 19 Nov 2026: pulling the player down got jerky once the dial
    /// had search dots: every frame of the pull searched every line again).
    @ObservationIgnored private var memoKey: String = ""
    @ObservationIgnored private var memo: [TimeInterval] = []

    func hits(of term: String, in lines: [TranscriptLayout.Line]) -> [TimeInterval] {
        let key: String = "\(term)|\(episodeID ?? "")|\(lines.count)|\(lines.first?.start ?? 0)|\(lines.last?.start ?? 0)"
        if key == memoKey { return memo }
        memo = Self.times(of: term, in: lines)
        memoKey = key
        return memo
    }

    /// Lines containing every word of the phrase (any case or accents).
    nonisolated static func times(of term: String, in lines: [TranscriptLayout.Line]) -> [TimeInterval] {
        let words: [String] = term.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return lines.filter { (line: TranscriptLayout.Line) -> Bool in
            words.allSatisfy { line.text.range(of: $0, options: options) != nil }
        }.map(\.start)
    }
}

/// White on the player's colour: a faint track, the played part white,
/// ad breaks amber (paler ahead), chapter ticks cut into the ring, clips
/// as white dots and a knob at the play point (the last three fade out as
/// it shrinks into Read along's corner). Animatable on its size, so the
/// ring follows the picture smoothly between the two.
private struct DeckDialRing: View, Animatable {
    var side: CGFloat
    let spec: DeckDialRingSpec

    var animatableData: CGFloat {
        get { side }
        set { side = newValue }
    }

    var body: some View {
        let geometry = DeckDialGeometry(side: side)
        let spec: DeckDialRingSpec = self.spec
        return Canvas { (context: inout GraphicsContext, size: CGSize) in
            Self.draw(in: context, size: size, geometry: geometry, spec: spec)
        }
        .frame(width: side, height: side)
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func arc(_ centre: CGPoint, _ radius: CGFloat, from start: Double, to end: Double) -> Path {
        var path = Path()
        path.addArc(center: centre, radius: radius, startAngle: .degrees(-90 + 360 * start),
                    endAngle: .degrees(-90 + 360 * end), clockwise: false)
        return path
    }

    private static func draw(in context: GraphicsContext, size: CGSize, geometry: DeckDialGeometry,
                             spec: DeckDialRingSpec) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = geometry.ringRadius
        let width: CGFloat = geometry.lineWidth
        let circle = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                            width: radius * 2, height: radius * 2))
        context.stroke(circle, with: .color(Color.white.opacity(0.2)), lineWidth: width)
        let progress: Double = spec.progress
        if progress > 0.001 {
            context.stroke(arc(centre, radius, from: 0, to: progress), with: .color(Color.white),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        drawAds(in: context, centre: centre, geometry: geometry, spec: spec)
        guard geometry.presence > 0.01 else { return }
        var marks = context
        marks.opacity = Double(geometry.presence)
        drawTicks(in: context, centre: centre, geometry: geometry, spec: spec)
        drawClips(in: marks, centre: centre, geometry: geometry, spec: spec)
        drawHits(in: marks, centre: centre, geometry: geometry, spec: spec)
        drawKnob(in: marks, centre: centre, geometry: geometry, spec: spec)
    }

    private static func drawAds(in context: GraphicsContext, centre: CGPoint, geometry: DeckDialGeometry,
                                spec: DeckDialRingSpec) {
        let radius: CGFloat = geometry.ringRadius
        let style = StrokeStyle(lineWidth: geometry.lineWidth, lineCap: .butt)
        for ad in spec.ads {
            let played: Double = min(ad.upperBound, spec.progress)
            if played > ad.lowerBound {
                context.stroke(arc(centre, radius, from: ad.lowerBound, to: played),
                               with: .color(Theme.deckAd), style: style)
            }
            let ahead: Double = max(ad.lowerBound, spec.progress)
            if ad.upperBound > ahead {
                context.stroke(arc(centre, radius, from: ahead, to: ad.upperBound),
                               with: .color(Theme.deckAd.opacity(0.45)), style: style)
            }
        }
    }

    /// A small cut across the ring at each chapter start.
    private static func drawTicks(in context: GraphicsContext, centre: CGPoint, geometry: DeckDialGeometry,
                                  spec: DeckDialRingSpec) {
        var cutter = context
        cutter.blendMode = .clear
        let radius: CGFloat = geometry.ringRadius
        let half: CGFloat = geometry.lineWidth / 2
        let inner: CGFloat = radius - half - 1
        let outer: CGFloat = radius + half + 1
        for start in spec.chapters where start > 0.002 && start < 0.998 {
            var tick = Path()
            tick.move(to: DeckDialMath.point(centre, inner, at: start))
            tick.addLine(to: DeckDialMath.point(centre, outer, at: start))
            cutter.stroke(tick, with: .color(Color.black), lineWidth: 2.5 * geometry.presence)
        }
    }

    private static func drawClips(in context: GraphicsContext, centre: CGPoint, geometry: DeckDialGeometry,
                                  spec: DeckDialRingSpec) {
        let dot: CGFloat = max(2.5, geometry.lineWidth * 0.42)
        for clip in spec.clips where clip >= 0 && clip <= 1 {
            let point: CGPoint = DeckDialMath.point(centre, geometry.ringRadius, at: clip)
            let rect = CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white))
            context.stroke(Path(ellipseIn: rect), with: .color(spec.deep), lineWidth: 1.5)
        }
    }

    /// Search hits: small yellow dots just inside the ring.
    private static func drawHits(in context: GraphicsContext, centre: CGPoint, geometry: DeckDialGeometry,
                                 spec: DeckDialRingSpec) {
        let dot: CGFloat = max(2, geometry.lineWidth * 0.36)
        let radius: CGFloat = geometry.ringRadius - geometry.lineWidth * 0.5 - dot - 2
        for hit in spec.hits where hit >= 0 && hit <= 1 {
            let point: CGPoint = DeckDialMath.point(centre, radius, at: hit)
            let rect = CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)
            context.fill(Path(ellipseIn: rect), with: .color(DeckDialSearch.dotColour))
        }
    }

    private static func drawKnob(in context: GraphicsContext, centre: CGPoint, geometry: DeckDialGeometry,
                                 spec: DeckDialRingSpec) {
        let point: CGPoint = DeckDialMath.point(centre, geometry.ringRadius, at: spec.progress)
        let size: CGFloat = geometry.knob
        guard size > 3 else { return }
        let rect = CGRect(x: point.x - size, y: point.y - size, width: size * 2, height: size * 2)
        var shadowed = context
        shadowed.addFilter(.shadow(color: Color.black.opacity(0.3), radius: 3, y: 2))
        shadowed.fill(Path(ellipseIn: rect), with: .color(Color.white))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(spec.deep), lineWidth: 3)
    }
}

// MARK: - Times row

/// Under the title with the dial: played · ends HH:MM · −left (at this
/// speed). While dragging round the dial it follows the drag and the
/// middle names the chapter there.
struct DeckDialTimes: View {
    @Environment(PlayerModel.self) private var player
    let scrub: DeckDialScrub
    /// Read along: the same row, shrunk under the straight line. The numbers
    /// shrink in place (a scale, so it animates smoothly with Read along's
    /// move, like the chapter pill) instead of swapping for a smaller row
    /// (Paul, 16 Nov 2026: "make the animation on the numbers getting
    /// smaller and moving smoother like the chapter pill moving").
    var compact: Bool = false

    static let compactHeight: CGFloat = 16
    private var clockScale: CGFloat { compact ? 12.0 / 18.0 : 1 }
    private var middleScale: CGFloat { compact ? 12.0 / 13.0 : 1 }

    /// Bigger numbers (Paul, 16 Nov 2026: with the line gone, the small
    /// times looked "like something has failed to render").
    static let height: CGFloat = 26
    static var clockFont: Font { Theme.outfit(18, .semibold) }
    static var middleFont: Font { Theme.outfit(13, .medium) }

    var body: some View {
        let shown: TimeInterval = scrub.time ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let atSpeed: TimeInterval = left / max(player.speed, 0.5)
        let ends: Date = Date().addingTimeInterval(atSpeed)
        return HStack(spacing: 4) {
            Text(TimeFormat.clock(shown))
                .font(Self.clockFont)
                .frame(minWidth: 72, alignment: .leading)
                .scaleEffect(clockScale, anchor: .leading)
            Spacer(minLength: 0)
            Text(middle(shown, ends: ends))
                .font(Self.middleFont)
                .minimumScaleFactor(0.7)
                .opacity(0.75)
                .scaleEffect(middleScale)
            Spacer(minLength: 0)
            Text("−" + TimeFormat.clock(atSpeed))
                .font(Self.clockFont)
                .frame(minWidth: 72, alignment: .trailing)
                .scaleEffect(clockScale, anchor: .trailing)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .opacity(compact ? 0.85 : 1)
        .frame(height: compact ? Self.compactHeight : Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(TimeFormat.clock(atSpeed)) left, ends at \(UpNextTimes.clock(ends))")
    }

    private func middle(_ time: TimeInterval, ends: Date) -> String {
        if let hint = scrub.hint { return hint }
        if scrub.time != nil {
            let chapters: [Chapter] = player.chapters
            if let index = Chapters.index(at: time, in: chapters) { return chapters[index].title }
        }
        return "ends " + UpNextTimes.clock(ends)
    }
}
