import AVKit
import SwiftUI
import PodcastCore

/// The full player ("middle ground" look). The top area runs edge to edge in
/// the colour of the episode's artwork, with the artwork fading into it, and
/// switches between ARTWORK (big show name, episode title, chapter) and
/// TRANSCRIPT (live lines with find). Ad breaks show as a floating bar in
/// that area, so nothing below it moves. Below, on the sand page: the
/// counter, the wave progress bar (drag to scrub), transport keys, speed /
/// trim / boost / sleep tiles, what's next, and the episode notes.
struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss
    /// While dragging along the progress bar, where it would play from.
    @State private var scrubTime: TimeInterval?
    /// Where the handle was when the drag began (it moves by how far the
    /// finger travels, so touching near it never makes it jump).
    @State private var scrubStart: TimeInterval?
    @State private var showingChapters = false
    @State private var showingNotes = false
    @State private var transcriptEpisode: PodcastEpisode?
    @State private var showingQueue = false
    @State private var searchingTranscript = false
    /// Bumped by the notes key: scrolls down to the episode notes.
    @State private var notesJump = 0
    /// The downloaded episode's real loudness, for the progress line.
    @State private var waveform: [CGFloat]?
    @State private var closing = false
    @AppStorage("playerShowsTranscript") private var showsTranscript = false

    /// Looked up once per episode, not on every redraw: the player redraws
    /// twice a second while playing (review, 9 Nov 2026).
    @State private var currentEpisode: PodcastEpisode?

    var body: some View {
        Group {
            if let item = player.nowPlaying {
                let tint = ArtworkColors.shared.background(for: item.artworkURL) ?? Theme.display
                GeometryReader { geometry in
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        hero(item, tint: tint, top: geometry.safeAreaInsets.top)
                        VStack(spacing: 14) {
                            clock
                            scrubBar(tint: tint)
                            transport(tint: tint)
                            modeKeys(tint: tint)
                            nextUp
                            if let episode = currentEpisode {
                                EpisodeNotesText(episode: episode)
                                    .padding(.top, 6)
                                    .id("notes")
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
                // Floats over the page instead of taking room at the bottom:
                // as a safe-area inset, showing it changed the scroll area's
                // size, which flickered (Paul's recording, build 126).
                .overlay(alignment: .bottom) {
                    UndoBar()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .animation(.easeOut(duration: 0.2), value: store.undoAction?.id)
                }
                .onChange(of: notesJump) {
                    withAnimation(.easeInOut) { proxy.scrollTo("notes", anchor: .top) }
                }
                // Pull down past the top to close the player.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                    if offset < -100, !closing {
                        closing = true
                        dismiss()
                    }
                }
                .ignoresSafeArea(edges: .top)
                }
                }
                .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
                // The real shape of the episode, once it's downloaded.
                .task(id: waveformKey) {
                    waveform = nil
                    if let episode = currentEpisode, let file = store.localAudioURL(for: episode) {
                        waveform = await Waveform.levels(for: file, count: 44)
                    }
                }
            } else {
                Text("Nothing playing")
                    .foregroundStyle(Theme.muted)
                    .onAppear { dismiss() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.ink)
        .onChange(of: player.nowPlaying?.episodeID, initial: true) { _, id in
            currentEpisode = id.flatMap { store.episode($0) }
        }
        .sheet(isPresented: $showingChapters) {
            // Pulled up like the Up Next list: half height, drag for more.
            ChaptersView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotes) {
            if let episode = currentEpisode { EpisodeNotesView(episode: episode) }
        }
        .sheet(item: $transcriptEpisode) { TranscriptView(episode: $0) }
        .sheet(isPresented: $showingQueue) {
            UpNextSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .transcribeExplainer()
    }

    // MARK: Top area

    /// `top` is the status bar's height: the player fills the screen to the
    /// top edge, so the keys start below it.
    private func hero(_ item: PlayerModel.NowPlaying, tint: Color, top: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // One row: close, device, then (transcript) find, download, mark played.
            HStack(spacing: 8) {
                roundButton("chevron.down", label: "Close player") { dismiss() }
                deviceButton
                Spacer(minLength: 4)
                if showsTranscript {
                    roundButton("magnifyingglass", label: "Find in transcript") { searchingTranscript.toggle() }
                }
                roundButton("doc.text", label: "Episode notes") { notesJump += 1 }
                roundButton("checkmark", label: "Mark as played") { markPlayed() }
            }
            Group {
                if showsTranscript, let episode = currentEpisode {
                    PlayerTranscriptPanel(episode: episode, searching: $searchingTranscript)
                } else {
                    artworkContent(item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            if showsTranscript { chapterChip }
            adBar
            HStack(spacing: 8) {
                modeSwitch(tint: tint)
                roundButton("arrow.up.left.and.arrow.down.right", label: "Full transcript") { transcriptEpisode = currentEpisode }
                if let episode = currentEpisode { downloadKey(episode) }
            }
        }
        .foregroundStyle(Theme.displayText)
        .padding(.horizontal, 20)
        .padding(.top, top + 8)
        .padding(.bottom, 16)
        .frame(height: 430 + top)
        .frame(maxWidth: .infinity)
        .background {
            // The artwork fills the whole width from the top (Paul, 7 Nov
            // 2026: it sat small on the right with flat colour beside it)
            // and fades into its colour behind the titles and keys.
            ZStack(alignment: .top) {
                tint
                // No blur behind the titles (Paul, build 127: it smeared the
                // artwork); the colour fade below keeps them readable.
                GeometryReader { geometry in
                    CachedImage(url: item.artworkURL) { Color.clear }
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                }
                .opacity(showsTranscript ? 0.15 : 1)
                .accessibilityHidden(true)
                // Keeps the big white titles readable over light artwork.
                LinearGradient(stops: [.init(color: tint.opacity(0.15), location: 0),
                                       .init(color: tint.opacity(0), location: 0.22),
                                       .init(color: tint.opacity(0.7), location: 0.55),
                                       .init(color: tint.opacity(0.98), location: 0.78)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40))
        .environment(\.heroTint, tint)
    }

    private func artworkContent(_ item: PlayerModel.NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            // The show name opens the show (Paul, 9 Nov 2026).
            Button {
                if let show = currentEpisode?.podcast { store.revealShow = show }
            } label: {
                Text(item.showTitle.uppercased())
                    .font(Theme.big(58))
                    .lineLimit(3)
                    .minimumScaleFactor(0.45)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Opens the show")
            Button { showingNotes = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(item.title)
                        .font(Theme.text(18, .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the episode notes")
            chapterChip
        }
    }

    @ViewBuilder private var chapterChip: some View {
        if let index = player.currentChapterIndex {
            Button { showingChapters = true } label: {
                Text("CH \(index + 1) OF \(player.chapters.count) · \(player.chapters[index].title.uppercased()) ›")
                    .font(Theme.mono(11, .bold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.black.opacity(0.22), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chapter \(index + 1) of \(player.chapters.count), \(player.chapters[index].title)")
            .accessibilityHint("Shows all chapters")
        }
    }

    /// Where the sound is going; tap for the system device picker.
    private var deviceButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplayaudio")
            Text((player.outputName ?? "iPhone").uppercased())
                .lineLimit(1)
        }
        .font(Theme.mono(12, .bold))
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Self.keyFill, in: Capsule())
        .overlay(Capsule().stroke(Theme.displayText.opacity(0.3), lineWidth: 1))
        .allowsHitTesting(false)
        .background(RoutePicker(tint: .clear))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playing on \(player.outputName ?? "iPhone"). Choose another device")
        .accessibilityAddTraits(.isButton)
    }

    private var waveformKey: String {
        let id = player.nowPlaying?.episodeID ?? ""
        let local = currentEpisode.map { store.localAudioURL(for: $0) != nil } ?? false
        return "\(id)-\(local)"
    }

    /// Download: an arrow; a ring filling while it downloads; a filled
    /// circle once it's on the phone.
    private func downloadKey(_ episode: PodcastEpisode) -> some View {
        let local = store.localAudioURL(for: episode) != nil
        let fraction = downloads.progress[episode.episodeID]
        return Button {
            // While it downloads the key is a stop key (Paul, 9 Nov 2026).
            if fraction != nil {
                store.removeDownload(episode)
            } else if !local {
                downloads.download(episode)
            }
        } label: {
            ZStack {
                if let fraction {
                    Circle().stroke(Theme.displayText.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.04, fraction))
                        .stroke(Theme.displayText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 8, weight: .bold))
                } else {
                    Image(systemName: local ? "arrow.down.circle.fill" : "arrow.down")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(width: 22, height: 22)
            .frame(width: 40, height: 40)
            .background(Self.keyFill, in: Circle())
            .overlay(Circle().stroke(Theme.displayText.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(local)
        .accessibilityLabel(local ? "Downloaded" : fraction.map { "Stop download, \(Int($0 * 100)) percent done" } ?? "Download")
    }

    /// The top keys' fill: solid, so they stand out on any artwork (Paul,
    /// build 127: they got lost on busy artwork at 45% black).
    static var keyFill: Color { Theme.display.opacity(0.92) }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Self.keyFill, in: Circle())
            .overlay(Circle().stroke(Theme.displayText.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Marked played (with Undo); the player moves on as when an episode ends.
    private func markPlayed() {
        guard let episode = currentEpisode else { return }
        // Finishing marks it played (and keeps its place for "Next in the
        // list"); Undo brings back its played state and place.
        store.undoable("Marked played", episodes: [episode]) { player.finishEarly() }
    }

    /// While an ad plays: a floating bar with Skip ad and Not an ad. Just
    /// after a skip: Play ad / Not an ad.
    @ViewBuilder private var adBar: some View {
        if let adBreak = player.currentAd {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("AD BREAK").font(Theme.mono(11, .bold)).tracking(1)
                    Text("Show resumes at \(TimeFormat.clock(adBreak.end))").font(Theme.mono(12))
                }
                Spacer(minLength: 4)
                Button("Not an ad") { player.notAnAd(adBreak, transcripts: transcripts) }
                    .font(Theme.mono(12, .bold))
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                Button { player.skipCurrentAd() } label: {
                    Text("SKIP AD").font(Theme.mono(13, .bold)).padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(KeyButtonStyle(kind: .dark, radius: 20))
                .accessibilityLabel("Skip ad")
            }
            .foregroundStyle(Theme.adText)
            .padding(.leading, 16)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background(Theme.highlight, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        } else if let adBreak = player.lastSkippedAd {
            HStack(spacing: 8) {
                Text("Ad skipped at \(TimeFormat.clock(adBreak.start))").font(Theme.mono(12, .bold))
                Spacer(minLength: 4)
                Button("Play ad") { player.playAd(adBreak) }
                    .font(Theme.mono(12, .bold)).buttonStyle(.plain).frame(minHeight: 40)
                Button("Not an ad") { player.notAnAd(adBreak, transcripts: transcripts) }
                    .font(Theme.mono(12, .bold)).buttonStyle(.plain).frame(minHeight: 40)
            }
            .foregroundStyle(Theme.adText)
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .background(Theme.highlight, in: Capsule())
        }
    }

    private func modeSwitch(tint: Color) -> some View {
        HStack(spacing: 4) {
            switchKey("ARTWORK", on: !showsTranscript, tint: tint) { showsTranscript = false }
            switchKey("TRANSCRIPT", on: showsTranscript, tint: tint) { showsTranscript = true }
        }
        .padding(4)
        .background(.black.opacity(0.22), in: Capsule())
    }

    private func switchKey(_ title: String, on: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(12, .bold))
                .tracking(1)
                .frame(maxWidth: .infinity, minHeight: 36)
                .foregroundStyle(on ? tint : Theme.displayText)
                .background(on ? Theme.displayText : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Below

    /// Played on the left, left to go on the right with the time it will
    /// end (at this speed), and level bars moving in between while playing.
    private var clock: some View {
        let shown = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let endsAt: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        let endsText: String = "ENDS " + endsAt.formatted(date: .omitted, time: .shortened)
        return ZStack {
            // Across the whole strip, behind the numbers, boldest in the
            // middle above the play key.
            LevelBars(playing: player.isPlaying && scrubTime == nil, color: heroTint, bands: { player.outputBands })
                .frame(maxWidth: .infinity)
                .frame(height: 68)
            HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TimeFormat.clock(shown))
                    .font(Theme.big(46))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("PLAYED")
                    .font(Theme.mono(10, .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if player.duration > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("−" + TimeFormat.clock(left))
                        .font(Theme.big(30))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(endsText)
                        .font(Theme.mono(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                }
            }
            }
        }
    }

    private var heroTint: Color {
        player.nowPlaying.flatMap { ArtworkColors.shared.background(for: $0.artworkURL) } ?? Theme.display
    }

    /// A long jump with the handle might be a stray touch: offer to go
    /// back (Paul, 7 Nov 2026). Two minutes or more either way.
    private func offerUndoJump(from start: TimeInterval, to target: TimeInterval) {
        guard abs(target - start) >= 120 else { return }
        let player = self.player
        let store = self.store
        store.undoAction = UndoAction(label: "Jumped to \(TimeFormat.clock(target))") {
            player.seek(to: start)
            store.undoAction = nil
        }
    }

    /// The wave progress bar. Only the outlined handle at the current
    /// position moves it (drag it), so a stray touch never jumps the episode.
    private func scrubBar(tint: Color) -> some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        return GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let x = min(width, max(0, shown / duration * width))
            ZStack(alignment: .leading) {
                SegmentBar(progress: shown / duration, ads: adFractions, count: 44, height: 34, played: tint, track: Theme.hairline, levels: waveform)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink, lineWidth: 2))
                    .frame(width: 8, height: 32)
                    .shadow(color: .black.opacity(scrubTime == nil ? 0.1 : 0.3), radius: 4, y: 2)
                    .scaleEffect(scrubTime == nil ? 1 : 1.15)
                    // A touch area just round the handle, moving with it.
                    // The handle moves by how far the finger travels, and
                    // only once it has travelled a little (Paul: a touch
                    // near the bar moved it).
                    .frame(width: 32, height: 52)
                    .contentShape(Rectangle())
                    .offset(x: x - 16)
                    .gesture(
                        DragGesture(minimumDistance: 6, coordinateSpace: .named("scrub"))
                            .onChanged { value in
                                let start = scrubStart ?? player.currentTime
                                if scrubStart == nil { scrubStart = start }
                                let moved = value.translation.width / width * duration
                                scrubTime = min(duration, max(0, start + moved))
                            }
                            .onEnded { _ in
                                if let target = scrubTime, let start = scrubStart {
                                    player.seek(to: target)
                                    offerUndoJump(from: start, to: target)
                                }
                                scrubTime = nil
                                scrubStart = nil
                            }
                    )
            }
            .coordinateSpace(name: "scrub")
        }
        .frame(height: 40)
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue(TimeFormat.clock(shown))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.skipForwardBy()
            case .decrement: player.skipBackward()
            @unknown default: break
            }
        }
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }

    private func transport(tint: Color) -> some View {
        HStack {
            // No circle (Paul): a bigger icon, in proportion with play.
            SkipButton(direction: .back, iconSize: 36, frame: 60)
                .foregroundStyle(Theme.ink)
            Spacer()
            // Chapter keys in the gaps, when the episode has chapters (Paul).
            if hasChapters {
                chapterKey("backward.end.fill", label: "Previous chapter") { player.previousChapter() }
                Spacer()
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.displayText)
                    .frame(width: 86, height: 86)
                    .background(tint, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Spacer()
            if hasChapters {
                chapterKey("forward.end.fill", label: "Next chapter") { player.nextChapter() }
                Spacer()
            }
            // No circle (Paul): a bigger icon, in proportion with play.
            SkipButton(direction: .forward, iconSize: 36, frame: 60)
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.ink)
        .padding(.horizontal, 18)
    }

    private var hasChapters: Bool { !player.chapters.isEmpty }

    private func chapterKey(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// SPEED / TRIM / BOOST / SLEEP tiles: in the episode's colour when on.
    private func modeKeys(tint: Color) -> some View {
        HStack(spacing: 8) {
            Menu {
                Picker(player.speedIsForShow ? "Speed for this show" : "Speed", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(PlayerOptions.speeds, id: \.self) { speed in
                        Text(PlayerOptions.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                tile(PlayerOptions.speedLabel(player.speed), player.speedIsForShow ? "SHOW SPEED" : "SPEED", on: player.speed != 1, tint: tint)
            }
            .accessibilityLabel("Speed, \(PlayerOptions.speedLabel(player.speed))")

            Button { player.setTrimSilences(!player.trimSilences) } label: {
                tile(player.trimSilences ? "ON" : "OFF", "TRIM", on: player.trimSilences, tint: tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trim silences: speeds through pauses")
            .accessibilityAddTraits(player.trimSilences ? .isSelected : [])

            Button { player.setBoostVoices(!player.boostVoices) } label: {
                tile(player.boostVoices ? "ON" : "OFF", "BOOST", on: player.boostVoices, tint: tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Boost voices: makes speech clearer and more even")
            .accessibilityAddTraits(player.boostVoices ? .isSelected : [])

            Menu {
                if player.sleepTimer != nil {
                    Button("5 more minutes", systemImage: "plus.circle") { player.extendSleepTimer() }
                    Button("Turn off timer", systemImage: "moon.zzz") { player.setSleepTimer(nil) }
                }
                ForEach(SleepTimerOption.all, id: \.self) { option in
                    Button(option.label) { player.chooseSleepTimer(option) }
                }
            } label: {
                sleepTile(tint: tint)
            }
            .accessibilityLabel(player.sleepTimer == nil ? "Sleep timer" : "Sleep timer on")
        }
    }

    private func tile(_ value: String, _ label: String, on: Bool, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.big(20)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(Theme.mono(10, .bold)).tracking(0.8).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(on ? Theme.displayText : Theme.ink)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(on ? tint : Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private func sleepTile(tint: Color) -> some View {
        if let ends = player.sleepEndsAt {
            let now = Date()
            VStack(spacing: 2) {
                Text(timerInterval: now...max(ends, now), countsDown: true)
                    .font(Theme.big(20))
                    .monospacedDigit()
                Text("SLEEP").font(Theme.mono(10, .bold)).tracking(0.8)
            }
            .foregroundStyle(Theme.displayText)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(tint, in: RoundedRectangle(cornerRadius: 18))
        } else {
            tile(player.sleepTimer == .endOfEpisode ? "END" : "—", "SLEEP", on: player.sleepTimer != nil, tint: tint)
        }
    }

    /// The next episode in Up Next; tap to go back to the queue.
    /// What's next. Tap (or swipe up) to open Up Next over the player; the
    /// handle and "ALL n" show that it opens.
    @ViewBuilder private var nextUp: some View {
        let playingID = player.nowPlaying?.episodeID
        let upcoming = store.queue.filter { $0.episode.id != playingID }
        if let next = upcoming.first {
            let episode = store.episode(next.episode.id)
            Button { showingQueue = true } label: {
                VStack(spacing: 6) {
                    Capsule().fill(Theme.hairline).frame(width: 34, height: 4)
                    HStack(spacing: 12) {
                        ArtworkView(url: episode?.artwork, title: episode?.podcast?.title ?? next.episode.title, size: 42, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UP NEXT")
                                .font(Theme.mono(10, .bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.muted)
                            Text(next.episode.title)
                                .font(Theme.text(15, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("ALL \(upcoming.count)")
                        }
                        .font(Theme.mono(11, .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Theme.background, in: Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .deckCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -30 { showingQueue = true }
            })
            .accessibilityLabel("Up next: \(next.episode.title). \(upcoming.count) in Up Next")
            .accessibilityHint("Opens Up Next")
        }
    }
}

/// Little level bars between the times: they move while the episode plays
/// and settle when it's paused.
private struct LevelBars: View {
    let playing: Bool
    let color: Color
    /// Power per pitch band, low to high; all zero when it can't be measured.
    let bands: () -> [Float]
    @State private var meter = LevelMeter()

    var body: some View {
        TimelineView(.animation(paused: !playing)) { context in
            let values: [Double] = meter.step(bands: playing ? bands() : [], playing: playing, time: context.date.timeIntervalSinceReferenceDate)
            Canvas { graphics, size in
                Self.draw(values, in: graphics, size: size, color: color)
            }
        }
        .accessibilityHidden(true)
    }

    /// Thin bars across the whole width (Paul's pick "B bold 2", 10 Nov
    /// 2026): low pitches in the middle, high ones at the edges, nearly
    /// invisible at the edges behind the numbers and almost full colour in
    /// the middle.
    private static func draw(_ values: [Double], in graphics: GraphicsContext, size: CGSize, color: Color) {
        let barWidth: CGFloat = 4
        let gap: CGFloat = 3
        let count: Int = max(1, Int((size.width + gap) / (barWidth + gap)))
        let used: CGFloat = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let x0: CGFloat = (size.width - used) / 2
        let half: CGFloat = max(1, size.width / 2)
        let last: Int = values.count - 1
        guard last >= 1 else { return }
        for index in 0..<count {
            let x: CGFloat = x0 + CGFloat(index) * (barWidth + gap)
            let distance: Double = Double(min(1, abs(x + barWidth / 2 - half) / half))
            let position: Double = distance * Double(last) * 0.85
            let lower: Int = min(last, Int(position))
            let upper: Int = min(last, lower + 1)
            let blend: Double = position - Double(lower)
            let value: Double = (values[lower] * (1 - blend) + values[upper] * blend) * (1 - 0.3 * distance) + 0.03
            let height: CGFloat = 4 + (size.height - 4) * CGFloat(min(1, value))
            let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
            let opacity: Double = 0.06 + 0.82 * pow(1 - distance, 2.2)
            graphics.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color.opacity(opacity)))
        }
    }
}

/// Turns band powers into bar heights (0...1): each bar jumps up at once
/// and falls slowly, like a real meter, and the whole meter levels itself
/// to how loud the episode is, so quiet shows still fill the strip.
private final class LevelMeter {
    private var shown = [Double](repeating: 0, count: BandMeter.bandCount)
    /// The loudest band recently, in dB; eases down over a few seconds.
    private var peak: Double = -80
    private var lastTime: Double = 0

    /// How many dB below the recent loudest a bar reaches the bottom.
    private static let range: Double = 38

    func step(bands: [Float], playing: Bool, time: Double) -> [Double] {
        guard playing else {
            for index in shown.indices { shown[index] = 0 }
            lastTime = 0
            return shown
        }
        let dt: Double = lastTime == 0 ? 1.0 / 60 : min(0.05, max(0, time - lastTime))
        lastTime = time
        var target = [Double](repeating: 0, count: shown.count)
        if bands.count == shown.count, bands.contains(where: { $0 > 0 }) {
            var loudest: Double = -200
            for index in target.indices {
                // Speech has far more energy low down: tilt up the high bands.
                let decibels: Double = 10 * log10(Double(bands[index]) + 1e-12) + Double(index) * 1.0
                target[index] = decibels
                loudest = max(loudest, decibels)
            }
            peak = max(loudest, peak - 1.5 * dt)
            let floor: Double = peak - Self.range
            for index in target.indices {
                target[index] = min(1, max(0, (target[index] - floor) / Self.range))
            }
        } else {
            // No reading (some streams): a gentle made-up motion instead.
            for index in target.indices {
                let i = Double(index)
                target[index] = 0.15 + 0.3 * abs(sin(time * (2.1 + 0.15 * i) + i * 0.9))
            }
        }
        let frames: Double = dt * 60
        for index in shown.indices {
            let rising: Bool = target[index] > shown[index]
            let ease: Double = 1 - pow(1 - (rising ? 0.7 : 0.13), frames)
            shown[index] += (target[index] - shown[index]) * ease
        }
        return shown
    }
}

/// The system AirPlay / Bluetooth device picker.
private struct RoutePicker: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = tint
        view.activeTintColor = tint
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
