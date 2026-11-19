import SwiftUI
import UIKit
import PodcastCore

/// Read along in Deck's player (prototype `txHtml`), white on the show's
/// colour: each line with a small speaker label above it, the line now
/// big and white, the others smaller and faded; a rule with the chapter's
/// name where a chapter starts; lines inside an ad in amber with "· AD".
/// Tap a line to play from there; touch and hold to share a clip or copy.
/// Scrolling by hand stops it following for 5 seconds (or tap Back to
/// now). The magnifier finds words: matches marked, "2 of 6", up / down. Lines load as in Haar (`HaarReadAlong`): the transcript lined up
/// with Paul's own download.
struct DeckReadAlong: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var followPaused = false
    @State private var resume: Task<Void, Never>?
    @State private var clip: ClipRequest?
    /// The last reported play time and when it came: the player reports
    /// twice a second, so the words are lit in between from the clock.
    @State private var anchorTime: TimeInterval = 0
    @State private var anchorDate = Date()
    /// Find in the words (Paul, 19 Nov 2026: "we need a search on the
    /// transcript page"): the lines with every word typed, which one is
    /// shown, and the box's focus.
    @State private var searching = false
    @State private var query = ""
    @State private var matches: [Int] = []
    @State private var matchIndex = 0
    @FocusState private var searchFocused: Bool

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
        .onChange(of: player.currentTime, initial: true) { _, time in
            anchorTime = time
            anchorDate = Date()
        }
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
        updateMatches(keepPlace: true)
    }

    private var searchWords: [String] {
        query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    /// The lines holding every word typed (any case or accents), as
    /// `DeckDialSearch.times` matches them.
    private func updateMatches(keepPlace: Bool = false) {
        let words: [String] = searchWords
        guard searching, !words.isEmpty else {
            matches = []
            matchIndex = 0
            return
        }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let found: [Int] = lines.indices.filter { index in
            words.allSatisfy { lines[index].text.range(of: $0, options: options) != nil }
        }
        let previous: Int? = keepPlace && matches.indices.contains(matchIndex) ? matches[matchIndex] : nil
        matches = found
        if let previous, let kept = found.firstIndex(of: previous) {
            matchIndex = kept
        } else {
            // Start at the first match from where it's playing, if any.
            let from: Int = nowIndex ?? 0
            matchIndex = found.firstIndex { $0 >= from } ?? 0
        }
    }

    private var list: some View {
        let now: Int? = nowIndex
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if searching {
                    searchBar { index in scrollToMatch(index, proxy: proxy) }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                scroller(now: now, proxy: proxy)
            }
            .overlay(alignment: .topTrailing) {
                if !searching { searchKey }
            }
            .onChange(of: query) { _, _ in
                updateMatches()
                if !matches.isEmpty { scrollToMatch(matchIndex, proxy: proxy) }
            }
        }
    }

    private func scroller(now: Int?, proxy: ScrollViewProxy) -> some View {
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
                withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo(index, anchor: Self.anchor) }
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

    // MARK: Find in the words

    private var searchKey: some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) { searching = true }
            searchFocused = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.22)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
        .padding(.top, 4)
        .accessibilityLabel("Find in the words")
    }

    private func searchBar(_ go: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.7)
                TextField("", text: $query, prompt: Text("Find in the words").foregroundStyle(Color.white.opacity(0.55)))
                    .font(Theme.outfit(16, .medium))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { step(1, go) }
                if !searchWords.isEmpty {
                    Text(matches.isEmpty ? "None" : "\(matchIndex + 1) of \(matches.count)")
                        .font(Theme.outfit(13, .semibold))
                        .monospacedDigit()
                        .opacity(0.75)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(Color.black.opacity(0.22)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            stepKey("chevron.up", label: "Previous match") { step(-1, go) }
            stepKey("chevron.down", label: "Next match") { step(1, go) }
            Button("Done") { closeSearch() }
                .font(Theme.outfit(15, .semibold))
                .buttonStyle(.plain)
                .padding(.leading, 2)
        }
        .foregroundStyle(Color.white)
        .tint(Color.white)
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func stepKey(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(matches.count < 2)
        .opacity(matches.count < 2 ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int, _ go: (Int) -> Void) {
        guard !matches.isEmpty else { return }
        matchIndex = (matchIndex + by + matches.count) % matches.count
        go(matchIndex)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Shows a match and stops following until search closes.
    private func scrollToMatch(_ index: Int, proxy: ScrollViewProxy) {
        guard matches.indices.contains(index) else { return }
        resume?.cancel()
        followPaused = true
        withAnimation(.smooth(duration: 0.4)) { proxy.scrollTo(matches[index], anchor: Self.anchor) }
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(.smooth(duration: 0.3)) { searching = false }
        query = ""
        matches = []
        matchIndex = 0
        followPaused = false
    }

    /// The words typed marked in a found line, the match being shown
    /// brighter.
    private func foundText(_ line: TranscriptLayout.Line, current: Bool) -> AttributedString {
        var text = AttributedString(line.text)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        for word in searchWords {
            var from = line.text.startIndex
            while let range = line.text.range(of: word, options: options, range: from..<line.text.endIndex) {
                if let low = AttributedString.Index(range.lowerBound, within: text),
                   let high = AttributedString.Index(range.upperBound, within: text) {
                    text[low..<high].backgroundColor = DeckDialSearch.dotColour.opacity(current ? 0.85 : 0.4)
                    text[low..<high].foregroundColor = current ? DeckPlayerColours.ink : Color.white
                }
                from = range.upperBound
            }
        }
        return text
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
                guard !Task.isCancelled, !searching || matches.isEmpty else { return }
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
        let found: Bool = searching && matches.contains(index)
        let current: Bool = found && matches.indices.contains(matchIndex) && matches[matchIndex] == index
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
                // Every line the same size (Paul, 17 Nov 2026, option A: the
                // line now used to grow to 24 pt, so the lines below jumped
                // and overlapped while the list scrolled); only the light
                // changes, like lyrics.
                Group {
                    if found {
                        Text(foundText(line, current: current))
                    } else {
                        lineText(line, isNow: isNow && !ad)
                    }
                }
                    .font(Theme.outfit(19, .semibold))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(colour.opacity(isNow || current ? 1 : (found ? 0.8 : (ad ? 0.55 : 0.4))))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.5), value: isNow)
        }
        .buttonStyle(.plain)
        .contextMenu {
            menuItems(for: line)
        }
        .accessibilityHint("Plays from here")
    }

    /// The hold menu. Its icons are dark on iOS's light menu (Paul, 17 Nov
    /// 2026: they came out white, from the player's white text).
    @ViewBuilder private func menuItems(for line: TranscriptLayout.Line) -> some View {
        Group {
            Button("Share a clip", systemImage: "scissors") { clip = ClipRequest(line: line, quote: line.text) }
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = line.text
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // The manual fix for words out of step (Paul, 16 Nov 2026, sync
            // issues again): hold the line you can hear and choose this; the
            // words from here on line up with the audio (a sync anchor, as
            // the older looks' transcript screen has).
            if isPlayingThis {
                Button("This is playing now", systemImage: "arrow.left.and.right.text.vertical") { syncHere(line) }
            }
        }
        .foregroundStyle(Color.primary)
        .tint(Color.primary)
    }

    /// Moves the words so this line sits at the play point now. The lines'
    /// times already include earlier fixes, so map back to the
    /// transcript's own time first.
    private func syncHere(_ line: TranscriptLayout.Line) {
        let anchors: [SyncAnchor] = episode.syncAnchors
        let original: TimeInterval = TranscriptAlign.transcriptTime(forAudio: line.start, anchors: anchors)
        episode.syncAnchors = TranscriptAlign.adding(SyncAnchor(transcriptTime: original, offset: player.currentTime - original), to: anchors)
        store.save()
        followPaused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// The line now has its words lit as they're said (Paul, 16 Nov 2026:
    /// "the transcript follows the sentences paragraphs but doesn't
    /// highlight words as spoken"): words said in full white, the word now
    /// white on a soft white mark, words to come faint. Transcripts time
    /// lines, not words, so the place is worked out across the line by its
    /// letters; between the player's twice-a-second reports it runs on the
    /// clock, 10 times a second, only while playing.
    @ViewBuilder private func lineText(_ line: TranscriptLayout.Line, isNow: Bool) -> some View {
        if isNow && isPlayingThis {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(litText(line, at: context.date))
            }
        } else {
            Text(line.text)
        }
    }

    /// The word now (Paul, 17 Nov 2026, option A: no block behind it): a
    /// light tint of the show's colour, so it reads on the player's dark
    /// shade of the same colour and matches the dial and ring.
    private var wordTint: Color {
        let base = UIColor(DeckRings.showColour(episode))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard base.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        let mix: CGFloat = 0.55
        return Color(red: Double(r + (1 - r) * mix), green: Double(g + (1 - g) * mix), blue: Double(b + (1 - b) * mix))
    }

    private func litText(_ line: TranscriptLayout.Line, at date: Date) -> AttributedString {
        let words: [Substring] = line.text.split(separator: " ")
        guard !words.isEmpty else { return AttributedString(line.text) }
        let span: TimeInterval = max(0.5, line.end - line.start)
        let running: Bool = player.isPlaying
        let since: TimeInterval = running ? min(0.7, max(0, date.timeIntervalSince(anchorDate))) * player.speed : 0
        let time: TimeInterval = anchorTime + since + 0.2
        let done: Double = min(1, max(0, (time - line.start) / span))
        let nowWord: Int = DeckReadAlongWords.word(at: done, in: words)
        var text = AttributedString()
        for (index, word) in words.enumerated() {
            var piece = AttributedString(String(word))
            if index < nowWord {
                piece.foregroundColor = Color.white
            } else if index == nowWord {
                piece.foregroundColor = wordTint
            } else {
                piece.foregroundColor = Color.white.opacity(0.45)
            }
            text += piece
            if index < words.count - 1 {
                var gap = AttributedString(" ")
                gap.foregroundColor = Color.white
                text += gap
            }
        }
        return text
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

/// Which word of a line is being said, from how far through the line the
/// time is (0...1), weighted by letters so long words take longer.
enum DeckReadAlongWords {
    static func word(at fraction: Double, in words: [Substring]) -> Int {
        let lengths: [Int] = words.map { (word: Substring) -> Int in word.count + 1 }
        let total: Int = max(1, lengths.reduce(0, +))
        let target: Double = fraction * Double(total)
        var passed: Int = 0
        for (index, length) in lengths.enumerated() {
            passed += length
            if Double(passed) > target { return index }
        }
        return words.count - 1
    }
}
