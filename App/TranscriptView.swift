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
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(isPresented: $namingSpeakers) {
                if let show = episode.podcast, let transcript {
                    NameSpeakersView(show: show, speakers: transcript.speakers)
                }
            }
        }
        .task(id: episode.transcriptStateRaw) { load() }
    }

    private var subtitle: String {
        guard let transcript else { return episode.title }
        let count = transcript.speakers.count
        let speakers = count > 0 ? "\(count) speaker\(count == 1 ? "" : "s") · " : ""
        return speakers + (transcript.source == .publisher ? "from the show" : "transcribed on this iPhone")
    }

    private func load() {
        transcript = transcripts.transcript(for: episode)
        blocks = transcript.map(TranscriptLayout.blocks(for:)) ?? []
        if transcript == nil { transcripts.prepare(episode, urgent: true) }
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
                            Text(TimeFormat.stamp(block.start))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                            ForEach(block.rows, id: \.self) { row in
                                switch row {
                                case .line(let line):
                                    lineView(line, speakers: speakers, names: names, current: current)
                                        .id(line.start)
                                case .music(let span):
                                    Label("Music · \(TimeFormat.stamp(span.length))", systemImage: "music.note")
                                        .font(.subheadline)
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
        let isPast = isThisEpisodePlaying && !isCurrent && line.end <= player.currentTime
        let speakerIndex = line.speaker.flatMap { speakers.firstIndex(of: $0) }
        let speakerName = line.speaker.map { names[$0] ?? $0 }

        var text = AttributedString()
        if let speakerName {
            var who = AttributedString(speakerName + " — ")
            who.foregroundColor = (speakerIndex ?? 0) % 2 == 0 ? Theme.ink : Theme.accentText
            who.font = .system(size: isCurrent ? 21 : 18, weight: .semibold, design: .serif)
            text += who
        }
        var body = AttributedString(line.text)
        body.font = .system(size: isCurrent ? 21 : 18, design: .serif)
        text += body

        let quote = (speakerName.map { "\($0): " } ?? "") + line.text
        return Text(text)
            .foregroundStyle(isPast ? Theme.muted : Theme.ink)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { playFrom(line.start) }
            .contextMenu {
                Button("Play from here", systemImage: "play") { playFrom(line.start) }
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = quote }
                ShareLink(item: shareText(quote, at: line.start)) {
                    Label("Share quote", systemImage: "square.and.arrow.up")
                }
                Button("Bookmark", systemImage: "bookmark") { bookmark(line, quote: quote) }
            }
            .accessibilityHint("Plays from \(TimeFormat.clock(line.start))")
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
        bookmarked = "Bookmarked at \(TimeFormat.clock(line.start))"
        Task {
            try? await Task.sleep(for: .seconds(2))
            bookmarked = nil
        }
    }

    // MARK: Not ready yet

    private var status: some View {
        VStack(spacing: 12) {
            Spacer()
            switch episode.transcriptState {
            case .transcribing:
                ProgressView()
                Text("Transcribing on your iPhone…")
                    .foregroundStyle(Theme.ink)
                Text("This takes a few minutes for a long episode. You can close this and come back.")
            case .failed:
                Image(systemName: "exclamationmark.bubble")
                    .font(.title)
                Text("Couldn't make a transcript for this episode.")
                    .foregroundStyle(Theme.ink)
                Button("Try again") {
                    episode.transcriptState = .none
                    transcripts.prepare(episode, urgent: true)
                }
                .buttonStyle(.bordered)
                .tint(Theme.ink)
            default:
                if store.localAudioURL(for: episode) == nil && episode.transcriptURL == nil {
                    Text("Download this episode to transcribe it.")
                        .foregroundStyle(Theme.ink)
                    Text("Transcripts are made on your iPhone from the downloaded audio.")
                } else {
                    ProgressView()
                    Text("Getting the transcript ready…")
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
            if transcript != nil {
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
            .navigationTitle("Name speakers")
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
