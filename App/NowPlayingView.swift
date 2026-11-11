import AVKit
import SwiftUI
import PodcastCore

/// The full player in the poster look (Paul, 11 Nov 2026): the whole screen
/// is the episode's artwork printed in its colour. Looking at the top:
/// the show, the episode title in big capitals and the chapter now / next
/// (or the transcript as a lyric sheet). Doing at the bottom, within thumb
/// reach: the time, the progress line (drag to scrub), transport, SPEED /
/// TRIM / BOOST / SLEEP, and TRANSCRIPT / CHAPTERS / UP NEXT. The episode
/// notes are further down; pull down past the top to close.
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
    /// A drag that began away from the play point: ignored until it ends.
    @State private var scrubRefused = false
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
                        poster(item, tint: tint, top: geometry.safeAreaInsets.top,
                               height: geometry.size.height + geometry.safeAreaInsets.top)
                        if let episode = currentEpisode {
                            EpisodeNotesText(episode: episode)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)
                                .padding(.bottom, 30)
                                .id("notes")
                        }
                    }
                }
                .background(tint.ignoresSafeArea())
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

    // MARK: The poster

    /// The first screenful: `top` is the status bar's height (the player
    /// runs to the top edge), `height` the whole screen's.
    private func poster(_ item: PlayerModel.NowPlaying, tint: Color, top: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow(item)
            Group {
                if showsTranscript, let episode = currentEpisode {
                    PlayerTranscriptPanel(episode: episode, searching: $searchingTranscript)
                } else {
                    titleBlock(item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.top, 10)
            adBar
                .padding(.top, 10)
            controls(tint: tint)
                .padding(.top, 14)
        }
        .foregroundStyle(Poster.paper)
        .padding(.horizontal, 20)
        .padding(.top, top + 6)
        .padding(.bottom, 18)
        .frame(height: max(height, 660))
        .frame(maxWidth: .infinity)
        .background { PosterBackdrop(url: item.artworkURL, tint: tint, strength: showsTranscript ? 0.25 : 0.7) }
        .environment(\.heroTint, tint)
    }

    /// Close, where it's playing, then (transcript) find, download, notes,
    /// mark played, and the artwork stamp (opens the show).
    private func topRow(_ item: PlayerModel.NowPlaying) -> some View {
        HStack(spacing: 6) {
            roundButton("chevron.down", label: "Close player") { dismiss() }
            deviceButton
            Spacer(minLength: 4)
            if showsTranscript {
                roundButton("magnifyingglass", label: "Find in transcript") { searchingTranscript.toggle() }
            }
            if let episode = currentEpisode { downloadKey(episode) }
            if !showsTranscript {
                roundButton("doc.text", label: "Episode notes") { notesJump += 1 }
            }
            roundButton("checkmark", label: "Mark as played") { markPlayed() }
            Button {
                if let show = currentEpisode?.podcast { store.revealShow = show }
            } label: {
                Stamp(url: item.artworkURL, title: item.showTitle, size: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.showTitle)")
        }
    }

    /// The show (opens it), the episode title in big capitals (opens its
    /// notes), and the chapter now and next (opens the chapters).
    private func titleBlock(_ item: PlayerModel.NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Button {
                if let show = currentEpisode?.podcast { store.revealShow = show }
            } label: {
                Text(([item.showTitle] + [currentEpisode.map { Self.published($0.published) }].compactMap { $0 }).joined(separator: " · ").uppercased())
                    .font(Theme.mono(10, .bold))
                    .tracking(1)
                    .lineLimit(1)
                    .foregroundStyle(Poster.paper.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the show")
            Button { showingNotes = true } label: {
                Text(item.title)
                    .font(Theme.big(46))
                    .lineLimit(4)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Opens the episode notes")
            chapterBill
        }
    }

    /// "NOW · CH 2 · FAN CALLS ……… NEXT · THE QUIZ" between two rules,
    /// like the acts on a bill.
    @ViewBuilder private var chapterBill: some View {
        if let index = player.currentChapterIndex {
            let chapters = player.chapters
            Button { showingChapters = true } label: {
                VStack(spacing: 6) {
                    Rectangle().fill(Poster.paper.opacity(0.5)).frame(height: 1)
                    HStack(spacing: 8) {
                        Text("NOW · CH \(index + 1) · \(chapters[index].title.uppercased())")
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if index + 1 < chapters.count {
                            Text("NEXT · \(chapters[index + 1].title.uppercased())")
                                .lineLimit(1)
                                .foregroundStyle(Poster.paper.opacity(0.7))
                                .layoutPriority(-1)
                        }
                    }
                    .font(Theme.mono(10, .bold))
                    .tracking(0.8)
                    Rectangle().fill(Poster.paper.opacity(0.5)).frame(height: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chapter \(index + 1) of \(chapters.count), \(chapters[index].title)")
            .accessibilityHint("Shows all chapters")
        }
    }

    /// "9 Nov" or "9 Nov 2025".
    private static func published(_ date: Date) -> String {
        let thisYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return thisYear ? date.formatted(.dateTime.day().month(.abbreviated))
            : date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// Everything you tap, in the bottom half.
    private func controls(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            timeRow
            scrubBar(tint: tint)
            transport(tint: tint)
            modeKeys(tint: tint)
            bottomRow
        }
    }

    /// The time in big figures, then what's left and when it ends (or the
    /// scrubbing speed while the finger is below the line).
    private var timeRow: some View {
        let shown = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let endsAt: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        let detail: String = scrubSpeed ?? "−\(TimeFormat.clock(left)) · ENDS \(endsAt.formatted(date: .omitted, time: .shortened))"
        return VStack(alignment: .leading, spacing: 0) {
            Text(TimeFormat.clock(shown))
                .font(Theme.big(72))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail.uppercased())
                .font(Theme.mono(11, .bold))
                .tracking(0.8)
                .monospacedDigit()
                .foregroundStyle(Poster.paper.opacity(0.85))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// TRANSCRIPT (or ARTWORK), CHAPTERS, FULL (transcript), UP NEXT · n.
    private var bottomRow: some View {
        let playingID = player.nowPlaying?.episodeID
        let upcoming = store.queue.filter { $0.episode.id != playingID }.count
        // Four fixed slots that never change their words or come and go
        // (Paul: the row jumped about as keys appeared and labels changed):
        // TRANSCRIPT lights up while it's showing, CHAPTERS and FULL dim
        // when they can't be used.
        return HStack(spacing: 6) {
            textKey("TRANSCRIPT", icon: "text.quote", lit: showsTranscript) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { showsTranscript.toggle() }
            }
            .accessibilityLabel(showsTranscript ? "Show artwork" : "Show transcript")
            textKey("CHAPTERS", icon: "list.bullet") { showingChapters = true }
                .disabled(player.chapters.isEmpty)
            textKey("FULL TEXT", icon: "arrow.up.left.and.arrow.down.right") { transcriptEpisode = currentEpisode }
                .disabled(!showsTranscript)
                .accessibilityLabel("Full transcript")
            textKey("UP NEXT \(upcoming)", icon: "arrow.up") { showingQueue = true }
                .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                    if value.translation.height < -30 { showingQueue = true }
                })
                .accessibilityLabel("Up Next, \(upcoming) episodes")
        }
    }

    /// A key in the bottom row: icon above a small label, the same width
    /// every time; lit (paper) when it's on.
    private func textKey(_ title: String, icon: String, lit: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(Theme.mono(9, .bold)).tracking(0.5).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(lit ? Color.black.opacity(0.85) : Poster.paper)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(lit ? Poster.paper : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(DimWhenDisabled())
    }

    /// Where the sound is going; tap for the system device picker.
    private var deviceButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplayaudio")
            Text((player.outputName ?? "iPhone").uppercased())
                .lineLimit(1)
        }
        .font(Theme.mono(11, .bold))
        .padding(.horizontal, 12)
        .frame(maxWidth: 130)
        .frame(height: 36)
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
            .frame(width: 36, height: 36)
            .background(Self.keyFill, in: Circle())
            .overlay(Circle().stroke(Theme.displayText.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(local)
        .accessibilityLabel(local ? "Downloaded" : fraction.map { "Stop download, \(Int($0 * 100)) percent done" } ?? "Download")
    }

    /// The top keys' fill on printed colour areas (the poster look's one-ink
    /// artwork is calm enough for a see-through dark fill).
    static var keyFill: Color { Color.black.opacity(0.3) }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 36, height: 36)
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
        return GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            // Paper on the printed colour: played solid, ahead see-through.
            ScrubLine(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions,
                      tint: Poster.paper, track: Poster.paper.opacity(0.28), grow: active ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: active)
                .frame(width: width + 2 * ScrubLine.stretch, height: ScrubLine.height)
                .offset(x: -ScrubLine.stretch)
                // A small round marker at the play point: where a drag
                // has to start.
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Poster.paper)
                        .frame(width: active ? 26 : 16, height: active ? 26 : 16)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .offset(x: ScrubLine.stretch + CGFloat(shown / duration) * width - (active ? 13 : 8))
                        .animation(.easeOut(duration: 0.15), value: active)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if active { scrubBubble(at: shown, x: shown / duration * width, width: width) }
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: width, duration: duration))
        }
        .frame(height: ScrubLine.height)
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
                    let playheadX = ScrubLine.stretch + CGFloat(player.currentTime / duration) * width
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
                let below: Double = Double(value.location.y - ScrubLine.height / 2)
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

    /// The chapter and time above the finger while scrubbing: a paper card
    /// with a shadow, so it reads clearly over the artwork area above.
    private func scrubBubble(at time: TimeInterval, x: CGFloat, width: CGFloat) -> some View {
        let chapters = player.chapters
        let title: String? = Chapters.index(at: time, in: chapters).map { chapters[$0].title }
        let bubbleWidth: CGFloat = 190
        let centre: CGFloat = min(width - bubbleWidth / 2, max(bubbleWidth / 2, x)) + ScrubLine.stretch
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
            SkipButton(direction: .back, iconSize: 34, frame: 56)
                .foregroundStyle(Poster.paper)
            Spacer()
            // Chapter keys in the gaps, when the episode has chapters (Paul).
            if hasChapters {
                chapterKey("backward.end.fill", label: "Previous chapter") { player.previousChapter() }
                Spacer()
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
                    .frame(width: 80, height: 80)
                    .background(Poster.paper, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Spacer()
            if hasChapters {
                chapterKey("forward.end.fill", label: "Next chapter") { player.nextChapter() }
                Spacer()
            }
            SkipButton(direction: .forward, iconSize: 34, frame: 56)
                .foregroundStyle(Poster.paper)
        }
        .tint(Poster.paper)
    }

    private var hasChapters: Bool { !player.chapters.isEmpty }

    private func chapterKey(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Poster.paper)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// SPEED / TRIM / BOOST / SLEEP keys: paper when on, see-through when off.
    private func modeKeys(tint: Color) -> some View {
        HStack(spacing: 6) {
            Menu {
                Picker(player.speedIsForShow ? "Speed for this show" : "Speed", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(PlayerOptions.speeds, id: \.self) { speed in
                        Text(PlayerOptions.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                tile(player.speedIsForShow ? "SHOW " + PlayerOptions.speedLabel(player.speed) : PlayerOptions.speedLabel(player.speed),
                     icon: "gauge.with.dots.needle.33percent", on: player.speed != 1, tint: tint)
            }
            .accessibilityLabel("Speed, \(PlayerOptions.speedLabel(player.speed))")

            Button { player.setTrimSilences(!player.trimSilences) } label: {
                tile("TRIM", icon: "scissors", on: player.trimSilences, tint: tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trim silences: speeds through pauses")
            .accessibilityAddTraits(player.trimSilences ? .isSelected : [])

            Button { player.setBoostVoices(!player.boostVoices) } label: {
                tile("BOOST", icon: "waveform", on: player.boostVoices, tint: tint)
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

    private func tile(_ title: String, icon: String, on: Bool, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(title).font(Theme.mono(11, .bold)).tracking(0.6).lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(on ? tint : Poster.paper)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(on ? Poster.paper : Self.keyFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Poster.paper.opacity(on ? 0 : 0.2), lineWidth: 1))
    }

    @ViewBuilder private func sleepTile(tint: Color) -> some View {
        if let ends = player.sleepEndsAt {
            let now = Date()
            HStack(spacing: 4) {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .bold))
                Text(timerInterval: now...max(ends, now), countsDown: true)
                    .font(Theme.mono(11, .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Poster.paper, in: RoundedRectangle(cornerRadius: 12))
        } else {
            tile(player.sleepTimer == .endOfEpisode ? "END" : "SLEEP", icon: "moon", on: player.sleepTimer != nil, tint: tint)
        }
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
