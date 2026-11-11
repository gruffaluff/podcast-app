import AVKit
import SwiftUI
import PodcastCore

/// The full player (Deck 0, Paul 11 Nov 2026; mock-up
/// https://claude.ai/artifact/7Pz2BXFcpRBv9JMsz2m1TA). Looking at the top:
/// the artwork filling the top half with the title under it. TRANSCRIPT or
/// CHAPTERS shrinks the artwork beside the title and fills the top half
/// instead (they swap with each other; tap the lit one again for the
/// artwork), like Apple Podcasts. Doing at the bottom, in thumb reach: the
/// green display (time, when it ends, what's left; drag along its progress
/// from the play point to scrub), skip / play / skip, the Speed / Trim /
/// Boost / Sleep strip, and TRANSCRIPT / CHAPTERS / where it's playing. No
/// close key: swipe down. Up Next is on the Listen tab. The episode notes
/// are further down the page.
struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss
    /// While dragging along the progress, where it would play from.
    @State private var scrubTime: TimeInterval?
    /// Where it was when the drag began (it moves by how far the finger
    /// travels, so a touch never makes it jump).
    @State private var scrubStart: TimeInterval?
    /// The finger's last position along the line while scrubbing.
    @State private var scrubLastX: CGFloat?
    /// "HALF-SPEED SCRUBBING" etc. while the finger is below the line.
    @State private var scrubSpeed: String?
    /// A drag that began away from the play point: ignored until it ends.
    @State private var scrubRefused = false
    @State private var showingNotes = false
    @State private var searchingTranscript = false
    /// Set while the player is closing itself (pull down past the top).
    @State private var closing = false
    @AppStorage("playerTopMode") private var topModeRaw = TopMode.artwork.rawValue
    @Namespace private var artSpace

    /// What fills the top half.
    enum TopMode: String { case artwork, transcript, chapters }
    private var topMode: TopMode { TopMode(rawValue: topModeRaw) ?? .artwork }

    /// Looked up once per episode, not on every redraw: the player redraws
    /// twice a second while playing (review, 9 Nov 2026).
    @State private var currentEpisode: PodcastEpisode?

    var body: some View {
        Group {
            if let item = player.nowPlaying {
                GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        screen(item, top: geometry.safeAreaInsets.top,
                               height: geometry.size.height + geometry.safeAreaInsets.top)
                        if let episode = currentEpisode {
                            EpisodeNotesText(episode: episode)
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                                .padding(.bottom, 30)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // Floats over the page instead of taking room at the bottom
                // (as a safe-area inset it resized the page and flickered).
                .overlay(alignment: .bottom) {
                    UndoBar()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .animation(.easeOut(duration: 0.2), value: store.undoAction?.id)
                }
                // Pull down past the top to close the player (no close key).
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                    if offset < -90, !closing {
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
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .onChange(of: player.nowPlaying?.episodeID, initial: true) { _, id in
            currentEpisode = id.flatMap { store.episode($0) }
        }
        .onChange(of: player.chapters.isEmpty) { _, empty in
            if empty, topMode == .chapters { topModeRaw = TopMode.artwork.rawValue }
        }
        .sheet(isPresented: $showingNotes) {
            if let episode = currentEpisode { EpisodeNotesView(episode: episode) }
        }
        .transcribeExplainer()
    }

    // MARK: The first screenful

    /// `top` is the status bar's height (the player runs to the top edge),
    /// `height` the whole screen's.
    private func screen(_ item: PlayerModel.NowPlaying, top: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            topKeys
            topArea(item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            adBar
                .padding(.top, 8)
            VStack(spacing: 11) {
                timeDisplay
                DeckTransport(height: 46)
                toolsStrip
                modeButtons
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, top + 4)
        .padding(.bottom, 12)
        .frame(height: max(height, 680))
        .frame(maxWidth: .infinity)
    }

    /// A handle (pull down to close), then find (transcript), download and
    /// mark played, small and quiet on the right.
    private var topKeys: some View {
        HStack(spacing: 6) {
            Spacer()
            if topMode == .transcript {
                quietKey("magnifyingglass", label: "Find in transcript") { searchingTranscript.toggle() }
            }
            if let episode = currentEpisode { downloadKey(episode) }
            quietKey("checkmark", label: "Mark as played") { markPlayed() }
        }
        .frame(height: 36)
        .overlay {
            Capsule().fill(Theme.controlBorder).frame(width: 38, height: 5)
                .accessibilityHidden(true)
        }
    }

    private func quietKey(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Artwork with the title under it, or (transcript / chapters) a small
    /// artwork beside the title with the panel filling the rest.
    private func topArea(_ item: PlayerModel.NowPlaying) -> some View {
        GeometryReader { geometry in
            let side: CGFloat = max(120, min(geometry.size.width - 24, geometry.size.height - 96))
            VStack(spacing: 0) {
                if topMode == .artwork {
                    Spacer(minLength: 4)
                    artwork(item, size: side)
                    titleBlock(item, centred: true)
                        .padding(.top, 14)
                    Spacer(minLength: 4)
                } else {
                    HStack(spacing: 12) {
                        Button { setMode(.artwork) } label: { artwork(item, size: 52) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show artwork")
                        titleBlock(item, centred: false)
                    }
                    .padding(.top, 6)
                    Group {
                        if topMode == .transcript, let episode = currentEpisode {
                            PlayerTranscriptPanel(episode: episode, searching: $searchingTranscript, light: true)
                        } else {
                            PlayerChaptersPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 10)
                    .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func artwork(_ item: PlayerModel.NowPlaying, size: CGFloat) -> some View {
        ArtworkView(url: item.artworkURL, title: item.showTitle, size: size, radius: max(6, size * 0.05))
            .shadow(color: .black.opacity(size > 100 ? 0.22 : 0.15), radius: size > 100 ? 14 : 4, y: size > 100 ? 8 : 2)
            .matchedGeometryEffect(id: "artwork", in: artSpace)
    }

    /// The title (opens the notes), the show and chapter (the show opens its
    /// page), and the DL / TX letters.
    private func titleBlock(_ item: PlayerModel.NowPlaying, centred: Bool) -> some View {
        VStack(alignment: centred ? .center : .leading, spacing: 4) {
            Button { showingNotes = true } label: {
                Text(item.title)
                    .font(Theme.title(centred ? 22 : 18))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Opens the episode notes")
            HStack(spacing: 8) {
                Button {
                    if let show = currentEpisode?.podcast { store.revealShow = show }
                } label: {
                    Text(showLine(item).uppercased())
                        .font(Theme.mono(9.5))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the show")
                if let episode = currentEpisode { EpisodeLights(episode: episode) }
            }
        }
        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }

    /// "Wastelanders · Ch 2 The bunker".
    private func showLine(_ item: PlayerModel.NowPlaying) -> String {
        var parts = [item.showTitle]
        if let index = player.currentChapterIndex, player.chapters.indices.contains(index) {
            parts.append("Ch \(index + 1) \(player.chapters[index].title)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func setMode(_ mode: TopMode) {
        let next: TopMode = (mode == topMode || mode == .artwork) ? .artwork : mode
        if next != .transcript { searchingTranscript = false }
        withAnimation(.spring(duration: 0.45, bounce: 0.12)) { topModeRaw = next.rawValue }
    }

    // MARK: The deck

    /// The time, when it ends and what's left, over the progress (drag from
    /// the play point to scrub).
    private var timeDisplay: some View {
        let shown = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let ends: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        return LCDPanel(vertical: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TimeFormat.clock(shown))
                    .font(Theme.mono(24, .medium))
                    .foregroundStyle(Deck0.lcdBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text((scrubSpeed ?? "Ends " + UpNextTimes.clock(ends)).uppercased())
                    .foregroundStyle(Deck0.lcdDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text("−" + TimeFormat.clock(left))
                    .font(Theme.mono(13, .medium))
                    .lineLimit(1)
            }
            .monospacedDigit()
            .accessibilityElement(children: .combine)
            scrubRow
        }
    }

    /// The display's progress blocks with a bright mark at the play point.
    /// Drag from the mark: it moves by how far the finger travels; sliding
    /// the finger down while dragging slows it (half, quarter, fine).
    private var scrubRow: some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        let active = scrubTime != nil
        let left: TimeInterval = max(0, player.duration - shown)
        return GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let x: CGFloat = CGFloat(shown / duration) * width
            LCDProgress(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions)
                .frame(height: active ? 9 : 5)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Deck0.lcdBright)
                        .frame(width: 3, height: active ? 22 : 14)
                        .offset(x: x - 1.5)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if active { scrubBubble(at: shown, x: x, width: width) }
                }
                .animation(.easeOut(duration: 0.15), value: active)
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: width, duration: duration))
        }
        .frame(height: 24)
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
                if scrubRefused { return }
                guard let lastX = scrubLastX, let current = scrubTime else {
                    // Only from where it's playing now (Paul, after build
                    // 139): a touch elsewhere on the line does nothing.
                    let playheadX = CGFloat(player.currentTime / duration) * width
                    if abs(value.startLocation.x - playheadX) > 30 {
                        scrubRefused = true
                        return
                    }
                    scrubStart = player.currentTime
                    scrubTime = player.currentTime
                    scrubLastX = value.location.x
                    scrubSpeed = PlayerOptions.scrubSpeed(below: 0).label
                    return
                }
                let below: Double = Double(value.location.y - 12)
                let speed = PlayerOptions.scrubSpeed(below: below)
                scrubSpeed = speed.label
                let moved: Double = Double((value.location.x - lastX) / width) * duration * speed.factor
                scrubTime = min(duration, max(0, current + moved))
                scrubLastX = value.location.x
            }
            .onEnded { _ in
                scrubRefused = false
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

    /// Where each chapter starts, as fractions of the episode.
    private var chapterStarts: [Double] {
        guard player.duration > 0 else { return [] }
        return player.chapters.map { min(1, max(0, $0.start / player.duration)) }
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }

    /// Speed, Trim, Boost and Sleep as one quiet strip, each with its value
    /// and a light (Paul: keep the keys, but not like a calculator).
    private var toolsStrip: some View {
        ToolsStrip {
            Menu {
                Picker(player.speedIsForShow ? "Speed for this show" : "Speed", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(PlayerOptions.speeds, id: \.self) { speed in
                        Text(PlayerOptions.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                ToolCell(value: PlayerOptions.speedLabel(player.speed), label: player.speedIsForShow ? "SHOW" : "SPEED", on: player.speed != 1)
            }
            .accessibilityLabel("Speed, \(PlayerOptions.speedLabel(player.speed))")

            Button { player.setTrimSilences(!player.trimSilences) } label: {
                ToolCell(value: player.trimSilences ? "ON" : "OFF", label: "TRIM", on: player.trimSilences)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trim silences: speeds through pauses")
            .accessibilityAddTraits(player.trimSilences ? .isSelected : [])

            Button { player.setBoostVoices(!player.boostVoices) } label: {
                ToolCell(value: player.boostVoices ? "ON" : "OFF", label: "BOOST", on: player.boostVoices)
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
                ToolCell(value: sleepValue, label: "SLEEP", on: player.sleepTimer != nil)
            }
            .accessibilityLabel(player.sleepTimer == nil ? "Sleep timer" : "Sleep timer on, \(sleepValue)")
        }
    }

    /// "OFF", "END" or the minutes left ("20M").
    private var sleepValue: String {
        if let ends = player.sleepEndsAt {
            return "\(max(1, Int((ends.timeIntervalSinceNow / 60).rounded(.up))))M"
        }
        return player.sleepTimer == .endOfEpisode ? "END" : (player.sleepTimer == nil ? "OFF" : "ON")
    }

    /// TRANSCRIPT, CHAPTERS and where it's playing (Paul, 11 Nov 2026).
    private var modeButtons: some View {
        HStack(spacing: 8) {
            modeButton("TRANSCRIPT", icon: "text.quote", lit: topMode == .transcript) { setMode(.transcript) }
                .accessibilityLabel(topMode == .transcript ? "Show artwork" : "Show transcript")
            modeButton("CHAPTERS", icon: "list.bullet", lit: topMode == .chapters) { setMode(.chapters) }
                .disabled(player.chapters.isEmpty)
                .accessibilityLabel(topMode == .chapters ? "Show artwork" : "Show chapters")
            deviceButton
        }
    }

    private func modeButton(_ title: String, icon: String, lit: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(Theme.mono(8.5, .bold)).tracking(0.8).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(lit ? Poster.paper : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(lit ? Theme.playingCard : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(DimWhenDisabled())
    }

    /// Where the sound is going; tap for the system device picker.
    private var deviceButton: some View {
        VStack(spacing: 4) {
            Image(systemName: "airplayaudio").font(.system(size: 16, weight: .semibold))
            Text((player.outputName ?? "iPhone").uppercased())
                .font(Theme.mono(8.5, .bold)).tracking(0.8).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, minHeight: 50)
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
                    Circle().stroke(Theme.hairline, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.04, fraction))
                        .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 8, weight: .bold))
                } else {
                    Image(systemName: local ? "arrow.down.circle.fill" : "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .frame(width: 22, height: 22)
            .frame(width: 34, height: 34)
            .background(Theme.surface, in: Circle())
            .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(local)
        .accessibilityLabel(local ? "Downloaded" : fraction.map { "Stop download, \(Int($0 * 100)) percent done" } ?? "Download")
    }

    /// The top keys' fill on printed colour areas (the poster look's one-ink
    /// artwork is calm enough for a see-through dark fill).
    static var keyFill: Color { Color.black.opacity(0.3) }

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

    /// The chapter and time above the finger while scrubbing: a paper card
    /// with a shadow, so it reads clearly over the artwork area above.
    private func scrubBubble(at time: TimeInterval, x: CGFloat, width: CGFloat) -> some View {
        let chapters = player.chapters
        let title: String? = Chapters.index(at: time, in: chapters).map { chapters[$0].title }
        let bubbleWidth: CGFloat = 190
        let centre: CGFloat = min(width - bubbleWidth / 2, max(bubbleWidth / 2, x))
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

}

/// The player's CHAPTERS view (fills the top half): every chapter, the one
/// playing in the dark "playing" card, earlier ones faded; tap to jump.
/// "From the show / auto" opens the full chapters list with its switch.
private struct PlayerChaptersPanel: View {
    @Environment(PlayerModel.self) private var player
    @State private var showingAll = false

    var body: some View {
        let current = player.currentChapterIndex
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(player.chapters.enumerated()), id: \.offset) { index, chapter in
                        Button { player.play(chapter: chapter) } label: {
                            row(index: index, title: chapter.title, start: chapter.start, current: current)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                    Button { showingAll = true } label: {
                        Text("ALL CHAPTERS · FROM THE SHOW / AUTO ›")
                            .font(Theme.mono(9, .bold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onChange(of: current, initial: true) { _, index in
                guard let index else { return }
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .sheet(isPresented: $showingAll) {
            ChaptersView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func row(index: Int, title: String, start: TimeInterval, current: Int?) -> some View {
        let isNow = index == current
        let done = current.map { index < $0 } ?? false
        return HStack(spacing: 10) {
            Text(isNow ? "▶" : "\(index + 1)")
                .font(Theme.mono(10, .bold))
                .foregroundStyle(isNow ? Deck0.led : Theme.muted)
                .frame(width: 18, alignment: .leading)
            Text(title)
                .font(Theme.text(15, isNow ? .semibold : .regular))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(TimeFormat.clock(start))
                .font(Theme.mono(10))
                .monospacedDigit()
                .opacity(0.75)
        }
        .foregroundStyle(isNow ? Poster.paper : (done ? Theme.muted : Theme.ink))
        .padding(.horizontal, 10)
        .frame(minHeight: 38)
        .background(isNow ? Theme.playingCard : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityLabel("Chapter \(index + 1), \(title)\(isNow ? ", playing" : "")")
    }
}

/// The progress line's drawing (see `scrubBar`): split by small gaps at
/// chapters, played part in the artwork's colour, ad breaks amber. `grow`
/// (0 at rest, 1 while scrubbing) animates it thicker and a little wider.
private struct ScrubLine: View, Animatable {
    let progress: Double
    let chapterStarts: [Double]
    let ads: [ClosedRange<Double>]
    let tint: Color
    var track: Color = Theme.hairline
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
            Self.draw(in: graphics, size: size, progress: progress, chapterStarts: chapterStarts, ads: ads, tint: tint, track: track, grow: CGFloat(grow))
        }
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private static func draw(in graphics: GraphicsContext, size: CGSize, progress: Double, chapterStarts: [Double], ads: [ClosedRange<Double>], tint: Color, track: Color, grow: CGFloat) {
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
            segment.fill(shape, with: .color(track))
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

/// Behind the player's poster: the artwork printed in one ink of its
/// colour across the top, fading into the colour, with the dot screen over
/// the whole poster. Its own view with plain inputs, so the player's
/// twice-a-second clock doesn't redraw it.
private struct PosterBackdrop: View, Equatable {
    let url: URL?
    let tint: Color
    let strength: Double

    var body: some View {
        ZStack(alignment: .top) {
            tint
            GeometryReader { geometry in
                PrintedArtwork(url: url, colour: tint, strength: strength, dots: false)
                    .frame(width: geometry.size.width, height: geometry.size.width * 1.1)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                                 .init(color: .black, location: 0.55),
                                                 .init(color: .black.opacity(0), location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
            Halftone()
        }
        .accessibilityHidden(true)
    }
}

/// Plain button that fades when it can't be used.
private struct DimWhenDisabled: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}
