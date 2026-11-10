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
    /// Where it was when the drag began (it moves by how far the finger
    /// travels, so a touch on the line never makes it jump).
    @State private var scrubStart: TimeInterval?
    /// The finger's last position along the line while scrubbing.
    @State private var scrubLastX: CGFloat?
    /// "HALF-SPEED SCRUBBING" etc. while the finger is below the line.
    @State private var scrubSpeed: String?
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

    /// A long jump while scrubbing might be a stray touch: offer to go
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

    /// The progress line (Paul's pick "T4 firm", 10 Nov 2026, after Apple
    /// Podcasts' scrubber): a 10-point line split by gaps at chapters, ads
    /// amber, no handle, and the times under each end with when it ends in
    /// the middle. Touch it anywhere and drag: it grows to 20 points and a
    /// little wider, a bubble shows the chapter and time, and it moves by
    /// how far the finger travels (so a touch alone never jumps). Sliding
    /// the finger down while dragging slows it: half, quarter, fine.
    private func scrubBar(tint: Color) -> some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        let active = scrubTime != nil
        let left: TimeInterval = max(0, player.duration - shown)
        let endsAt: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        let middle: String = scrubSpeed ?? ("ENDS " + endsAt.formatted(date: .omitted, time: .shortened))
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                ProgressLine(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions,
                             tint: tint, grow: active ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: active)
                    .frame(width: width + 2 * ProgressLine.stretch, height: ProgressLine.height)
                    .offset(x: -ProgressLine.stretch)
                    .overlay(alignment: .topLeading) {
                        if active { scrubBubble(at: shown, x: shown / duration * width, width: width) }
                    }
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: width, duration: duration))
            }
            .frame(height: ProgressLine.height)
            HStack(alignment: .firstTextBaseline) {
                Text(TimeFormat.clock(shown))
                    .font(Theme.mono(16, .bold))
                Spacer(minLength: 6)
                Text(middle)
                    .font(Theme.mono(10, .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("−" + TimeFormat.clock(left))
                    .font(Theme.mono(16, .bold))
            }
            .monospacedDigit()
            .foregroundStyle(Theme.ink)
        }
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue("\(TimeFormat.clock(shown)), \(TimeFormat.clock(left)) left")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.skipForwardBy()
            case .decrement: player.skipBackward()
            @unknown default: break
            }
        }
    }

    private func scrubGesture(width: CGFloat, duration: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let lastX = scrubLastX, let current = scrubTime else {
                    scrubStart = player.currentTime
                    scrubTime = player.currentTime
                    scrubLastX = value.location.x
                    scrubSpeed = PlayerOptions.scrubSpeed(below: 0).label
                    return
                }
                let below: Double = Double(value.location.y - ProgressLine.height / 2)
                let speed = PlayerOptions.scrubSpeed(below: below)
                scrubSpeed = speed.label
                let moved: Double = Double((value.location.x - lastX) / width) * duration * speed.factor
                scrubTime = min(duration, max(0, current + moved))
                scrubLastX = value.location.x
            }
            .onEnded { _ in
                if let target = scrubTime, let start = scrubStart, abs(target - start) > 0.5 {
                    player.seek(to: target)
                    offerUndoJump(from: start, to: target)
                }
                scrubTime = nil
                scrubStart = nil
                scrubLastX = nil
                scrubSpeed = nil
            }
    }

    /// The chapter and time above the finger while scrubbing: a paper card
    /// with a shadow, so it reads clearly over the artwork area above.
    private func scrubBubble(at time: TimeInterval, x: CGFloat, width: CGFloat) -> some View {
        let chapters = player.chapters
        let title: String? = Chapters.index(at: time, in: chapters).map { chapters[$0].title }
        let bubbleWidth: CGFloat = 190
        let centre: CGFloat = min(width - bubbleWidth / 2, max(bubbleWidth / 2, x)) + ProgressLine.stretch
        return VStack(spacing: 1) {
            if let title {
                Text(title)
                    .font(Theme.text(12, .semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .frame(maxWidth: bubbleWidth - 24)
            }
            Text(TimeFormat.clock(time))
                .font(Theme.mono(14, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
        .fixedSize()
        .position(x: centre, y: -30)
        .allowsHitTesting(false)
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

/// The progress line's drawing (see `scrubBar`): split by small gaps at
/// chapters, played part in the artwork's colour, ad breaks amber. `grow`
/// (0 at rest, 1 while scrubbing) animates it thicker and a little wider.
private struct ProgressLine: View, Animatable {
    let progress: Double
    let chapterStarts: [Double]
    let ads: [ClosedRange<Double>]
    let tint: Color
    var grow: Double

    var animatableData: Double {
        get { grow }
        set { grow = newValue }
    }

    static let rest: CGFloat = 10
    static let scrubbing: CGFloat = 20
    /// How much wider each side it gets while scrubbing (the view is drawn
    /// this much wider than its slot).
    static let stretch: CGFloat = 8
    static let height: CGFloat = 24
    private static let gap: CGFloat = 3

    var body: some View {
        Canvas { graphics, size in
            Self.draw(in: graphics, size: size, progress: progress, chapterStarts: chapterStarts, ads: ads, tint: tint, grow: CGFloat(grow))
        }
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private static func draw(in graphics: GraphicsContext, size: CGSize, progress: Double, chapterStarts: [Double], ads: [ClosedRange<Double>], tint: Color, grow: CGFloat) {
        let inset: CGFloat = stretch * (1 - grow)
        let x0: CGFloat = inset
        let span: CGFloat = max(1, size.width - 2 * inset)
        let thickness: CGFloat = rest + (scrubbing - rest) * grow
        let top: CGFloat = (size.height - thickness) / 2
        let playedX: CGFloat = x0 + span * CGFloat(min(1, max(0, progress)))
        let inner: [Double] = chapterStarts.filter { $0 > 0.002 && $0 < 0.998 }.sorted()
        let cuts: [Double] = [0] + inner + [1]
        for index in 0..<(cuts.count - 1) {
            let start: CGFloat = x0 + span * CGFloat(cuts[index]) + (index > 0 ? gap / 2 : 0)
            let end: CGFloat = x0 + span * CGFloat(cuts[index + 1]) - (index < cuts.count - 2 ? gap / 2 : 0)
            guard end > start else { continue }
            let shape = Path(roundedRect: CGRect(x: start, y: top, width: end - start, height: thickness), cornerRadius: thickness / 2)
            var segment = graphics
            segment.clip(to: shape)
            segment.fill(shape, with: .color(Theme.hairline))
            for ad in ads {
                let adStart: CGFloat = max(start, x0 + span * CGFloat(ad.lowerBound))
                let adEnd: CGFloat = min(end, x0 + span * CGFloat(ad.upperBound))
                guard adEnd > adStart else { continue }
                segment.fill(Path(CGRect(x: adStart, y: top, width: adEnd - adStart, height: thickness)), with: .color(Theme.adMarker.opacity(0.45)))
            }
            if playedX > start {
                segment.fill(Path(CGRect(x: start, y: top, width: min(end, playedX) - start, height: thickness)), with: .color(tint))
                for ad in ads {
                    let adStart: CGFloat = max(start, x0 + span * CGFloat(ad.lowerBound))
                    let adEnd: CGFloat = min(end, playedX, x0 + span * CGFloat(ad.upperBound))
                    guard adEnd > adStart else { continue }
                    segment.fill(Path(CGRect(x: adStart, y: top, width: adEnd - adStart, height: thickness)), with: .color(Theme.adMarker))
                }
            }
        }
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
