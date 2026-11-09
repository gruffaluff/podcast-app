import SwiftUI
import PodcastCore

/// The player's TRANSCRIPT view: the line playing now (large), with the
/// lines before and after. A find box steps through matches ("2 of 5");
/// "Back to now" returns to the line playing. Tap a line to play from it.
/// Find opens from the magnifier in the player's top row.
/// Lives in the coloured top area, so it uses the light text colours.
struct PlayerTranscriptPanel: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    /// Find is opened from the magnifier in the player's top row.
    @Binding var searching: Bool

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var query = ""
    @State private var matchIndex = 0
    @FocusState private var fieldFocused: Bool
    /// "Share a clip" from a line (Paul: clips were too hard to find).
    @State private var clipLine: ClipRequest?

    private var isPlayingThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        // The find box floats over the top of the lines (it doesn't push
        // them down); the lines fill the area from the top.
        ZStack(alignment: .top) {
            if lines.isEmpty {
                TranscriptStatusView(episode: episode, onDark: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                window
                    .padding(.top, searching ? 52 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
            }
            if searching { searchRow }
        }
        .overlay(alignment: .bottom) { backToNow }
        .sheet(item: $clipLine) { request in
            ClipView(episode: episode, line: request.line, quote: request.quote)
        }
        .task(id: episode.transcriptStateRaw) { load() }
        .onChange(of: episode.syncAnchorsData) { load() }
        .onChange(of: query) { matchIndex = 0 }
        .onChange(of: searching) { _, on in
            fieldFocused = on
            if !on { query = "" }
        }
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
            .background(NowPlayingView.keyFill, in: RoundedRectangle(cornerRadius: 12))
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
                .background(NowPlayingView.keyFill, in: RoundedRectangle(cornerRadius: 12))
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
        // Read once per redraw (they're decoded from saved data each time).
        let names = episode.podcast?.speakerNames ?? [:]
        return VStack(alignment: .leading, spacing: 12) {
            if let focus {
                // One line before, then the line now (or the match) and what
                // follows; whatever doesn't fit is cut off at the bottom.
                let shown = searching ? [focus, focus + 1, focus + 2] : [focus - 1, focus, focus + 1, focus + 2, focus + 3]
                ForEach(shown.filter { lines.indices.contains($0) }, id: \.self) { index in
                    lineView(lines[index], isFocus: index == focus, names: names)
                }
            }
        }
    }

    /// While finding away from the line playing: a key back to it, floating
    /// at the bottom of the area.
    @ViewBuilder private var backToNow: some View {
        if searching, focusIndex != nowIndex, let now = nowIndex {
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

    /// The suspected ad break a line sits in, if any.
    private func adBreak(for line: TranscriptLayout.Line) -> AdBreak? {
        let breaks = isPlayingThis ? player.adBreaks : episode.adBreaks
        return breaks.first { $0.contains(line.start + 0.1) }
    }

    private func lineView(_ line: TranscriptLayout.Line, isFocus: Bool, names: [String: String]) -> some View {
        let speaker = line.speaker.map { names[$0] ?? $0 }
        // Lines in a suspected ad: an amber bar down the side and "AD" first.
        let ad = adBreak(for: line)
        let label = [ad == nil ? nil : "SUSPECTED AD", speaker?.uppercased(), TimeFormat.clock(line.start)].compactMap { $0 }.joined(separator: " · ")
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
                    .font(Theme.text(isFocus ? 21 : 15, isFocus ? .bold : .regular))
                    .lineLimit(isFocus ? 4 : 2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, ad == nil ? 0 : 12)
            .overlay(alignment: .leading) {
                if ad != nil {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.adMarker)
                        .frame(width: 4)
                }
            }
            .opacity(isFocus ? 1 : 0.6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The line playing now has a CLIP key; every line has Share clip
        // in its long-press menu.
        .overlay(alignment: .topTrailing) {
            if isFocus {
                Button { clipLine = ClipRequest(line: line, quote: line.text) } label: {
                    Label("CLIP", systemImage: "waveform")
                        .font(Theme.mono(10, .bold))
                        .foregroundStyle(Theme.displayText)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 26)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share a clip of this line")
            }
        }
        .contextMenu {
            Button("Share clip", systemImage: "waveform") { clipLine = ClipRequest(line: line, quote: line.text) }
        }
        .accessibilityLabel(ad == nil ? Text(line.text) : Text("Suspected ad. \(line.text)"))
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
    @Environment(DownloadManager.self) private var downloads
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    var onDark = false

    var body: some View {
        VStack(spacing: 10) {
            switch episode.transcriptState {
            case .transcribing:
                if let fraction = transcripts.progress[episode.episodeID] {
                    Text("Transcribing · \(Int(fraction * 100))%").font(.headline).monospacedDigit()
                    bar(fraction)
                } else {
                    ProgressView().tint(textColor)
                    Text("Getting ready to transcribe…").font(.headline)
                }
                Text("You can keep listening. Stop it if the phone gets warm or slow.")
                stopButton
            case .waiting where transcripts.isQueued(episode) || transcripts.isRequested(episode):
                if let fraction = downloads.progress[episode.episodeID] {
                    // Transcripts are made from the downloaded file.
                    Text("Downloading first · \(Int(fraction * 100))%").font(.headline).monospacedDigit()
                    bar(fraction)
                    Text("Then it transcribes on this iPhone.")
                } else {
                    ProgressView().tint(textColor)
                    Text("Waiting to transcribe").font(.headline)
                    Text(store.localAudioURL(for: episode) == nil ? "It downloads first, then transcribes." : transcripts.schedule.explanation)
                }
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

    private func bar(_ fraction: Double) -> some View {
        ProgressView(value: min(1, max(0, fraction)))
            .tint(textColor)
            .frame(maxWidth: 240)
            .animation(.easeOut(duration: 0.4), value: fraction)
    }

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
    /// `enabled` false while something covers this screen (e.g. the full
    /// player), so the alert shows on the top one only.
    func transcribeExplainer(enabled: Bool = true) -> some View {
        modifier(TranscribeExplainer(enabled: enabled))
    }
}

private struct TranscribeExplainer: ViewModifier {
    @Environment(TranscriptService.self) private var transcripts
    var enabled = true

    func body(content: Content) -> some View {
        content.alert("Transcribe on this iPhone?", isPresented: Binding(get: { enabled && transcripts.explainEpisode != nil }, set: { _ in })) {
            // Listed in this order, Transcribe shows on the left.
            Button("Transcribe") { transcripts.confirmExplainer() }
            Button("Not now") { transcripts.explainEpisode = nil }
        } message: {
            Text(message)
        }
    }

    private var message: String {
        let time = transcripts.typicalMinutesPerHour.map { "About \(max(1, Int($0.rounded()))) min per hour of audio." }
            ?? "A few minutes per hour of audio."
        return "Made from the download; nothing leaves your phone.\n\(time)\nUses battery while it runs. Stop it any time."
    }
}
