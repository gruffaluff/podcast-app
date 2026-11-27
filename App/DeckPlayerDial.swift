import SwiftUI
import UIKit
import SwiftData
import Observation
import PodcastCore

// The player's artwork (it began as a dial, Paul, 15 Nov 2026; G3, 22 Nov
// 2026: a big rounded square, no ring, "more like Apple Podcasts"). Only
// for looking: scrubbing is the straight line above the keys, and while
// it's dragged the middle shows the time and the words said at that
// point. Tap the artwork to turn it over to the line being said now; tap
// again for the artwork. In Read along the same picture slides into the
// corner.

/// Where a drag of the progress line has got to, shared by the artwork's
/// middle and the times row (only views that read it redraw).
@Observable
final class DeckDialScrub {
    var time: TimeInterval?
    /// While the line is dragged: how fine ("Half speed"), shown in the
    /// middle of the times row.
    var hint: String?
}

/// Sums for the artwork's middle, kept apart (with explicit types) so the
/// compiler checks them quickly.
enum DeckDialMath {
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

/// The artwork's sizes for a spot `side` points across. Everything follows
/// the size, so it shrinks smoothly into Read along's corner.
struct DeckDialGeometry {
    let side: CGFloat

    var big: Bool { side > 90 }
    /// The artwork fills the whole spot now (Paul, 22 Nov 2026, G3: "more
    /// like Apple Podcasts … dropping the ring from the artwork").
    var artwork: CGFloat { max(10, side) }
    /// Rounded-square corners, smaller in Read along's corner.
    var corner: CGFloat { max(6, side * 0.055) }
}

/// Seeks after a scrub; a jump of 2 minutes or more offers Undo.
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

/// Drawn over the player at the artwork's spot: the big rounded-square
/// artwork, or the small one in Read along's corner (it only takes
/// touches when big).
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

    var body: some View {
        let geometry = DeckDialGeometry(side: min(rect.width, rect.height))
        return dial(geometry)
            .frame(width: geometry.side, height: geometry.side)
            .contentShape(RoundedRectangle(cornerRadius: geometry.corner, style: .continuous))
            // Look, don't drag (Paul, 22 Nov 2026, option 2): scrubbing is
            // the straight line in the thumb zone; while it's dragged the
            // middle shows the time and what's said.
            .onTapGesture { toggleWords() }
            .modifier(DeckDialAccessibility(big: geometry.big, value: accessibilityValue,
                                            words: showWords, canTranscribe: canStartWords,
                                            toggle: toggleWords, transcribe: transcribe,
                                            forward: { player.skipForwardBy() },
                                            back: { player.skipBackward() }))
            // Search hits (Paul, 17 Nov 2026): a phrase found in Find's
            // "Said in your episodes" is marked on the progress line
            // wherever it's said in this episode; the pill names it and
            // clears it.
            .overlay(alignment: .topLeading) {
                if geometry.big, !searchHits.isEmpty, let term = search.term { searchPill(term) }
            }
            .allowsHitTesting(geometry.big)
            .position(x: rect.midX, y: rect.midY)
            .task(id: lineKey) { await load() }
            .onChange(of: searchHits, initial: true) { _, hits in
                if search.episodeID == item.episodeID, search.lineHits != hits { search.lineHits = hits }
            }
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
        let face: Bool = geometry.big && faceShown
        return ZStack {
            artwork(geometry)
            if face {
                faceView(geometry, time: shown)
                    .transition(.opacity)
            }
            // No ring (G3): progress is the line above the keys.
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: face)
    }

    /// The artwork in full colour (the colour sweep went, Paul, 23 Nov 2026).
    private func artwork(_ geometry: DeckDialGeometry) -> some View {
        let diameter: CGFloat = geometry.artwork
        return Color.clear
            .frame(width: diameter, height: diameter)
            .overlay {
                // Full colour (Paul, 23 Nov 2026: the colour fade goes).
                CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: geometry.corner, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: geometry.corner, style: .continuous)
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(geometry.big ? 0.35 : 0), radius: 28, y: 20)
                    .opacity(geometry.big ? 1 : 0)
            }
    }

    // MARK: Middle of the dial

    private func faceView(_ geometry: DeckDialGeometry, time: TimeInterval) -> some View {
        let diameter: CGFloat = geometry.artwork
        let lineSize: CGFloat = max(13, min(19, diameter * 0.068))
        return RoundedRectangle(cornerRadius: geometry.corner, style: .continuous)
            .fill(DeckPlayerBackground.shade(colour).opacity(0.9))
            .frame(width: diameter, height: diameter)
            .overlay {
                faceText(time: time, lineSize: lineSize)
                    .padding(diameter * 0.15)
            }
    }

    @ViewBuilder private func faceText(time: TimeInterval, lineSize: CGFloat) -> some View {
        if scrub.time != nil {
            // Scrubbing: the time, what's said there, how fine.
            DeckDialFaceText(time: TimeFormat.clock(time),
                             line: DeckDialMath.line(at: time + 0.2, in: lines)?.text,
                             hint: scrub.hint ?? "", lineSize: lineSize)
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

    /// Transcribe now.
    private func transcribe() {
        guard let episode else { return }
        transcripts.transcribeNow(episode)
    }

    // MARK: Touches

    private func toggleWords() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { showWords.toggle() }
    }

    // MARK: Words

    private var lineKey: String {
        guard let episode else { return "" }
        let anchors: Int = episode.syncAnchorsData?.count ?? 0
        return episode.episodeID + "|" + episode.transcriptStateRaw + "|" + String(anchors)
    }

    /// The episode's lines, read once per episode (and when its transcript
    /// changes) off the main thread.
    private func load() async {
        guard let episode else {
            lines = []
            return
        }
        let id: String = episode.episodeID
        if linesFor != id {
            lines = []
            linesFor = id
        }
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

// MARK: - Search hits

/// The phrase last opened from Find's "Said in your episodes", and which
/// episode it was in: that episode's progress line marks every line saying it.
@MainActor
@Observable
final class DeckDialSearch {
    static let shared = DeckDialSearch()
    nonisolated static let dotColour = Color(red: 1, green: 0.84, blue: 0.42)
    private(set) var term: String?
    private(set) var episodeID: String?
    /// Times of the lines that say the phrase in that episode, set by the
    /// player's artwork view once it has the transcript; the progress line
    /// marks them (`DeckPlayerScrub.hitFractions`).
    var lineHits: [TimeInterval] = []

    func set(_ term: String, episodeID: String) {
        let trimmed: String = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.term = trimmed.isEmpty ? nil : trimmed
        self.episodeID = trimmed.isEmpty ? nil : episodeID
    }

    func clear() {
        term = nil
        episodeID = nil
        lineHits = []
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

// MARK: - Times row

/// Played · ends HH:MM · −left (at this speed). While the line is dragged
/// it follows the drag and the middle names the chapter there.
struct DeckDialTimes: View {
    @Environment(PlayerModel.self) private var player
    let scrub: DeckDialScrub
    /// Read along: the same row, shrunk under the straight line. The numbers
    /// shrink in place (a scale, so it animates smoothly with Read along's
    /// move, like the chapter pill) instead of swapping for a smaller row
    /// (Paul, 16 Nov 2026: "make the animation on the numbers getting
    /// smaller and moving smoother like the chapter pill moving").
    var compact: Bool = false
    /// R2 (Paul, 27 Nov 2026): the middle names the chapter now ("Comfort
    /// darts ›") and opens the chapters sheet; with no chapters it shows
    /// when the episode ends and still opens the sheet (Make chapters).
    var openChapters: (() -> Void)? = nil

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
            middleText(shown, ends: ends)
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

    @ViewBuilder private func middleText(_ time: TimeInterval, ends: Date) -> some View {
        let words: Text = Text(middle(time, ends: ends))
            .font(Self.middleFont)
        if let openChapters, scrub.time == nil {
            Button(action: openChapters) {
                words
                    .minimumScaleFactor(0.7)
                    .opacity(0.85)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the chapters")
        } else {
            words
                .minimumScaleFactor(0.7)
                .opacity(0.75)
        }
    }

    private func middle(_ time: TimeInterval, ends: Date) -> String {
        if let hint = scrub.hint { return hint }
        let chapters: [Chapter] = player.chapters
        if scrub.time != nil || openChapters != nil,
           let index = Chapters.index(at: time, in: chapters) {
            return chapters[index].title + (scrub.time == nil ? " ›" : "")
        }
        return "ends " + UpNextTimes.clock(ends)
    }
}

