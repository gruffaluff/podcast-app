import SwiftUI
import PodcastCore

// Pieces of Deck's player (DeckPlayer.swift), white on the show's colour.

// MARK: - Chapter row

/// "‹ 4/6 · title ›" (tap the pill for the chapter list) with Skip ad in
/// amber on the right while an ad plays ("Play ad" just after one is
/// skipped). The row keeps its height when there's nothing to show, so
/// nothing below moves.
struct DeckChapterRow: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    let openChapters: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if !player.chapters.isEmpty {
                chapters
            }
            Spacer(minLength: 0)
            adChip
                .fixedSize()
        }
        .frame(height: 32)
        .animation(.easeOut(duration: 0.25), value: player.currentAd?.start)
        .animation(.easeOut(duration: 0.25), value: player.lastSkippedAd?.start)
    }

    private var chapters: some View {
        let list: [Chapter] = player.chapters
        let index: Int? = player.currentChapterIndex
        let canNext: Bool = (index ?? -1) < list.count - 1
        return HStack(spacing: 4) {
            arrow("chevron.left", label: "Previous chapter", enabled: true) { player.previousChapter() }
            Button(action: openChapters) { pill(list, index: index) }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibility(list, index: index))
                .accessibilityHint("Shows every chapter")
            arrow("chevron.right", label: "Next chapter", enabled: canNext) { player.nextChapter() }
        }
    }

    private func pill(_ list: [Chapter], index: Int?) -> some View {
        let title: String = index.flatMap { list.indices.contains($0) ? list[$0].title : nil } ?? "Chapters"
        let number: String = index.map { "\($0 + 1)/\(list.count) · " } ?? ""
        return Text(number + title)
            .font(Theme.outfit(13, .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Color.white.opacity(0.16)))
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private func accessibility(_ list: [Chapter], index: Int?) -> String {
        guard let index, list.indices.contains(index) else { return "Chapters" }
        return "Chapter \(index + 1) of \(list.count), \(list[index].title)"
    }

    /// Skip ad while one plays; Play ad just after a skip. Touch and hold
    /// for Not an ad.
    @ViewBuilder private var adChip: some View {
        if let adBreak = player.currentAd {
            chip("Skip ad") { player.skipCurrentAd() }
                .contextMenu { notAnAd(adBreak) }
                .accessibilityHint("Show resumes at \(TimeFormat.clock(adBreak.end))")
                .transition(.opacity)
        } else if let adBreak = player.lastSkippedAd {
            chip("Play ad") { player.playAd(adBreak) }
                .contextMenu { notAnAd(adBreak) }
                .transition(.opacity)
        }
    }

    private func notAnAd(_ adBreak: AdBreak) -> some View {
        Button("Not an ad", systemImage: "xmark.circle") { player.notAnAd(adBreak, transcripts: transcripts) }
    }

    private func chip(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(DeckPlayerColours.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Theme.deckAd))
        }
        .buttonStyle(.plain)
    }
}

/// Fixed colours for the player, the same in Deck light and night.
enum DeckPlayerColours {
    /// The prototype's ink (#1C1B1A), on the amber and white keys.
    static let ink = Color(hex: 0x1C1B1A)
}

// MARK: - Progress line

/// The progress line (prototype `scrub`, with the drag rules Paul chose
/// before: HaarScrubLine): a 6 pt line, played in white, the rest faint,
/// small gaps at chapters, ad breaks amber, a white knob at the play
/// point. Drag anywhere: it moves by how far the finger travels (a touch
/// never jumps), finger lower down for finer, a bubble shows the chapter
/// and time, and a jump of 2 minutes or more offers Undo. Under it:
/// elapsed · ends HH:MM · −left (at this speed).
struct DeckPlayerScrub: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @State private var scrubTime: TimeInterval?
    @State private var scrubStart: TimeInterval?
    @State private var lastX: CGFloat?
    @State private var speedLabel: String?

    static let height: CGFloat = 28

    var body: some View {
        let duration: TimeInterval = max(player.duration, 1)
        let shown: TimeInterval = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        VStack(spacing: 2) {
            line(shown: shown, left: left, duration: duration)
            timeRow(shown: shown, left: left)
        }
    }

    private func line(shown: TimeInterval, left: TimeInterval, duration: TimeInterval) -> some View {
        GeometryReader { geometry in
            let width: CGFloat = max(1, geometry.size.width)
            ZStack(alignment: .topLeading) {
                DeckPlayerLine(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions,
                               grow: scrubTime == nil ? 0 : 1)
                    .frame(width: width, height: Self.height)
                    .animation(.easeOut(duration: 0.18), value: scrubTime == nil)
                if scrubTime != nil {
                    bubble(at: shown, x: CGFloat(shown / duration) * width, width: width)
                }
            }
            .contentShape(Rectangle())
            .gesture(scrub(width: width, duration: duration))
        }
        .frame(height: Self.height)
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue("\(TimeFormat.clock(shown)), \(TimeFormat.clock(left)) left")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.skipForwardBy()
            case .decrement: player.skipBackward()
            @unknown default: break
            }
        }
    }

    private func timeRow(shown: TimeInterval, left: TimeInterval) -> some View {
        let atSpeed: TimeInterval = left / max(player.speed, 0.5)
        let ends: Date = Date().addingTimeInterval(atSpeed)
        return HStack(spacing: 4) {
            Text(TimeFormat.clock(shown))
                .frame(minWidth: 64, alignment: .leading)
            Spacer(minLength: 0)
            Text(speedLabel ?? "ends " + UpNextTimes.clock(ends))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("−" + TimeFormat.clock(atSpeed))
                .frame(minWidth: 64, alignment: .trailing)
        }
        .font(Theme.outfit(12, .medium))
        .monospacedDigit()
        .opacity(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(TimeFormat.clock(atSpeed)) left, ends at \(UpNextTimes.clock(ends))")
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.compactMap { (ad: AdBreak) -> ClosedRange<Double>? in
            let start: Double = ad.start / player.duration
            let end: Double = ad.end / player.duration
            return start <= end ? start...end : nil
        }
    }

    private var chapterStarts: [Double] {
        guard player.duration > 0 else { return [] }
        return player.chapters.map { $0.start / player.duration }
    }

    private func scrub(width: CGFloat, duration: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { (value: DragGesture.Value) in
                moved(to: value.location, width: width, duration: duration)
            }
            .onEnded { (_: DragGesture.Value) in
                finish()
            }
    }

    private func moved(to location: CGPoint, width: CGFloat, duration: TimeInterval) {
        guard let last = lastX, let current = scrubTime else {
            scrubStart = player.currentTime
            scrubTime = player.currentTime
            lastX = location.x
            speedLabel = PlayerOptions.scrubSpeed(below: 0).label
            return
        }
        let below: Double = Double(location.y - Self.height)
        let speed = PlayerOptions.scrubSpeed(below: below)
        speedLabel = speed.label
        let change: Double = Double((location.x - last) / width) * duration * speed.factor
        scrubTime = min(duration, max(0, current + change))
        lastX = location.x
    }

    private func finish() {
        if let target = scrubTime, let start = scrubStart, abs(target - start) > 0.5 {
            player.seek(to: target)
            if abs(target - start) >= 120 {
                let player = self.player
                let store = self.store
                store.undoAction = UndoAction(label: "Jumped to \(TimeFormat.clock(target))") {
                    player.seek(to: start)
                    store.undoAction = nil
                }
            }
        }
        scrubTime = nil
        scrubStart = nil
        lastX = nil
        speedLabel = nil
    }

    private func bubble(at time: TimeInterval, x: CGFloat, width: CGFloat) -> some View {
        let chapters: [Chapter] = player.chapters
        let title: String? = Chapters.index(at: time, in: chapters).map { chapters[$0].title }
        let bubbleWidth: CGFloat = 190
        let centre: CGFloat = min(width - bubbleWidth / 2, max(bubbleWidth / 2, x))
        return VStack(spacing: 1) {
            if let title {
                Text(title)
                    .font(Theme.outfit(12, .semibold))
                    .foregroundStyle(DeckPlayerColours.ink.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: bubbleWidth - 24)
            }
            Text(TimeFormat.clock(time))
                .font(Theme.outfit(14, .bold))
                .monospacedDigit()
                .foregroundStyle(DeckPlayerColours.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
        .fixedSize()
        .position(x: centre, y: -26)
        .allowsHitTesting(false)
    }
}

/// Draws the line: faint track, chapter gaps, ads amber, played white, and
/// the knob. `grow` (0 at rest, 1 while dragging) thickens it a little.
private struct DeckPlayerLine: View, Animatable {
    let progress: Double
    let chapterStarts: [Double]
    let ads: [ClosedRange<Double>]
    var grow: Double

    var animatableData: Double {
        get { grow }
        set { grow = newValue }
    }

    var body: some View {
        Canvas { context, size in
            Self.draw(in: context, size: size, progress: progress, chapterStarts: chapterStarts,
                      ads: ads, grow: CGFloat(grow))
        }
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private static func draw(in context: GraphicsContext, size: CGSize, progress: Double,
                             chapterStarts: [Double], ads: [ClosedRange<Double>], grow: CGFloat) {
        let knob: CGFloat = 16 + 6 * grow
        let x0: CGFloat = knob / 2
        let span: CGFloat = max(1, size.width - knob)
        let thickness: CGFloat = 6 + 4 * grow
        let top: CGFloat = (size.height - thickness) / 2
        let playedX: CGFloat = x0 + span * CGFloat(min(1, max(0, progress)))
        let track = Path(roundedRect: CGRect(x: x0, y: top, width: span, height: thickness), cornerRadius: thickness / 2)
        var line = context
        line.clip(to: track)
        line.fill(track, with: .color(Color.white.opacity(0.22)))
        for ad in ads {
            let start: CGFloat = x0 + span * CGFloat(ad.lowerBound)
            let end: CGFloat = x0 + span * CGFloat(ad.upperBound)
            line.fill(Path(CGRect(x: start, y: top, width: max(0, end - start), height: thickness)),
                      with: .color(Theme.deckAd.opacity(0.7)))
        }
        line.fill(Path(CGRect(x: x0, y: top, width: playedX - x0, height: thickness)), with: .color(Color.white))
        drawGaps(in: line, chapterStarts: chapterStarts, x0: x0, span: span, top: top, thickness: thickness)
        let knobRect = CGRect(x: playedX - knob / 2, y: (size.height - knob) / 2, width: knob, height: knob)
        var shadowed = context
        shadowed.addFilter(.shadow(color: Color.black.opacity(0.3), radius: 3, y: 2))
        shadowed.fill(Path(ellipseIn: knobRect), with: .color(Color.white))
    }

    /// Cuts a 3 pt gap at each chapter start (clear, so the backdrop shows).
    private static func drawGaps(in context: GraphicsContext, chapterStarts: [Double], x0: CGFloat,
                                 span: CGFloat, top: CGFloat, thickness: CGFloat) {
        var cutter = context
        cutter.blendMode = .clear
        for start in chapterStarts where start > 0.002 && start < 0.998 {
            let x: CGFloat = x0 + span * CGFloat(start)
            cutter.fill(Path(CGRect(x: x - 1.5, y: top, width: 3, height: thickness)), with: .color(Color.black))
        }
    }
}

// MARK: - Transport

/// Skip back, the big white play key with an ink symbol, skip forward.
struct DeckPlayerTransport: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        HStack(spacing: 40) {
            SkipButton(direction: .back, iconSize: 30, frame: 56)
            playKey
            SkipButton(direction: .forward, iconSize: 30, frame: 56)
        }
        .frame(maxWidth: .infinity)
    }

    private var playKey: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DeckPlayerColours.ink)
                .offset(x: player.isPlaying ? 0 : 2)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.white))
                .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

/// The iPhone's own volume, a thin light line between speaker icons (only
/// on taller screens).
struct DeckPlayerVolume: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .opacity(0.6)
                .accessibilityHidden(true)
            SystemVolumeSlider()
                .frame(height: 28)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .opacity(0.6)
                .accessibilityHidden(true)
        }
        .frame(height: 28)
        .padding(.horizontal, 8)
    }
}

// MARK: - Bottom row

/// One of the four along the bottom: an icon above a centred label; lit
/// (a soft light square behind the icon, bolder label) when on, dim when
/// it can't be used.
struct DeckPlayerButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let icon: String
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DeckPlayerButtonLabel(icon: icon, label: label, on: on)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? (on ? 1 : 0.78) : 0.35)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

struct DeckPlayerButtonLabel: View {
    let icon: String
    let label: String
    let on: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 38, height: 30)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.white.opacity(0.22) : Color.clear))
            Text(label)
                .font(Theme.outfit(11, on ? .heavy : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 84)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

/// AirPlay: iOS's own device picker under the icon and label; says the
/// device's name (lit) when it isn't playing on the iPhone.
struct DeckAirPlayButton: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        let device: String? = player.outputName
        DeckPlayerButtonLabel(icon: "airplayaudio", label: device ?? "AirPlay", on: device != nil)
            .opacity(device == nil ? 0.78 : 1)
            .allowsHitTesting(false)
            .background(RoutePicker(tint: .clear))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playing on \(device ?? "iPhone"). Choose another device")
            .accessibilityAddTraits(.isButton)
    }
}
