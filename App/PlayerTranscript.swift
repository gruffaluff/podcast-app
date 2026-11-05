import SwiftUI
import PodcastCore

/// The player's TRANSCRIPT view: the line playing now (large), with the
/// lines before and after. A find box steps through matches ("2 of 5");
/// "Back to now" returns to the line playing. Tap a line to play from it.
/// Lives in the coloured top area, so it uses the light text colours.
struct PlayerTranscriptPanel: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var searching = false
    @State private var query = ""
    @State private var matchIndex = 0
    @FocusState private var fieldFocused: Bool

    private var isPlayingThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if searching { searchRow } else { headerRow }
            if lines.isEmpty {
                TranscriptStatusView(episode: episode, onDark: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                window
            }
        }
        .task(id: episode.transcriptStateRaw) { load() }
        .onChange(of: episode.syncAnchorsData) { load() }
        .onChange(of: query) { matchIndex = 0 }
    }

    private func load() {
        if let transcript = transcripts.transcript(for: episode) {
            lines = TranscriptLayout.lines(from: TranscriptAlign.aligned(transcript, anchors: episode.syncAnchors).segments)
        } else {
            lines = []
        }
    }

    // MARK: Find

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var matches: [Int] {
        guard !trimmedQuery.isEmpty else { return [] }
        return lines.indices.filter { lines[$0].text.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private var headerRow: some View {
        HStack {
            Text(transcriptSource.uppercased())
                .font(Theme.mono(11, .bold))
                .tracking(1)
                .opacity(0.8)
            Spacer()
            Button {
                searching = true
                fieldFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.22), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Find in transcript")
            .disabled(lines.isEmpty)
        }
    }

    private var transcriptSource: String {
        guard !lines.isEmpty else { return "Transcript" }
        return transcripts.transcript(for: episode)?.source == .publisher ? "Transcript from the show" : "Transcribed on this iPhone"
    }

    private var searchRow: some View {
        let found = matches
        return HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.footnote.weight(.bold))
                TextField("Find in transcript", text: $query)
                    .focused($fieldFocused)
                    .submitLabel(.search)
                    .onSubmit { step(1) }
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Theme.displayText)
                Text(found.isEmpty ? (trimmedQuery.isEmpty ? "" : "0") : "\(matchIndex % found.count + 1) of \(found.count)")
                    .font(Theme.mono(12, .bold))
                    .monospacedDigit()
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
            roundKey("chevron.up", label: "Previous match") { step(-1) }.disabled(found.isEmpty)
            roundKey("chevron.down", label: "Next match") { step(1) }.disabled(found.isEmpty)
            roundKey("xmark", label: "Close find") {
                searching = false
                query = ""
                fieldFocused = false
            }
        }
    }

    private func roundKey(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int) {
        let count = matches.count
        guard count > 0 else { return }
        matchIndex = ((matchIndex + by) % count + count) % count
    }

    // MARK: Lines

    /// The line playing now (when this episode is playing).
    private var nowIndex: Int? {
        guard isPlayingThis else { return nil }
        let time = player.currentTime + 0.2
        return lines.lastIndex { $0.start <= time }
    }

    /// The line in the middle: the current match while finding, else now.
    private var focusIndex: Int? {
        let found = matches
        if searching, !found.isEmpty { return found[matchIndex % found.count] }
        return nowIndex ?? (lines.isEmpty ? nil : 0)
    }

    private var window: some View {
        let focus = focusIndex
        return VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)
            if let focus {
                let shown = searching ? [focus - 1, focus] : [focus - 1, focus, focus + 1]
                ForEach(shown.filter { lines.indices.contains($0) }, id: \.self) { index in
                    lineView(lines[index], isFocus: index == focus)
                }
            }
            if searching, focus != nowIndex, let now = nowIndex {
                HStack {
                    Spacer()
                    Button {
                        searching = false
                        query = ""
                        fieldFocused = false
                    } label: {
                        Text("↓ BACK TO NOW · \(TimeFormat.clock(lines[now].start))")
                            .font(Theme.mono(12, .bold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.displayText, in: Capsule())
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
    }

    private func lineView(_ line: TranscriptLayout.Line, isFocus: Bool) -> some View {
        let names = episode.podcast?.speakerNames ?? [:]
        let speaker = line.speaker.map { names[$0] ?? $0 }
        let label = [speaker?.uppercased(), TimeFormat.clock(line.start)].compactMap { $0 }.joined(separator: " · ")
        return Button {
            if !isPlayingThis { player.play(episode) }
            player.seek(to: line.start)
            if !player.isPlaying { player.resume() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Theme.mono(10, .bold))
                    .tracking(1.2)
                    .foregroundStyle(isFocus ? Theme.adMarker : Theme.displayText)
                Text(highlighted(line.text))
                    .font(.system(size: isFocus ? 21 : 15, weight: isFocus ? .bold : .regular))
                    .lineLimit(isFocus ? 4 : 2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isFocus ? 1 : 0.6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Plays from \(TimeFormat.clock(line.start))")
    }

    /// The text with every match of the find box marked.
    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let needle = trimmedQuery
        guard searching, !needle.isEmpty else { return result }
        var from = result.startIndex
        while from < result.endIndex, let range = result[from...].range(of: needle, options: .caseInsensitive) {
            result[range].backgroundColor = Theme.highlight
            result[range].foregroundColor = Theme.ink
            from = range.upperBound
        }
        return result
    }
}

/// What to show when an episode has no transcript yet: Transcribe now,
/// progress with Stop, or Try again. Used by the player and the transcript
/// screen.
struct TranscriptStatusView: View {
    @Environment(TranscriptService.self) private var transcripts
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    var onDark = false

    var body: some View {
        VStack(spacing: 10) {
            switch episode.transcriptState {
            case .transcribing:
                ProgressView().tint(textColor)
                Text("Transcribing on this iPhone…").font(.headline)
                Text("You can keep listening. Stop it if the phone gets warm or slow.")
                stopButton
            case .waiting where transcripts.isQueued(episode):
                Text("Waiting to transcribe").font(.headline)
                Text(store.localAudioURL(for: episode) == nil ? "It downloads first, then transcribes." : transcripts.schedule.explanation)
                stopButton
            case .failed:
                Text("Couldn't make a transcript for this episode.").font(.headline)
                Button("Try again") { transcripts.transcribeNow(episode) }
                    .buttonStyle(KeyButtonStyle(kind: onDark ? .plain : .dark))
            default:
                if episode.transcriptURL != nil && transcripts.isFetchingPublisher(episode) {
                    ProgressView().tint(textColor)
                    Text("Getting the show's transcript…").font(.headline)
                } else {
                    Text("No transcript yet").font(.headline)
                    Text("Made on this iPhone from the downloaded audio. Nothing leaves your phone.")
                    Button { transcripts.transcribeNow(episode) } label: {
                        Text("TRANSCRIBE").font(Theme.mono(13, .bold)).padding(.horizontal, 18).frame(minHeight: 44)
                    }
                    .buttonStyle(KeyButtonStyle(kind: onDark ? .plain : .dark))
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(textColor)
        .multilineTextAlignment(.center)
    }

    private var textColor: Color { onDark ? Theme.displayText : Theme.ink }

    private var stopButton: some View {
        Button { transcripts.stop(episode) } label: {
            Text("STOP").font(Theme.mono(13, .bold)).padding(.horizontal, 18).frame(minHeight: 44)
        }
        .buttonStyle(KeyButtonStyle(kind: onDark ? .plain : .dark))
        .accessibilityLabel("Stop transcribing")
    }
}

extension View {
    /// The one-off explainer shown the first time Transcribe is tapped. Put
    /// on the root and on each sheet that has a Transcribe key, so it shows
    /// on top of whatever is open.
    func transcribeExplainer() -> some View {
        modifier(TranscribeExplainer())
    }
}

private struct TranscribeExplainer: ViewModifier {
    @Environment(TranscriptService.self) private var transcripts

    func body(content: Content) -> some View {
        content.alert("Transcripts on your iPhone", isPresented: Binding(get: { transcripts.explainEpisode != nil }, set: { _ in })) {
            Button("Transcribe") { transcripts.confirmExplainer() }
            Button("Cancel", role: .cancel) { transcripts.explainEpisode = nil }
        } message: {
            Text(message)
        }
    }

    private var message: String {
        let estimate = transcripts.typicalMinutesPerHour.map { "On this iPhone an hour of audio takes about \(max(1, Int($0.rounded()))) minutes." }
            ?? "An hour of audio usually takes a few minutes on a recent iPhone, and longer on older ones."
        return "Poddeck makes transcripts on this iPhone from the downloaded audio, so nothing leaves your phone. \(estimate) While it runs it uses battery and can make the phone warm or a little slower, especially older iPhones. Setting transcripts to \"While charging\" is gentler, and you can stop a transcript at any time."
    }
}
