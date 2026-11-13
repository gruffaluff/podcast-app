import SwiftUI
import PodcastCore

/// The Haar chapters sheet (prototype "v4 · Poddeck, Haar look"): a
/// timeline of the episode's chapters with the one playing now large in
/// the serif, "Stop at chapter end" and "Skip this chapter" at the foot.
/// With no chapters yet it explains they come with the transcript.
/// Presented with `.sheet { HaarChaptersSheet() }`; it styles its own sheet.
struct HaarChaptersSheet: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HaarChaptersHeader(episodeTitle: player.nowPlaying?.title ?? "")
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
            if player.chapters.isEmpty {
                HaarChaptersEmpty(episode: episode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HaarChapterTimeline(onPick: pick)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HaarChaptersFooter()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .transcribeExplainer()
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(36)
        .presentationBackground { HaarChaptersBackground() }
    }

    private var episode: PodcastEpisode? {
        guard let id = player.nowPlaying?.episodeID else { return nil }
        return store.episode(id)
    }

    private func pick(_ chapter: Chapter) {
        player.play(chapter: chapter)
        dismiss()
    }
}

/// Frosted, nearly opaque mist: rgba(240,241,240,.9) over thin material.
private struct HaarChaptersBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color(red: 240 / 255, green: 241 / 255, blue: 240 / 255).opacity(0.9)
        }
        .ignoresSafeArea()
    }
}

/// Small bold spaced capitals (11 pt, 700, tracking 1.3).
private struct HaarChaptersLabel: View {
    let text: String
    var colour: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(colour)
            .lineLimit(1)
    }
}

// MARK: Header

private struct HaarChaptersHeader: View {
    @Environment(PlayerModel.self) private var player
    let episodeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Chapters")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                HaarChaptersLabel(text: sourceTag, colour: Theme.accentText)
            }
            if !episodeTitle.isEmpty {
                Text(episodeTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            if bothSources {
                HaarSourceSwitch()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bothSources: Bool {
        !player.showChapters.isEmpty && !player.autoChapters.isEmpty
    }

    private var sourceTag: String {
        if player.chapters.isEmpty { return "Waiting" }
        return HaarChaptersSource.isAuto(player) ? "Auto" : "From the show"
    }
}

enum HaarChaptersSource {
    /// Whether the list on show is the auto-generated one (same rule as
    /// `PlayerModel.chapters`).
    @MainActor static func isAuto(_ player: PlayerModel) -> Bool {
        player.chapterSource == .auto || player.showChapters.isEmpty
    }
}

/// From the show / Auto-generated as two underlined words.
private struct HaarSourceSwitch: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        HStack(spacing: 18) {
            word("From the show", source: .show)
            word("Auto-generated", source: .auto)
        }
    }

    private func word(_ label: String, source: PlayerModel.ChapterSource) -> some View {
        let on: Bool = player.chapterSource == source
        return Button {
            player.chapterSource = source
        } label: {
            Text(label)
                .font(.system(size: 14, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.ink : Theme.muted)
                .underline(on, color: Theme.accentFill)
                .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: No chapters yet

private struct HaarChaptersEmpty: View {
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode?

    var body: some View {
        VStack(spacing: 14) {
            Text("Chapters arrive with the words.")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14))
                .lineSpacing(7)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            action
                .padding(.top, 4)
        }
        .padding(.horizontal, 36)
    }

    private var hasTranscript: Bool { episode?.transcriptState == .ready }

    private var message: String {
        hasTranscript
            ? "Poddeck marks the topic changes once the transcript is done."
            : "This show doesn't send its own, so Poddeck will mark the topic changes once the transcript is done."
    }

    @ViewBuilder private var action: some View {
        if let episode, !hasTranscript {
            if transcripts.isQueued(episode) {
                Text(progressText(episode))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            } else if transcripts.canTranscribeNow(episode) {
                Button {
                    transcripts.transcribeNow(episode)
                } label: {
                    Text("Transcribe now")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func progressText(_ episode: PodcastEpisode) -> String {
        if let fraction = transcripts.progress[episode.episodeID] {
            return "Transcribing · \(Int((fraction * 100).rounded()))%"
        }
        return "Waiting to transcribe"
    }
}

// MARK: Timeline

private enum HaarChapterPlace { case past, current, future }

private struct HaarChapterTimeline: View {
    @Environment(PlayerModel.self) private var player
    let onPick: (Chapter) -> Void

    var body: some View {
        let chapters: [Chapter] = player.chapters
        let current: Int = player.currentChapterIndex ?? -1
        let auto: Bool = HaarChaptersSource.isAuto(player)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                        row(index: index, chapter: chapter, current: current, count: chapters.count, auto: auto)
                            .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard current >= 0 else { return }
                proxy.scrollTo(current, anchor: .center)
            }
        }
    }

    private func row(index: Int, chapter: Chapter, current: Int, count: Int, auto: Bool) -> some View {
        let place: HaarChapterPlace = index < current ? .past : (index == current ? .current : .future)
        let end: TimeInterval = chapterEnd(index: index, chapter: chapter)
        return Button {
            onPick(chapter)
        } label: {
            HaarChapterRow(chapter: chapter, place: place, end: end,
                           now: player.currentTime, isFirst: index == 0,
                           isLast: index == count - 1, lineAboveLit: index <= current,
                           lineBelowLit: index < current, auto: auto)
        }
        .buttonStyle(.plain)
    }

    private func chapterEnd(index: Int, chapter: Chapter) -> TimeInterval {
        if let end = chapter.end, end > chapter.start { return end }
        let chapters = player.chapters
        if index + 1 < chapters.count { return chapters[index + 1].start }
        return max(player.duration, chapter.start)
    }
}

private struct HaarChapterRow: View {
    let chapter: Chapter
    let place: HaarChapterPlace
    let end: TimeInterval
    let now: TimeInterval
    let isFirst: Bool
    let isLast: Bool
    let lineAboveLit: Bool
    let lineBelowLit: Bool
    let auto: Bool

    var body: some View {
        content
            .padding(.leading, 36)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                HaarChapterRail(place: place, showAbove: !isFirst, showBelow: !isLast,
                                aboveLit: lineAboveLit, belowLit: lineBelowLit)
                    .frame(width: 22)
            }
            .contentShape(Rectangle())
            .opacity(place == .past ? 0.55 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(place == .current ? .isSelected : [])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(meta)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                if auto { HaarChaptersLabel(text: "Auto", colour: Theme.accentText) }
            }
            title
            if place == .current { HaarChapterProgress(start: chapter.start, end: end, now: now) }
        }
    }

    @ViewBuilder private var title: some View {
        if place == .current {
            Text(chapter.title)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.accentText)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(chapter.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
        }
    }

    private var meta: String {
        let length: TimeInterval = max(0, end - chapter.start)
        let minutes: Int = max(1, Int((length / 60).rounded()))
        var text = TimeFormat.clock(chapter.start)
        if length > 0 { text += " · \(minutes) min" }
        if chapter.isAd { text += " · Sponsor break" }
        return text
    }
}

/// The line down the left and the chapter's node on it.
private struct HaarChapterRail: View {
    let place: HaarChapterPlace
    let showAbove: Bool
    let showBelow: Bool
    let aboveLit: Bool
    let belowLit: Bool

    var body: some View {
        VStack(spacing: 0) {
            segment(lit: aboveLit, shown: showAbove)
                .frame(height: 10)
            node
                .frame(width: 22, height: 22)
            segment(lit: belowLit, shown: showBelow)
                .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 0)
        .accessibilityHidden(true)
    }

    private func segment(lit: Bool, shown: Bool) -> some View {
        Rectangle()
            .fill(lit ? Theme.accentFill.opacity(0.35) : Theme.ink.opacity(0.12))
            .frame(width: 2)
            .opacity(shown ? 1 : 0)
    }

    @ViewBuilder private var node: some View {
        switch place {
        case .current:
            Circle()
                .fill(Theme.accentFill)
                .frame(width: 16, height: 16)
                .background {
                    Circle().fill(Theme.accentFill.opacity(0.18)).frame(width: 28, height: 28)
                }
        case .past:
            Circle()
                .fill(Theme.accentFill.opacity(0.45))
                .frame(width: 12, height: 12)
        case .future:
            Circle()
                .strokeBorder(Theme.ink.opacity(0.3), lineWidth: 1.5)
                .background(Circle().fill(Color(red: 240 / 255, green: 241 / 255, blue: 240 / 255)))
                .frame(width: 12, height: 12)
        }
    }
}

/// The playing chapter's 4 pt progress and time left in it.
private struct HaarChapterProgress: View {
    let start: TimeInterval
    let end: TimeInterval
    let now: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar
            Text(leftText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 4)
    }

    private var fraction: Double {
        let length = end - start
        guard length > 0 else { return 0 }
        return min(1, max(0, (now - start) / length))
    }

    private var bar: some View {
        let shape = Capsule()
        return shape
            .fill(Theme.ink.opacity(0.12))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    shape.fill(Theme.accentFill)
                        .frame(width: geo.size.width * fraction, height: 4)
                }
            }
    }

    private var leftText: String {
        let left: TimeInterval = max(0, end - now)
        if left < 60 { return "Under a minute left in this chapter" }
        let minutes = Int((left / 60).rounded(.up))
        return "\(minutes) min left in this chapter"
    }
}

// MARK: Footer

private struct HaarChaptersFooter: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            stopButton
            Spacer(minLength: 8)
            skipButton
        }
    }

    private var stopButton: some View {
        let on: Bool = player.stopsAtChapterEnd
        return Button {
            player.setStopAtChapterEnd(!on)
        } label: {
            Label(on ? "Stops at chapter end" : "Stop at chapter end", systemImage: on ? "moon.fill" : "moon")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? Theme.accentText : Theme.ink)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(player.chapters.isEmpty || player.nowPlaying == nil)
        .opacity(player.chapters.isEmpty ? 0.4 : 1)
    }

    private var skipButton: some View {
        let enabled: Bool = hasNextChapter
        return Button {
            player.nextChapter()
        } label: {
            Label("Skip this chapter", systemImage: "forward.end")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var hasNextChapter: Bool {
        guard player.nowPlaying != nil, !player.chapters.isEmpty else { return false }
        let next = (player.currentChapterIndex ?? -1) + 1
        return next < player.chapters.count
    }
}
