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
    @Environment(\.dismiss) private var dismiss
    /// While dragging along the progress bar, where it would play from.
    @State private var scrubTime: TimeInterval?
    @State private var showingChapters = false
    @State private var showingNotes = false
    @State private var transcriptEpisode: PodcastEpisode?
    @State private var showingQueue = false
    @State private var searchingTranscript = false
    /// Up Next opened below the player (not over it).
    @State private var queueOpen = false
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
                                // What the episode page showed: place in Up
                                // Next, download, transcript; then the notes.
                                EpisodeStatusRows(episode: episode)
                                    .padding(.top, 6)
                                EpisodeNotesText(episode: episode)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
                .safeAreaInset(edge: .bottom) { UndoBar().padding(.horizontal, 12) }
                // Pull down past the top to close the player.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                    if offset < -100, !closing {
                        closing = true
                        dismiss()
                    }
                }
                .ignoresSafeArea(edges: .top)
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
            // One row: close, device, then (transcript) find, mark played.
            HStack(spacing: 8) {
                roundButton("chevron.down", label: "Close player") { dismiss() }
                deviceButton
                Spacer(minLength: 4)
                if showsTranscript {
                    roundButton("magnifyingglass", label: "Find in transcript") { searchingTranscript.toggle() }
                }
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
        store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        player.finishEarly()
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
        let left = max(0, player.duration - shown)
        return HStack(alignment: .center, spacing: 12) {
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
            LevelBars(playing: player.isPlaying && scrubTime == nil, color: heroTint)
                .frame(maxWidth: .infinity)
            if player.duration > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("−" + TimeFormat.clock(left))
                        .font(Theme.big(30))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("ENDS \(Date().addingTimeInterval(left / max(player.speed, 0.5)).formatted(date: .omitted, time: .shortened))")
                        .font(Theme.mono(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
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
                SegmentBar(progress: shown / duration, ads: adFractions, count: 44, height: 34, played: tint, track: Theme.hairline)
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
            SkipButton(direction: .forward, iconSize: 24, frame: 60)
                .foregroundStyle(Theme.ink)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
        }
        .tint(Theme.ink)
        .padding(.horizontal, 18)
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
                    Button(option.label) { player.setSleepTimer(option) }
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
    /// What's next: tap to open the next few below (tap one to play it);
    /// "Edit Up Next" opens the full list to reorder or remove.
    @ViewBuilder private var nextUp: some View {
        let playingID = player.nowPlaying?.episodeID
        let upcoming = store.queue.filter { $0.episode.id != playingID }
        if let next = upcoming.first {
            let episode = store.episode(next.episode.id)
            VStack(spacing: 0) {
                Button {
                    withAnimation(.snappy) { queueOpen.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(url: episode?.artwork, title: episode?.podcast?.title ?? next.episode.title, size: 42, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UP NEXT · \(upcoming.count)")
                                .font(Theme.mono(10, .bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.muted)
                            Text(next.episode.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .rotationEffect(.degrees(queueOpen ? 180 : 0))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(queueOpen ? "Hides Up Next" : "Shows what's next")
                if queueOpen {
                    let ids = upcoming.prefix(6).map(\.episode.id)
                    let found = store.episodes(ids)
                    ForEach(Array(upcoming.prefix(6).dropFirst()), id: \.episode.id) { item in
                        if let queued = found[item.episode.id] {
                            Divider().overlay(Theme.hairline).padding(.horizontal, 12)
                            Button { player.play(queued) } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(url: queued.artwork, title: queued.podcast?.title ?? queued.title, size: 34, radius: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(queued.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                        Text(queued.podcast?.title ?? "").font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Text(queued.timeLeft.map { TimeFormat.clock($0) } ?? "")
                                        .font(Theme.mono(11)).monospacedDigit().foregroundStyle(Theme.muted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Plays it now")
                        }
                    }
                    Button { showingQueue = true } label: {
                        Text("EDIT UP NEXT ›")
                            .font(Theme.mono(11, .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.accentText)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

/// Little level bars between the times: they move while the episode plays
/// and settle when it's paused.
private struct LevelBars: View {
    let playing: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<9, id: \.self) { index in
                    let wave = playing ? abs(sin(t * (2.1 + Double(index % 3) * 0.7) + Double(index) * 1.3)) : 0.15
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: 4, height: 6 + 22 * wave)
                }
            }
            .frame(height: 30)
            .animation(.easeOut(duration: 0.2), value: playing)
        }
        .accessibilityHidden(true)
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
