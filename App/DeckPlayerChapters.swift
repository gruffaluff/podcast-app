import SwiftUI
import PodcastCore

/// Chapters from Deck's player (prototype `sheetHtml` "chapters"): the
/// title, "8 chapters · from the show", then a white card per chapter
/// (number, title, "12:30 · 8m"), the one playing as the ink card with
/// NOW, earlier ones faded. Tap one to play from there. When the episode
/// has both, From the show / Auto switches between them; at the foot Stop
/// at chapter end and Skip this chapter (as in Haar's sheet).
struct DeckPlayerChaptersSheet: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                    .padding(.bottom, 4)
                rows
                DeckPlayerChaptersFooter()
                    .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Chapters")
                    .font(Theme.outfit(22, .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.outfit(16, .bold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
            Text(summary)
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
            if !player.showChapters.isEmpty && !player.autoChapters.isEmpty {
                sourceSwitch
                    .padding(.top, 6)
            }
        }
    }

    private var summary: String {
        let count: Int = player.chapters.count
        if count == 0 { return "Chapters arrive with the words." }
        let words: String = "\(count) chapter\(count == 1 ? "" : "s")"
        let fromShow: Bool = player.chapterSource == .show && !player.showChapters.isEmpty
        return words + (fromShow ? " · from the show" : " · made on your iPhone")
    }

    private var sourceSwitch: some View {
        HStack(spacing: 6) {
            sourceKey("From the show", source: .show)
            sourceKey("Auto", source: .auto)
        }
    }

    private func sourceKey(_ text: String, source: PlayerModel.ChapterSource) -> some View {
        let on: Bool = player.chapterSource == source
        return Button { player.chapterSource = source } label: {
            Text(text)
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(on ? Theme.background : Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(on ? Theme.ink : Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private var rows: some View {
        let chapters: [Chapter] = player.chapters
        let current: Int? = player.currentChapterIndex
        return ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
            Button { pick(chapter) } label: {
                DeckPlayerChapterCard(number: index + 1, chapter: chapter, end: end(of: index, in: chapters),
                                      isCurrent: index == current, isPast: index < (current ?? 0))
            }
            .buttonStyle(.plain)
        }
    }

    private func end(of index: Int, in chapters: [Chapter]) -> TimeInterval {
        if let end = chapters[index].end { return end }
        return index + 1 < chapters.count ? chapters[index + 1].start : player.duration
    }

    private func pick(_ chapter: Chapter) {
        player.play(chapter: chapter)
        dismiss()
    }
}

private struct DeckPlayerChapterCard: View {
    let number: Int
    let chapter: Chapter
    let end: TimeInterval
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(Theme.outfit(18, .heavy))
                .monospacedDigit()
                .frame(minWidth: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(chapter.title)
                    .font(Theme.outfit(15, .bold))
                    .lineLimit(2)
                Text(meta)
                    .font(Theme.outfit(12, .medium))
                    .monospacedDigit()
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCurrent {
                Text("NOW")
                    .font(Theme.outfit(11, .heavy))
                    .tracking(0.6)
            }
        }
        .foregroundStyle(isCurrent ? Color.white : Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background { card }
        .opacity(isPast ? 0.55 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    @ViewBuilder private var card: some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.playingCard)
        } else {
            Color.clear.deckPlainCard(radius: 18)
        }
    }

    private var meta: String {
        var parts: [String] = [TimeFormat.clock(chapter.start)]
        let length: TimeInterval = end - chapter.start
        if length > 0 { parts.append(TimeFormat.length(length)) }
        if chapter.isAd { parts.append("Skipped") }
        return parts.joined(separator: " · ")
    }
}

/// Stop at chapter end · Skip this chapter.
private struct DeckPlayerChaptersFooter: View {
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
        let enabled: Bool = !player.chapters.isEmpty && player.nowPlaying != nil
        return Button { player.setStopAtChapterEnd(!on) } label: {
            Label(on ? "Stops at chapter end" : "Stop at chapter end", systemImage: on ? "moon.fill" : "moon")
                .font(Theme.outfit(15, on ? .bold : .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var skipButton: some View {
        let index: Int = player.currentChapterIndex ?? -1
        let enabled: Bool = index >= 0 && index < player.chapters.count - 1
        return Button { player.nextChapter() } label: {
            Label("Skip this chapter", systemImage: "forward.end")
                .font(Theme.outfit(15, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
