import SwiftUI
import SwiftData
import UIKit
import PodcastCore

/// An episode's transcript: lines grouped under timestamps, speakers named,
/// music marked. Follows playback; tap a line to play from there; touch and
/// hold a line to copy, share or bookmark it.
struct TranscriptView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(LibraryStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let episode: PodcastEpisode

    @State private var transcript: Transcript?
    @State private var blocks: [TranscriptLayout.Block] = []
    @State private var follow = true
    @State private var namingSpeakers = false
    @State private var bookmarked: String?
    /// The line being shared as a clip.
    @State private var clipLine: ClipRequest?
    /// Ad bands Paul expanded with Show.
    @State private var shownAds: Set<TimeInterval> = []
    /// Find in transcript.
    @State private var query = ""
    @State private var matchCursor = 0
    @State private var scrollTarget: TimeInterval?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// Starts of the lines containing the find text.
    private var matchStarts: [TimeInterval] {
        guard !trimmedQuery.isEmpty else { return [] }
        var starts: [TimeInterval] = []
        for block in blocks {
            for case .line(let line) in block.rows where line.text.localizedCaseInsensitiveContains(trimmedQuery) {
                starts.append(line.start)
            }
        }
        return starts
    }

    private func jumpToMatch(_ by: Int) {
        let starts = matchStarts
        guard !starts.isEmpty else { return }
        matchCursor = ((matchCursor + by) % starts.count + starts.count) % starts.count
        follow = false
        scrollTarget = starts[matchCursor]
    }

    private var isThisEpisodePlaying: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        NavigationStack {
            Group {
                if transcript != nil {
                    lines
                } else {
                    status
                }
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Transcript").font(.headline).foregroundStyle(Theme.ink)
                        Text(subtitle).font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !(transcript?.speakers.isEmpty ?? true) {
                        Button("Name speakers") { namingSpeakers = true }
                            .foregroundStyle(Theme.accentText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Find in transcript")
            .onSubmit(of: .search) { jumpToMatch(1) }
            .onChange(of: query) {
                matchCursor = -1
                jumpToMatch(1)
            }
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(item: $clipLine) { request in
                ClipView(episode: episode, line: request.line, quote: request.quote)
            }
            .sheet(isPresented: $namingSpeakers) {
                if let show = episode.podcast, let transcript {
                    NameSpeakersView(show: show, speakers: transcript.speakers)
                }
            }
        }
        .transcribeExplainer()
        .task(id: episode.transcriptStateRaw) { load() }
        .onChange(of: episode.adBreaksData) { load() }
        .onChange(of: episode.syncAnchorsData) { load() }
    }

    private var subtitle: String {
        guard let transcript else { return episode.title }
        let count = transcript.speakers.count
        let speakers = count > 0 ? "\(count) speaker\(count == 1 ? "" : "s") · " : ""
        return speakers + (transcript.source == .publisher ? "from the show" : "transcribed on this iPhone")
    }

    private func load() {
        // Shown on the audio's clock: the show's transcript is shifted past
        // the ads inserted into Paul's copy (see TranscriptAlign).
        transcript = transcripts.transcript(for: episode).map { TranscriptAlign.aligned($0, anchors: episode.syncAnchors) }
        let ads = episode.adBreaks
        blocks = transcript.map { TranscriptLayout.blocks(for: $0, ads: ads) } ?? []
        // Publisher transcripts are just fetched; on-device ones follow the
        // schedule unless Paul taps Transcribe now.
        if transcript == nil { transcripts.prepare(episode) }
    }

    // MARK: Lines

    private var lines: some View {
        let speakers = transcript?.speakers ?? []
        let names = episode.podcast?.speakerNames ?? [:]
        let current = currentLineStart

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(blocks, id: \.start) { block in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(TimeFormat.clock(block.start))
                                .font(Theme.mono(11, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.muted)
                            ForEach(block.rows, id: \.self) { row in
                                switch row {
                                case .line(let line):
                                    lineView(line, speakers: speakers, names: names, current: current)
                                        .id(line.start)
                                case .ad(let adBreak, let adLines):
                                    adBand(adBreak, lines: adLines, speakers: speakers, names: names, current: current)
                                case .music(let span):
                                    Label("MUSIC · \(TimeFormat.stamp(span.length).uppercased())", systemImage: "music.note")
                                        .font(Theme.mono(12))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { follow = false }
            }
            .onChange(of: current) { _, start in
                guard follow, let start else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(start, anchor: .center) }
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .center) }
            }
            .onChange(of: follow) { _, on in
                if on, let current { withAnimation { proxy.scrollTo(current, anchor: .center) } }
            }
            .onAppear {
                if let current { proxy.scrollTo(current, anchor: .center) }
            }
        }
    }

    private func lineView(_ line: TranscriptLayout.Line, speakers: [String], names: [String: String], current: TimeInterval?) -> some View {
        let isCurrent = current == line.start
        let isMatch = !trimmedQuery.isEmpty && line.text.localizedCaseInsensitiveContains(trimmedQuery)
        let isFocusedMatch = isMatch && scrollTarget == line.start
        let isPast = isThisEpisodePlaying && !isCurrent && line.end <= player.currentTime
        let speakerIndex = line.speaker.flatMap { speakers.firstIndex(of: $0) }
        let speakerName = line.speaker.map { names[$0] ?? $0 }

        // Tape Deck: a mono speaker tag ("S1 · ANNA") over plain text; the
        // line playing now is larger, on a highlighted strip.
        let tag = speakerIndex.map { (index: Int) -> String in
            let short = "S\(index + 1)"
            return speakerName.map { $0 == line.speaker && $0.hasPrefix("Speaker") ? short : "\(short) · \($0.uppercased())" } ?? short
        }

        let quote = (speakerName.map { "\($0): " } ?? "") + line.text
        return VStack(alignment: .leading, spacing: 3) {
            if let tag {
                Text(tag)
                    .font(Theme.mono(10, .bold))
                    .foregroundStyle((speakerIndex ?? 0) % 2 == 0 ? Theme.ink : Theme.accentText)
            }
            Text(line.text)
                .font(Theme.text(isCurrent ? 19 : 16))
                .fontWeight(isCurrent ? .medium : .regular)
                .foregroundStyle(isPast ? Theme.muted : Theme.ink)
                .lineSpacing(3)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isCurrent ? 8 : 0)
            .padding(.horizontal, isCurrent ? 10 : 0)
            .padding(.vertical, isMatch && !isCurrent ? 6 : 0)
            .padding(.horizontal, isMatch && !isCurrent ? 8 : 0)
            .background(isMatch ? Theme.highlight : (isCurrent ? Theme.surface : .clear), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isFocusedMatch ? Theme.adText : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture { playFrom(line.start) }
            .contextMenu {
                Button("Play from here", systemImage: "play") { playFrom(line.start) }
                if isThisEpisodePlaying {
                    Button("This is playing now", systemImage: "arrow.left.and.right.text.vertical") { syncHere(line) }
                }
                Button("Share clip", systemImage: "waveform") { clipLine = ClipRequest(line: line, quote: quote) }
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = quote }
                ShareLink(item: shareText(quote, at: line.start)) {
                    Label("Share quote", systemImage: "square.and.arrow.up")
                }
                Button("Bookmark", systemImage: "bookmark") { bookmark(line, quote: quote) }
            }
            .accessibilityHint("Plays from \(TimeFormat.clock(line.start))")
    }

    /// An ad break as a dashed band; Show reveals its lines.
    private func adBand(_ adBreak: AdBreak, lines adLines: [TranscriptLayout.Line], speakers: [String], names: [String: String], current: TimeInterval?) -> some View {
        let shown = shownAds.contains(adBreak.start)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("AD \(TimeFormat.clock(adBreak.start))–\(TimeFormat.clock(adBreak.end))" + (player.skipAds ? " · SKIPPED" : ""))
                    .font(Theme.mono(11, .bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(shown ? "Hide" : "Show") {
                    if shown { shownAds.remove(adBreak.start) } else { shownAds.insert(adBreak.start) }
                }
                Button("Not an ad?") {
                    transcripts.notAnAd(adBreak, in: episode.episodeID)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accentText)
            .buttonStyle(.plain)
            if shown {
                ForEach(adLines, id: \.start) { line in
                    lineView(line, speakers: speakers, names: names, current: current)
                        .opacity(0.7)
                }
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.adMarker, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    /// Start of the line playing now (only when this episode is playing).
    private var currentLineStart: TimeInterval? {
        guard isThisEpisodePlaying else { return nil }
        let time = player.currentTime
        var found: TimeInterval?
        for block in blocks {
            for case .line(let line) in block.rows where line.start <= time + 0.2 {
                found = line.start
            }
            if block.start > time { break }
        }
        return found
    }

    /// Out of step? Paul picks the line he's hearing; from there on the
    /// transcript follows that timing.
    private func syncHere(_ line: TranscriptLayout.Line) {
        let anchors = episode.syncAnchors
        let original = TranscriptAlign.transcriptTime(forAudio: line.start, anchors: anchors)
        episode.syncAnchors = TranscriptAlign.adding(SyncAnchor(transcriptTime: original, offset: player.currentTime - original), to: anchors)
        store.save()
        follow = true
    }

    private func playFrom(_ time: TimeInterval) {
        if !isThisEpisodePlaying { player.play(episode) }
        player.seek(to: time)
        if !player.isPlaying { player.resume() }
        follow = true
    }

    private func shareText(_ quote: String, at time: TimeInterval) -> String {
        "“\(quote)”\n— \(episode.podcast?.title ?? ""), \(episode.title) (\(TimeFormat.clock(time)))"
    }

    private func bookmark(_ line: TranscriptLayout.Line, quote: String) {
        context.insert(Bookmark(episodeID: episode.episodeID, time: line.start, text: quote))
        try? context.save()
        let note = "Bookmarked at \(TimeFormat.clock(line.start))"
        bookmarked = note
        Task {
            try? await Task.sleep(for: .seconds(2))
            // Only clear this note, not a newer bookmark's.
            if bookmarked == note { bookmarked = nil }
        }
    }

    // MARK: Not ready yet

    /// Keys like the rest of the app (style rules, Paul 9 Nov 2026), not
    /// iOS's round buttons.
    private static func keyLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.mono(13, .bold))
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
    }

    private var status: some View {
        VStack(spacing: 12) {
            Spacer()
            switch episode.transcriptState {
            case .transcribing:
                ProgressView()
                Text("Transcribing on your iPhone…")
                    .foregroundStyle(Theme.ink)
                Text("This takes a few minutes for a long episode. You can close this and come back, or stop it if the phone gets warm or slow.")
                Button { transcripts.stop(episode) } label: { Self.keyLabel("Stop transcribing") }
                    .buttonStyle(KeyButtonStyle(kind: .plain, radius: 12))
            case .failed:
                Image(systemName: "exclamationmark.bubble")
                    .font(.title)
                Text("Couldn't make a transcript for this episode.")
                    .foregroundStyle(Theme.ink)
                Button { transcripts.transcribeNow(episode) } label: { Self.keyLabel("Try again") }
                    .buttonStyle(KeyButtonStyle(kind: .dark, radius: 12))
            default:
                if transcripts.canTranscribeNow(episode) {
                    Text("No transcript yet")
                        .foregroundStyle(Theme.ink)
                    Text(store.localAudioURL(for: episode) == nil
                         ? "It's made on your iPhone from the audio, so the episode downloads first."
                         : "Transcripts are made on your iPhone. " + transcripts.schedule.explanation)
                    Button { transcripts.transcribeNow(episode) } label: { Self.keyLabel("Transcribe now") }
                        .buttonStyle(KeyButtonStyle(kind: .dark, radius: 12))
                } else {
                    ProgressView()
                    Text(store.localAudioURL(for: episode) == nil ? "Downloading, then transcribing…" : "Getting the transcript ready…")
                        .foregroundStyle(Theme.ink)
                }
            }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            if let bookmarked {
                Label(bookmarked, systemImage: "bookmark.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.accentText)
            } else {
                Button {
                    if isThisEpisodePlaying { player.togglePlayPause() } else { player.play(episode) }
                } label: {
                    Image(systemName: isThisEpisodePlaying && player.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(Theme.background)
                        .frame(width: 40, height: 40)
                        .background(Theme.ink, in: Circle())
                }
                .accessibilityLabel(isThisEpisodePlaying && player.isPlaying ? "Pause" : "Play")
                if isThisEpisodePlaying {
                    Text("\(TimeFormat.clock(player.currentTime)) / \(TimeFormat.clock(player.duration)) · \(PlayerOptions.speedLabel(player.speed))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if !trimmedQuery.isEmpty {
                let count = matchStarts.count
                Text(count == 0 ? "No matches" : "\(min(max(matchCursor, 0), count - 1) + 1) of \(count)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Button { jumpToMatch(-1) } label: { Image(systemName: "chevron.up").frame(width: 36, height: 36) }
                    .disabled(count == 0)
                    .accessibilityLabel("Previous match")
                Button { jumpToMatch(1) } label: { Image(systemName: "chevron.down").frame(width: 36, height: 36) }
                    .disabled(count == 0)
                    .accessibilityLabel("Next match")
            } else if transcript != nil {
                Toggle("Follow along", isOn: $follow)
                    .toggleStyle(.button)
                    .font(.footnote.weight(.medium))
                    .tint(Theme.accentFill)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }
}

/// Rename "Speaker 1" etc. Names stick for every episode of the show.
struct NameSpeakersView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    let speakers: [String]
    @State private var names: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(speakers, id: \.self) { speaker in
                        TextField(speaker, text: Binding(get: { names[speaker] ?? "" }, set: { names[speaker] = $0 }))
                            .textInputAutocapitalization(.words)
                    }
                } footer: {
                    Text("Names are used in every transcript of \(show.title).")
                }
            }
            .navigationTitle("NAME SPEAKERS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var saved = show.speakerNames
                        for speaker in speakers {
                            let name = (names[speaker] ?? "").trimmingCharacters(in: .whitespaces)
                            saved[speaker] = name.isEmpty ? nil : name
                        }
                        show.speakerNames = saved
                        store.save()
                        dismiss()
                    }
                }
            }
            .onAppear { names = show.speakerNames }
        }
    }
}

struct ClipRequest: Identifiable {
    let line: TranscriptLayout.Line
    let quote: String
    var id: TimeInterval { line.start }
}
