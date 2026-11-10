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
    /// Set while the player is closing itself (pull down past the top).
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

    /// Played on the left, the chapter you're in in the middle, and time
    /// left with when it will end (at this speed) on the right (Paul's
    /// pick "A3+" with the chapter between the times, 10 Nov 2026).
    private var clock: some View {
        let shown = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let endsAt: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        let endsText: String = "ENDS " + endsAt.formatted(date: .omitted, time: .shortened)
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TimeFormat.clock(shown))
                    .font(Theme.big(42))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("PLAYED")
                    .font(Theme.mono(10, .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
            }
            .layoutPriority(1)
            chapterMiddle(at: shown)
                .frame(maxWidth: .infinity)
            if player.duration > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("−" + TimeFormat.clock(left))
                        .font(Theme.big(28))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(endsText)
                        .font(Theme.mono(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                }
                .layoutPriority(1)
            }
        }
    }

    /// "CHAPTER 2 OF 5" over the chapter's name, between the two times
    /// (where the handle is while dragging). Empty when there are none.
    @ViewBuilder private func chapterMiddle(at time: TimeInterval) -> some View {
        let chapters = player.chapters
        if let index = Chapters.index(at: time, in: chapters) {
            VStack(spacing: 2) {
                Text("CHAPTER \(index + 1) OF \(chapters.count)")
                    .font(Theme.mono(9, .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                Text(chapters[index].title)
                    .font(Theme.text(13, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .lineLimit(1)
            .multilineTextAlignment(.center)
        } else {
            Color.clear.frame(height: 1)
        }
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

    /// The progress bar (Paul's pick "A3+", 10 Nov 2026): the live sound
    /// bars are the progress line, played in the artwork's colour, with a
    /// dashed line and a numbered dot where each chapter starts, ad breaks
    /// amber under a bracket marked AD, and a round handle in the middle of
    /// the playhead line. Only the handle moves it (drag it), so a stray
    /// touch never jumps the episode.
    private func scrubBar(tint: Color) -> some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        let playing = player.isPlaying && scrubTime == nil
        return GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let x = min(width, max(0, shown / duration * width))
            ZStack(alignment: .topLeading) {
                LiveScrubber(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions,
                             tint: tint, playing: playing, bands: { player.outputBands })
                Circle()
                    .fill(Theme.surface)
                    .overlay(Circle().inset(by: 2).stroke(tint, lineWidth: 3.5))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(scrubTime == nil ? 0.16 : 0.3), radius: 3, y: 2)
                    .scaleEffect(scrubTime == nil ? 1 : 1.2)
                    // A touch area just round the handle, moving with it.
                    // The handle moves by how far the finger travels, and
                    // only once it has travelled a little (Paul: a touch
                    // near the bar moved it). Placed by its centre, so it
                    // sits on the line whatever the touch area's size
                    // (build 134's handle sat a few points low).
                    .frame(width: 44, height: 52)
                    .contentShape(Rectangle())
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
                    .position(x: x, y: LiveScrubber.barCentre)
            }
            .coordinateSpace(name: "scrub")
        }
        .frame(height: LiveScrubber.height)
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

    /// Where each chapter starts, as fractions of the episode.
    private var chapterStarts: [Double] {
        guard player.duration > 0 else { return [] }
        return player.chapters.map { min(1, max(0, $0.start / player.duration)) }
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

/// The progress line made of live sound bars (see `scrubBar`). Each bar's
/// height is a fixed shape times the live sound: bars near the playhead
/// follow the low pitches, further ones the higher pitches, so the line
/// ripples out from where you are. It moves while playing and settles
/// when paused.
private struct LiveScrubber: View {
    let progress: Double
    let chapterStarts: [Double]
    let ads: [ClosedRange<Double>]
    let tint: Color
    let playing: Bool
    /// Power per pitch band, low to high; all zero when it can't be measured.
    let bands: () -> [Float]
    @State private var meter = LevelMeter()

    /// Room above the bars for the AD brackets and tags.
    static let top: CGFloat = 26
    static let barHeight: CGFloat = 58
    static let barCentre: CGFloat = top + barHeight / 2
    /// Room below the bars for the chapter dots.
    static let height: CGFloat = top + barHeight + 34
    private static let barCount = 56
    /// A fixed, uneven shape so the line reads as sound even when paused.
    private static let shape: [Double] = (0..<barCount).map { i in
        let x = Double(i)
        return 0.45 + 0.4 * abs(sin(x * 1.7) * cos(x * 0.53)) + 0.12 * Double((i * 7919) % 13) / 13
    }

    var body: some View {
        TimelineView(.animation(paused: !playing)) { context in
            let values: [Double] = meter.step(bands: playing ? bands() : [], playing: playing, time: context.date.timeIntervalSinceReferenceDate)
            Canvas { graphics, size in
                Self.drawBars(values, in: graphics, width: size.width, progress: progress, ads: ads, tint: tint)
                Self.drawMarks(in: graphics, width: size.width, progress: progress, chapterStarts: chapterStarts, ads: ads, tint: tint)
            }
        }
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private static func drawBars(_ values: [Double], in graphics: GraphicsContext, width: CGFloat, progress: Double, ads: [ClosedRange<Double>], tint: Color) {
        let gap: CGFloat = 2.5
        let barWidth: CGFloat = max(1, (width - gap * CGFloat(barCount - 1)) / CGFloat(barCount))
        let last: Int = values.count - 1
        for index in 0..<barCount {
            let fraction: Double = (Double(index) + 0.5) / Double(barCount)
            var live: Double = 0.45
            if last >= 1 {
                let position: Double = min(1, abs(fraction - progress) * 1.2) * Double(last)
                let lower: Int = min(last, Int(position))
                let upper: Int = min(last, lower + 1)
                let blend: Double = position - Double(lower)
                live = 0.45 + 0.55 * (values[lower] * (1 - blend) + values[upper] * blend)
            }
            let height: CGFloat = 6 + (barHeight - 6) * CGFloat(min(1, shape[index] * live))
            let rect = CGRect(x: CGFloat(index) * (barWidth + gap), y: barCentre - height / 2, width: barWidth, height: height)
            let played: Bool = fraction < progress
            let inAd: Bool = ads.contains { $0.contains(fraction) }
            let color: Color = inAd ? Theme.adMarker.opacity(played ? 1 : 0.45) : (played ? tint : Theme.hairline)
            graphics.fill(Path(roundedRect: rect, cornerRadius: min(2, barWidth / 2)), with: .color(color))
        }
    }

    /// Dashed chapter lines, AD brackets and tags, the playhead line and the
    /// numbered chapter dots (filled once reached, the current one ringed).
    private static func drawMarks(in graphics: GraphicsContext, width: CGFloat, progress: Double, chapterStarts: [Double], ads: [ClosedRange<Double>], tint: Color) {
        let barTop: CGFloat = top
        let barBottom: CGFloat = top + barHeight
        var dashes = Path()
        for start in chapterStarts where start > 0.005 && start < 0.995 {
            let x: CGFloat = width * CGFloat(start)
            dashes.move(to: CGPoint(x: x, y: barTop - 6))
            dashes.addLine(to: CGPoint(x: x, y: barBottom + 2))
        }
        graphics.stroke(dashes, with: .color(Theme.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

        for ad in ads {
            let start: CGFloat = width * CGFloat(ad.lowerBound)
            let end: CGFloat = width * CGFloat(ad.upperBound)
            let passed: Bool = ad.upperBound < progress
            let y: CGFloat = barTop - 8
            var bracket = Path()
            bracket.move(to: CGPoint(x: start, y: y + 5))
            bracket.addLine(to: CGPoint(x: start, y: y))
            bracket.addLine(to: CGPoint(x: end, y: y))
            bracket.addLine(to: CGPoint(x: end, y: y + 5))
            graphics.stroke(bracket, with: .color(Theme.adMarker.opacity(passed ? 1 : 0.7)), lineWidth: 2)
            let middle: CGFloat = min(width - 14, max(14, (start + end) / 2))
            let tag = CGRect(x: middle - 13, y: y - 18, width: 26, height: 16)
            graphics.fill(Path(roundedRect: tag, cornerRadius: 8), with: .color(Theme.adMarker.opacity(passed ? 1 : 0.5)))
            graphics.draw(Text("AD").font(Theme.mono(9, .bold)).foregroundColor(Color(hex: 0x5A3B0B)), at: CGPoint(x: middle, y: tag.midY))
        }

        let playheadX: CGFloat = width * CGFloat(min(1, max(0, progress)))
        let playhead = CGRect(x: playheadX - 1, y: barTop - 4, width: 2, height: barHeight + 8)
        graphics.fill(Path(roundedRect: playhead, cornerRadius: 1), with: .color(Theme.ink))

        drawDots(in: graphics, width: width, progress: progress, chapterStarts: chapterStarts, tint: tint)
    }

    private static func drawDots(in graphics: GraphicsContext, width: CGFloat, progress: Double, chapterStarts: [Double], tint: Color) {
        guard chapterStarts.count > 1 else { return }
        let y: CGFloat = top + barHeight + 18
        let radius: CGFloat = 8
        let current: Int = chapterStarts.lastIndex { $0 <= progress + 0.0001 } ?? 0
        var lastDrawn: CGFloat = -.infinity
        for (index, start) in chapterStarts.enumerated() {
            let x: CGFloat = min(width - radius - 3, max(radius + 3, width * CGFloat(start)))
            // Lots of short chapters: leave out dots that would overlap
            // (always keep the one you're in).
            guard x - lastDrawn >= 20 || index == current else { continue }
            lastDrawn = x
            let reached: Bool = start <= progress + 0.0001
            let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            graphics.fill(circle, with: .color(reached ? tint : Theme.surface))
            graphics.stroke(circle, with: .color(reached ? tint : Theme.ink.opacity(0.3)), lineWidth: 1.5)
            if index == current {
                let ring = Path(ellipseIn: CGRect(x: x - radius - 3, y: y - radius - 3, width: (radius + 3) * 2, height: (radius + 3) * 2))
                graphics.stroke(ring, with: .color(tint), lineWidth: 2)
            }
            let number = Text("\(index + 1)").font(Theme.mono(9, .bold)).foregroundColor(reached ? Theme.surface : Theme.muted)
            graphics.draw(number, at: CGPoint(x: x, y: y))
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
