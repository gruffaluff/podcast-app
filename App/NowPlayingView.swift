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

    private var currentEpisode: PodcastEpisode? {
        player.nowPlaying.flatMap { store.episode($0.episodeID) }
    }

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
                .safeAreaInset(edge: .bottom) { UndoBar().padding(.horizontal, 12) }
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
        .sheet(isPresented: $showingChapters) { ChaptersView() }
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
            ZStack(alignment: .topTrailing) {
                tint
                CachedImage(url: item.artworkURL) { Color.clear }
                    .frame(width: 300, height: 300)
                    .offset(x: 50, y: 20)
                    .opacity(showsTranscript ? 0.15 : 1)
                    .mask(
                        RadialGradient(colors: [.black, .black.opacity(0)], center: UnitPoint(x: 0.6, y: 0.42), startRadius: 70, endRadius: 200)
                            .frame(width: 300, height: 300)
                            .offset(x: 50, y: 20)
                    )
                    .accessibilityHidden(true)
                // Keeps the big white titles readable over light artwork.
                LinearGradient(colors: [tint.opacity(0), tint.opacity(0.55), tint.opacity(0.95)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40))
        .environment(\.heroTint, tint)
    }

    private func artworkContent(_ item: PlayerModel.NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Text(item.showTitle.uppercased())
                .font(Theme.big(58))
                .lineLimit(3)
                .minimumScaleFactor(0.45)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                .accessibilityAddTraits(.isHeader)
            Button { showingNotes = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold))
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
            if !local && fraction == nil { downloads.download(episode) }
        } label: {
            ZStack {
                if let fraction {
                    Circle().stroke(Theme.displayText.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.04, fraction))
                        .stroke(Theme.displayText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    Image(systemName: local ? "arrow.down.circle.fill" : "arrow.down")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(width: 22, height: 22)
            .frame(width: 40, height: 40)
            .background(Self.keyFill, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(local)
        .accessibilityLabel(local ? "Downloaded" : fraction.map { "Downloading, \(Int($0 * 100)) percent" } ?? "Download")
    }

    /// The top keys' fill: dark enough to stand out on any artwork.
    static let keyFill = Color.black.opacity(0.45)

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Self.keyFill, in: Circle())
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
            // Centred on the screen, so right above the play key.
            LevelBars(playing: player.isPlaying && scrubTime == nil, color: heroTint, level: { player.outputLevel })
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
                    // A finger-sized touch area, centred on the handle and
                    // moving with it.
                    .frame(width: 44, height: 56)
                    .contentShape(Rectangle())
                    .offset(x: x - 22)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("scrub"))
                            .onChanged { value in
                                scrubTime = min(1, max(0, value.location.x / width)) * duration
                            }
                            .onEnded { _ in
                                if let target = scrubTime { player.seek(to: target) }
                                scrubTime = nil
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
            SkipButton(direction: .back, iconSize: 24, frame: 60)
                .foregroundStyle(Theme.ink)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
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
            SkipButton(direction: .forward, iconSize: 24, frame: 60)
                .foregroundStyle(Theme.ink)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
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
                                .font(.system(size: 15, weight: .bold))
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
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
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
    /// How loud the sound is right now (RMS); 0 when it can't be measured.
    let level: () -> Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !playing)) { context in
            bars(at: context.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: 60, height: 30)
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private func bars(at time: Double) -> some View {
        let loudness: Double = Self.loudness(level())
        return HStack(alignment: .center, spacing: 3) {
            ForEach(0..<9, id: \.self) { (index: Int) in
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: 4, height: Self.height(index: index, time: time, loudness: loudness, playing: playing))
            }
        }
        .frame(height: 30)
    }

    /// RMS to 0...1 (about −50 dB to −10 dB); -1 when there's no reading.
    private static func loudness(_ rms: Float) -> Double {
        guard rms > 0 else { return -1 }
        let decibels: Double = 20 * log10(Double(rms))
        return min(1, max(0, (decibels + 50) / 40))
    }

    private static func height(index: Int, time: Double, loudness: Double, playing: Bool) -> CGFloat {
        guard playing else { return 6 }
        let i = Double(index)
        // Taller in the middle, with a little movement between the bars.
        let shape: Double = 1 - abs(i - 4) / 6
        let jitter: Double = 0.75 + 0.25 * abs(sin(time * (5 + Double(index % 3)) + i * 1.7))
        // No reading (some streams): a gentle made-up motion instead.
        let amount: Double = loudness < 0 ? 0.5 * abs(sin(time * 2.3 + i)) : loudness
        return CGFloat(4 + 24 * amount * shape * jitter)
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
