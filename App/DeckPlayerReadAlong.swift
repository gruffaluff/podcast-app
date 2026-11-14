import SwiftUI
import UIKit
import PodcastCore

/// Read along in Deck's player (prototype `txHtml`), white on the show's
/// colour: each line with a small speaker label above it, the line now
/// big and white, the others smaller and faded; a rule with the chapter's
/// name where a chapter starts; lines inside an ad in amber with "· AD".
/// Tap a line to play from there; touch and hold to share a clip or copy.
/// Scrolling by hand stops it following for 5 seconds (or tap Back to
/// now). Lines load as in Haar (`HaarReadAlong`): the transcript lined up
/// with Paul's own download.
struct DeckReadAlong: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var followPaused = false
    @State private var resume: Task<Void, Never>?
    @State private var clip: ClipRequest?

    private static let anchor = UnitPoint(x: 0.5, y: 0.36)

    private var isPlayingThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    private var nowIndex: Int? {
        guard isPlayingThis else { return nil }
        let time: TimeInterval = player.currentTime + 0.2
        return lines.lastIndex { $0.start <= time }
    }

    var body: some View {
        Group {
            if lines.isEmpty {
                DeckWordsOnTheWay(episode: episode)
            } else {
                list
            }
        }
        .task(id: episode.transcriptStateRaw) { load() }
        .onChange(of: episode.syncAnchorsData) { load() }
        .sheet(item: $clip) { request in
            ClipView(episode: episode, line: request.line, quote: request.quote)
                .normalColours()
        }
    }

    private func load() {
        if let transcript = transcripts.transcript(for: episode) {
            lines = TranscriptLayout.lines(from: TranscriptAlign.aligned(transcript, anchors: episode.syncAnchors).segments)
        } else {
            lines = []
        }
    }

    private var list: some View {
        let now: Int? = nowIndex
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        entry(line, index: index, now: now)
                            .id(index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 60)
            }
            .scrollIndicators(.hidden)
            .mask { Self.fade }
            .onScrollPhaseChange { _, phase in
                scrollPhaseChanged(phase)
            }
            .onChange(of: now) { _, index in
                guard let index, !followPaused else { return }
                withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(index, anchor: Self.anchor) }
            }
            .onAppear {
                if let now { proxy.scrollTo(now, anchor: Self.anchor) }
            }
            .overlay(alignment: .bottom) {
                if followPaused, let now {
                    backToNow { withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(now, anchor: Self.anchor) } }
                }
            }
        }
    }

    /// Scrolling by hand pauses following until 5 s after you let go.
    private func scrollPhaseChanged(_ phase: ScrollPhase) {
        if phase == .interacting {
            resume?.cancel()
            followPaused = true
        } else if phase == .idle, followPaused {
            resume?.cancel()
            resume = Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                followPaused = false
            }
        }
    }

    private static var fade: LinearGradient {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                               .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    private func backToNow(_ scroll: @escaping () -> Void) -> some View {
        Button {
            followPaused = false
            scroll()
        } label: {
            Text("Back to now")
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(DeckPlayerColours.ink)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
    }

    @ViewBuilder private func entry(_ line: TranscriptLayout.Line, index: Int, now: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let chapter = chapterStarting(at: index) {
                chapterRule(chapter)
            }
            row(line, index: index, now: now)
        }
    }

    private func row(_ line: TranscriptLayout.Line, index: Int, now: Int?) -> some View {
        let isNow: Bool = index == now
        let ad: Bool = isAd(line)
        let colour: Color = ad ? Theme.deckAd : Color.white
        return Button { play(from: line) } label: {
            VStack(alignment: .leading, spacing: 2) {
                if let label = label(for: line, ad: ad) {
                    Text(label)
                        .font(Theme.outfit(11, .bold))
                        .tracking(0.5)
                        .lineLimit(1)
                        .opacity(0.7)
                }
                Text(line.text)
                    .font(Theme.outfit(isNow ? 24 : 17, isNow ? .bold : .medium))
                    .lineSpacing(isNow ? 2 : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(colour.opacity(isNow ? 1 : (ad ? 0.55 : 0.45)))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.3), value: isNow)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Share a clip", systemImage: "scissors") { clip = ClipRequest(line: line, quote: line.text) }
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = line.text }
        }
        .accessibilityHint("Plays from here")
    }

    /// "SPEAKER", "SPEAKER · AD" or "AD".
    private func label(for line: TranscriptLayout.Line, ad: Bool) -> String? {
        var parts: [String] = []
        if let speaker = line.speaker, !speaker.isEmpty { parts.append(speaker.uppercased()) }
        if ad { parts.append("AD") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func isAd(_ line: TranscriptLayout.Line) -> Bool {
        guard isPlayingThis else { return false }
        return player.adBreaks.contains { $0.start <= line.start && line.start < $0.end }
    }

    private func play(from line: TranscriptLayout.Line) {
        if !isPlayingThis { player.play(episode) }
        player.seek(to: line.start)
    }

    /// The chapter that starts at this line (the first line at or after
    /// its start), if any.
    private func chapterStarting(at index: Int) -> String? {
        let chapters: [Chapter] = player.chapters
        guard isPlayingThis, !chapters.isEmpty, lines.indices.contains(index) else { return nil }
        let start: TimeInterval = lines[index].start
        let previous: TimeInterval = index > 0 ? lines[index - 1].start : -1
        guard let found = chapters.lastIndex(where: { $0.start > previous && $0.start <= start }) else { return nil }
        return chapters[found].title
    }

    private func chapterRule(_ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().frame(height: 1)
            Text(title.uppercased())
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle().frame(height: 1)
        }
        .opacity(0.6)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter: \(title)")
    }
}

/// Before there are words (prototype): "No transcript yet" with
/// Transcribe now, or "Transcribing on this iPhone · 62%" with Stop.
struct DeckWordsOnTheWay: View {
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode

    private var working: Bool {
        episode.transcriptState == .transcribing || transcripts.isQueued(episode) || transcripts.isRequested(episode)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(Theme.outfit(18, .bold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
            Text(note)
                .font(Theme.outfit(14, .medium))
                .multilineTextAlignment(.center)
                .opacity(0.7)
                .fixedSize(horizontal: false, vertical: true)
            action
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headline: String {
        let id: String = episode.episodeID
        if episode.transcriptState == .failed { return "Couldn't make a transcript" }
        if transcripts.isFetchingPublisher(episode) { return "Getting the show's transcript" }
        if episode.transcriptState == .transcribing {
            if let fraction = transcripts.progress[id] { return "Transcribing on this iPhone · \(Int(fraction * 100))%" }
            return "Transcribing on this iPhone"
        }
        if working {
            if let fraction = downloads.progress[id] { return "Downloading first · \(Int(fraction * 100))%" }
            return "Waiting to transcribe"
        }
        return "No transcript yet"
    }

    private var note: String {
        working ? "You can keep listening meanwhile." : "Made on the iPhone from the download. Takes a few minutes."
    }

    @ViewBuilder private var action: some View {
        if working {
            key("Stop") { transcripts.stop(episode) }
                .accessibilityLabel("Stop transcribing")
        } else if transcripts.canTranscribeNow(episode) {
            key(episode.transcriptState == .failed ? "Try again" : "Transcribe now") { transcripts.transcribeNow(episode) }
        }
    }

    private func key(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(DeckPlayerColours.ink)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }
}
