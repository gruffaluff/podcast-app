import SwiftUI
import UIKit
import PodcastCore

/// Haar, phase 2 (Paul, 13 Nov 2026): the player is home, the first
/// screen, on the fog. Big artwork with the title under it; tap the
/// artwork (or Read along) and it shrinks into the corner while the
/// transcript fills the space, the line now in the serif with each word
/// lit as it's said. Under it: the chapter "4/6 · title" with ‹ ›, a
/// waveform-style progress line (chapter dots, ads faded), the times,
/// skip / play / skip, the volume, Options · Read along · Chapters, and
/// what's up next as a small stack of cards (tap for Up next). AirPlay at
/// the top left, ⋯ (episode options) at the top right. Mock-ups:
/// https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7.
struct HaarNowView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads

    /// Opens the Up next layer (the card stack, or swipe up).
    var openUpNext: () -> Void
    /// Opens Find (when there's nothing to play).
    var openFind: () -> Void
    /// Room left at the bottom for the floating dock.
    var bottomRoom: CGFloat = 76

    /// Read-along on (the artwork shrinks into the corner). Kept between
    /// launches, like the old player's transcript mode.
    @AppStorage("haarReading") private var reading = false
    @State private var episode: PodcastEpisode?
    @State private var showingOptions = false
    @State private var showingChapters = false
    @State private var showingNotes = false
    /// The card that floats in when a new chapter starts.
    @State private var flash: ChapterFlash?
    @Namespace private var art

    struct ChapterFlash: Equatable {
        let number: Int
        let count: Int
        let title: String
    }

    var body: some View {
        GeometryReader { geometry in
            let height: CGFloat = geometry.size.height
            VStack(spacing: 0) {
                topBar
                if let item = player.nowPlaying {
                    playing(item, height: height, width: geometry.size.width)
                } else {
                    idle
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, bottomRoom)
            .frame(width: geometry.size.width, height: height)
        }
        .overlay(alignment: .top) {
            if let flash {
                chapterCard(flash)
                    .padding(.top, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: player.nowPlaying?.episodeID, initial: true) { _, id in
            episode = id.flatMap { store.episode($0) }
        }
        .onChange(of: player.currentChapterIndex) { old, new in
            showFlash(from: old, to: new)
        }
        .sheet(isPresented: $showingOptions) { PlayerOptionsSheet() }
        .sheet(isPresented: $showingChapters) {
            ChaptersView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotes) {
            if let episode { EpisodeNotesView(episode: episode) }
        }
    }

    // MARK: Top

    /// AirPlay on the left, where it's playing in the middle (only when
    /// not on the iPhone), ⋯ on the right.
    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplayaudio")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .allowsHitTesting(false)
                .background(RoutePicker(tint: .clear))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Playing on \(player.outputName ?? "iPhone"). Choose another device")
                .accessibilityAddTraits(.isButton)
            Spacer(minLength: 4)
            if let output = player.outputName {
                Text("Playing on \(output)")
                    .font(Theme.text(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            optionsMenu
        }
        .frame(height: 44)
    }

    /// Episode options: notes, the show, download, transcript, share,
    /// mark played.
    @ViewBuilder private var optionsMenu: some View {
        if let episode {
            Menu {
                Button("Episode notes", systemImage: "doc.text") { showingNotes = true }
                if let show = episode.podcast {
                    Button("Go to \(show.title)", systemImage: "square.stack") { store.revealShow = show }
                }
                downloadItem(episode)
                transcriptItem(episode)
                if let link = episode.webLink {
                    ShareLink(item: link) { Label("Share link", systemImage: "square.and.arrow.up") }
                }
                Button("Mark as played", systemImage: "checkmark.circle") { markPlayed() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Episode options")
        } else {
            Color.clear.frame(width: 40, height: 40)
        }
    }

    @ViewBuilder private func downloadItem(_ episode: PodcastEpisode) -> some View {
        let local: Bool = store.localAudioURL(for: episode) != nil
        if let fraction = downloads.progress[episode.episodeID] {
            Button("Stop download (\(Int(fraction * 100))%)", systemImage: "stop.circle") { store.removeDownload(episode) }
        } else if local {
            Button("Remove download", systemImage: "trash", role: .destructive) { store.removeDownload(episode) }
        } else {
            Button("Download", systemImage: "arrow.down.circle") { downloads.download(episode) }
        }
    }

    @ViewBuilder private func transcriptItem(_ episode: PodcastEpisode) -> some View {
        if transcripts.isQueued(episode) {
            Button("Stop transcribing", systemImage: "stop.circle") { transcripts.stop(episode) }
        } else if episode.transcriptState == .ready || !transcripts.canTranscribeNow(episode) {
            Button("Read along", systemImage: "text.quote") { setReading(true) }
        } else {
            Button("Transcribe now", systemImage: "text.bubble") { transcripts.transcribeNow(episode) }
        }
    }

    private func markPlayed() {
        guard let episode else { return }
        store.undoable("Marked played", episodes: [episode]) { player.finishEarly() }
    }

    private func setReading(_ on: Bool) {
        withAnimation(.spring(duration: 0.5, bounce: 0.12)) { reading = on }
    }

    // MARK: Playing

    private func playing(_ item: PlayerModel.NowPlaying, height: CGFloat, width: CGFloat) -> some View {
        // The artwork takes what the controls leave (a little smaller on
        // small iPhones), never wider than the page.
        let side: CGFloat = max(150, min(width - 64, height - 470 - bottomRoom))
        let roomy: Bool = height > 760
        return VStack(spacing: 0) {
            if reading {
                HStack(spacing: 12) {
                    Button { setReading(false) } label: { artwork(item, size: 56) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show artwork")
                    titleBlock(item, size: 21, lines: 2)
                }
                .padding(.top, 4)
                if let episode {
                    HaarReadAlong(episode: episode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    Spacer()
                }
            } else {
                Spacer(minLength: 6)
                Button { setReading(true) } label: { artwork(item, size: side) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Artwork")
                    .accessibilityHint("Shows the words as they're said")
                Spacer(minLength: 10)
                titleBlock(item, size: 28, lines: 2)
            }
            chapterPill
                .padding(.top, 8)
            adBar
                .padding(.top, 4)
            HaarWave(episodeID: item.episodeID)
                .padding(.top, 6)
            transport
                .padding(.top, 2)
            if roomy {
                volumeRow
            }
            controlsRow
                .padding(.top, roomy ? 0 : 4)
            HaarUpNextStack(open: openUpNext, openFind: openFind)
                .padding(.top, 10)
        }
    }

    private func artwork(_ item: PlayerModel.NowPlaying, size: CGFloat) -> some View {
        ArtworkView(url: item.artworkURL, title: item.showTitle, size: size, radius: max(8, size * 0.07))
            .shadow(color: Color(hex: 0x28323C).opacity(size > 100 ? 0.22 : 0.12), radius: size > 100 ? 24 : 6, y: size > 100 ? 12 : 3)
            .matchedGeometryEffect(id: "artwork", in: art)
    }

    /// The title in the serif (tap for the notes), the show and date under
    /// it (tap the show for its page), and the DL / TX letters.
    private func titleBlock(_ item: PlayerModel.NowPlaying, size: CGFloat, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { showingNotes = true } label: {
                Text(item.title)
                    .font(Theme.serif(size))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(lines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Opens the episode notes")
            HStack(spacing: 8) {
                Button {
                    if let show = episode?.podcast { store.revealShow = show }
                } label: {
                    Text(showLine(item))
                        .font(Theme.text(13, .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the show")
                if let episode { EpisodeLights(episode: episode) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showLine(_ item: PlayerModel.NowPlaying) -> String {
        var parts: [String] = [item.showTitle]
        if let published = episode?.published, published > .distantPast {
            parts.append(published.formatted(.dateTime.day().month(.abbreviated)))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "‹  4/6 · The bunker  ›": tap the words for the chapter list.
    @ViewBuilder private var chapterPill: some View {
        let chapters = player.chapters
        if !chapters.isEmpty {
            let index: Int = player.currentChapterIndex ?? 0
            HStack(spacing: 4) {
                Button { player.previousChapter() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous chapter")
                Button { showingChapters = true } label: {
                    Text("\(index + 1)/\(chapters.count) · \(chapters[min(index, chapters.count - 1)].title)")
                        .font(Theme.text(13, .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chapter \(index + 1) of \(chapters.count), \(chapters[min(index, chapters.count - 1)].title)")
                .accessibilityHint("Shows every chapter")
                Button { player.nextChapter() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index >= chapters.count - 1)
                .accessibilityLabel("Next chapter")
            }
            .foregroundStyle(Theme.ink)
        }
    }

    /// Skip back, play / pause, skip forward: plain symbols on the fog.
    private var transport: some View {
        HStack {
            Spacer()
            SkipButton(direction: .back, iconSize: 28, frame: 58)
            Spacer()
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .frame(width: 76, height: 66)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Spacer()
            SkipButton(direction: .forward, iconSize: 28, frame: 58)
            Spacer()
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
    }

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            SystemVolumeSlider()
                .frame(height: 30)
                .tint(Theme.ink)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
    }

    /// Options (speed, trim, boost, sleep) · Read along · Chapters, as
    /// plain words; lit ones in ink, the rest muted.
    private var controlsRow: some View {
        HStack(spacing: 0) {
            Button { showingOptions = true } label: {
                textKey(optionsSummary, icon: "slider.horizontal.3", lit: optionsOn)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options: speed, trim, boost, sleep")
            .accessibilityValue(optionsSummary)
            Button { setReading(!reading) } label: {
                textKey(reading ? "Artwork" : "Read along", icon: reading ? "photo" : "text.quote", lit: reading)
            }
            .buttonStyle(.plain)
            Button { showingChapters = true } label: {
                textKey("Chapters", icon: "list.bullet", lit: false)
            }
            .buttonStyle(.plain)
            .disabled(player.chapters.isEmpty)
            .opacity(player.chapters.isEmpty ? 0.4 : 1)
        }
    }

    private func textKey(_ title: String, icon: String, lit: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium))
            Text(title).font(Theme.text(13, lit ? .semibold : .medium)).lineLimit(1)
        }
        .foregroundStyle(lit ? Theme.ink : Theme.muted)
        .frame(maxWidth: .infinity, minHeight: 40)
        .contentShape(Rectangle())
    }

    private var optionsOn: Bool {
        player.speed != 1 || player.trimSilences || player.boostVoices || player.sleepTimer != nil
    }

    /// "1.2× · Trim · Sleep" or just "Options".
    private var optionsSummary: String {
        var parts: [String] = []
        if player.speed != 1 { parts.append(PlayerOptions.speedLabel(player.speed)) }
        if player.trimSilences { parts.append("Trim") }
        if player.boostVoices { parts.append("Boost") }
        if player.sleepTimer != nil { parts.append("Sleep") }
        return parts.isEmpty ? "Options" : parts.joined(separator: " · ")
    }

    /// While an ad plays: Skip ad and Not an ad. Just after a skip: Play ad
    /// / Not an ad. Plain words on a frosted strip.
    @ViewBuilder private var adBar: some View {
        if let adBreak = player.currentAd {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ad break").font(Theme.text(13, .semibold))
                    Text("Show resumes at \(TimeFormat.clock(adBreak.end))").font(Theme.text(12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 4)
                Button("Not an ad") { player.notAnAd(adBreak, transcripts: transcripts) }
                    .font(Theme.text(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .frame(minHeight: 40)
                Button("Skip ad") { player.skipCurrentAd() }
                    .font(Theme.text(14, .semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 40)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frostedCard(radius: 16)
        } else if let adBreak = player.lastSkippedAd {
            HStack(spacing: 12) {
                Text("Ad skipped at \(TimeFormat.clock(adBreak.start))").font(Theme.text(13, .medium))
                Spacer(minLength: 4)
                Button("Play ad") { player.playAd(adBreak) }
                    .font(Theme.text(13, .semibold)).buttonStyle(.plain).frame(minHeight: 36)
                Button("Not an ad") { player.notAnAd(adBreak, transcripts: transcripts) }
                    .font(Theme.text(13, .medium)).buttonStyle(.plain).frame(minHeight: 36)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frostedCard(radius: 16)
        }
    }

    // MARK: Chapter card

    private func showFlash(from old: Int?, to new: Int?) {
        // Only when playing moves on into a new chapter, not on opening.
        guard player.isPlaying, let old, let new, new != old else { return }
        let chapters = player.chapters
        guard chapters.indices.contains(new) else { return }
        let card = ChapterFlash(number: new + 1, count: chapters.count, title: chapters[new].title)
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) { flash = card }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            if flash == card {
                withAnimation(.easeOut(duration: 0.4)) { flash = nil }
            }
        }
    }

    private func chapterCard(_ card: ChapterFlash) -> some View {
        VStack(spacing: 3) {
            Text("Chapter \(card.number) of \(card.count)")
                .font(Theme.text(11, .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text(card.title)
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frostedCard(radius: 20)
        .padding(.horizontal, 40)
        .onTapGesture { showingChapters = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Nothing playing

    /// Nothing playing: the top of Up Next ready to play, or a way to find
    /// something.
    @ViewBuilder private var idle: some View {
        let upcoming: PodcastEpisode? = store.queue.first.flatMap { store.episode($0.episode.id) }
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            if let upcoming {
                Button { player.play(upcoming) } label: {
                    ArtworkView(url: upcoming.artwork, title: upcoming.showTitle, size: 220, radius: 16)
                        .shadow(color: Color(hex: 0x28323C).opacity(0.2), radius: 22, y: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play \(upcoming.title)")
                Text(upcoming.position > 5 ? "Carry on" : "Up next")
                    .font(Theme.text(12, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 22)
                Text(upcoming.title)
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.top, 4)
                Text([upcoming.showTitle, upcoming.timeLeft.map { TimeFormat.length($0) } ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.text(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                Button { player.play(upcoming) } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(Theme.text(17, .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: 120, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            } else {
                Text("Nothing playing")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                Text("Up next is empty. Find a show, or pick an episode in your Library.")
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                Button(action: openFind) {
                    Label("Find something", systemImage: "magnifyingglass")
                        .font(Theme.text(16, .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            Spacer(minLength: 10)
            if upcoming != nil {
                HaarUpNextStack(open: openUpNext, openFind: openFind, skipFirst: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Waveform progress

/// The progress line as a waveform (the shape is made up from the
/// episode, the same every time; it isn't the real sound), played part in
/// ink, the rest faded, ad breaks fainter still, chapter dots under it.
/// Drag anywhere along it: it moves by how far the finger travels (a touch
/// never jumps), finger lower down for finer, a bubble shows the chapter
/// and time, and a jump of 2 minutes or more offers Undo.
struct HaarWave: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let episodeID: String

    @State private var scrubTime: TimeInterval?
    @State private var scrubStart: TimeInterval?
    @State private var lastX: CGFloat?
    @State private var speedLabel: String?

    static let bars = 64
    static let height: CGFloat = 42

    var body: some View {
        let duration: TimeInterval = max(player.duration, 1)
        let shown: TimeInterval = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        let ends: Date = Date().addingTimeInterval(left / max(player.speed, 0.5))
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width: CGFloat = max(1, geometry.size.width)
                ZStack(alignment: .topLeading) {
                    WaveShape(heights: Self.heights(for: episodeID), progress: shown / duration,
                              ads: adFractions, ink: Theme.ink, faded: Theme.ink.opacity(0.18))
                        .frame(width: width, height: Self.height)
                    dots(width: width)
                        .offset(y: Self.height + 3)
                    if scrubTime != nil {
                        bubble(at: shown, x: CGFloat(shown / duration) * width, width: width)
                    }
                }
                .contentShape(Rectangle())
                .gesture(scrub(width: width, duration: duration))
            }
            .frame(height: Self.height + 9)
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
            HStack {
                Text(TimeFormat.clock(shown))
                Spacer(minLength: 6)
                Text(speedLabel ?? "ends " + UpNextTimes.clock(ends))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text("−" + TimeFormat.clock(left))
            }
            .font(Theme.text(12, .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.muted)
        }
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.compactMap { ad in
            let start = ad.start / player.duration, end = ad.end / player.duration
            return start <= end ? start...end : nil
        }
    }

    /// Small dots under the wave where each chapter starts; filled once
    /// reached.
    private func dots(width: CGFloat) -> some View {
        let duration: TimeInterval = max(player.duration, 1)
        let now: TimeInterval = scrubTime ?? player.currentTime
        return ZStack(alignment: .leading) {
            ForEach(Array(player.chapters.enumerated()), id: \.offset) { _, chapter in
                let x: CGFloat = CGFloat(min(1, max(0, chapter.start / duration))) * width
                Circle()
                    .fill(chapter.start <= now ? Theme.ink : Theme.ink.opacity(0.25))
                    .frame(width: 4, height: 4)
                    .offset(x: max(0, min(width - 4, x - 2)))
            }
        }
        .frame(width: width, height: 4, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func scrub(width: CGFloat, duration: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard let last = lastX, let current = scrubTime else {
                    scrubStart = player.currentTime
                    scrubTime = player.currentTime
                    lastX = value.location.x
                    speedLabel = PlayerOptions.scrubSpeed(below: 0).label
                    return
                }
                let below: Double = Double(value.location.y - Self.height)
                let speed = PlayerOptions.scrubSpeed(below: below)
                speedLabel = speed.label
                let moved: Double = Double((value.location.x - last) / width) * duration * speed.factor
                scrubTime = min(duration, max(0, current + moved))
                lastX = value.location.x
            }
            .onEnded { _ in
                if let target = scrubTime, let start = scrubStart, abs(target - start) > 0.5 {
                    player.seek(to: target)
                    if abs(target - start) >= 120 {
                        let player = self.player
                        let store = self.store
                        store.undoAction = UndoAction(label: "Jumped to \(TimeFormat.clock(target))") {
                            player.seek(to: start)
                            store.undoAction = nil
                        }
                    }
                }
                scrubTime = nil
                scrubStart = nil
                lastX = nil
                speedLabel = nil
            }
    }

    private func bubble(at time: TimeInterval, x: CGFloat, width: CGFloat) -> some View {
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
                .font(Theme.text(14, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frostedCard(radius: 12)
        .fixedSize()
        .position(x: centre, y: -26)
        .allowsHitTesting(false)
    }

    /// Bar heights (0.18–1) made from the episode's ID: a calm, speech-like
    /// shape that's the same every time the episode is shown.
    static func heights(for id: String) -> [Double] {
        var seed: UInt64 = 1469598103934665603
        for byte in id.utf8 {
            seed = (seed ^ UInt64(byte)) &* 1099511628211
        }
        var values: [Double] = []
        values.reserveCapacity(bars)
        var smooth: Double = 0.5
        for index in 0..<bars {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let random: Double = Double((seed >> 33) % 1000) / 1000
            smooth = smooth * 0.55 + random * 0.45
            let swell: Double = 0.75 + 0.25 * sin(Double(index) / 5.3)
            values.append(max(0.18, min(1, smooth * swell * 1.25)))
        }
        return values
    }
}

/// Draws the bars: played in ink, the rest faded, ads fainter.
private struct WaveShape: View {
    let heights: [Double]
    let progress: Double
    let ads: [ClosedRange<Double>]
    let ink: Color
    let faded: Color

    var body: some View {
        Canvas { context, size in
            let count: Int = heights.count
            guard count > 0 else { return }
            let step: CGFloat = size.width / CGFloat(count)
            let barWidth: CGFloat = max(1.5, step * 0.55)
            for index in 0..<count {
                let middle: Double = (Double(index) + 0.5) / Double(count)
                let inAd: Bool = ads.contains { $0.contains(middle) }
                let barHeight: CGFloat = max(3, CGFloat(heights[index]) * size.height)
                let rect = CGRect(x: CGFloat(index) * step + (step - barWidth) / 2,
                                  y: (size.height - barHeight) / 2,
                                  width: barWidth, height: barHeight)
                let played: Bool = middle <= progress
                var colour: Color = played ? ink : faded
                if inAd { colour = played ? ink.opacity(0.35) : faded.opacity(0.45) }
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(colour))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Up next stack

/// What's up next, as the top card of a small stack (two card edges
/// behind it); tap for the whole of Up next.
struct HaarUpNextStack: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let open: () -> Void
    let openFind: () -> Void
    /// With nothing playing, the first in Up Next is already shown big.
    var skipFirst = false

    var body: some View {
        let waiting: [QueueItem] = store.queue.filter { $0.episode.id != player.nowPlaying?.episodeID }
        let shown: [QueueItem] = Array(waiting.dropFirst(skipFirst ? 1 : 0))
        let next: PodcastEpisode? = shown.first.flatMap { store.episode($0.episode.id) }
        Button(action: next == nil && waiting.isEmpty ? openFind : open) {
            ZStack(alignment: .top) {
                if shown.count > 2 {
                    edge.padding(.horizontal, 26).offset(y: 12)
                }
                if shown.count > 1 {
                    edge.padding(.horizontal, 13).offset(y: 6)
                }
                card(next: next, count: shown.count)
            }
            .padding(.bottom, shown.count > 2 ? 12 : (shown.count > 1 ? 6 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Up next")
    }

    private var edge: some View {
        Color.clear
            .frame(height: 56)
            .frostedCard(radius: 18)
            .opacity(0.7)
    }

    private func card(next: PodcastEpisode?, count: Int) -> some View {
        HStack(spacing: 12) {
            if let next {
                ArtworkView(url: next.artwork, title: next.showTitle, size: 40, radius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(count > 1 ? "Up next · \(count) waiting" : "Up next")
                        .font(Theme.text(11, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text(next.title)
                        .font(Theme.text(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up next is empty")
                        .font(Theme.text(14, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Find something to listen to")
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .frostedCard(radius: 18)
    }
}

// MARK: - Read along

/// The transcript as you listen: the line now in the serif with each word
/// lit as it's said (timed across the line; transcripts give a time per
/// line, not per word), the lines either side smaller and faded, chapter
/// breaks as a thin rule with the chapter's name. Tap a line to play from
/// it; touch and hold to share a clip or copy. Scrolling by hand stops it
/// following for a few seconds (or tap Back to now).
struct HaarReadAlong: View {
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode

    @State private var lines: [TranscriptLayout.Line] = []
    @State private var followPaused = false
    @State private var resume: Task<Void, Never>?
    @State private var clip: ClipRequest?
    /// The last reported play time and when it came: the player reports
    /// twice a second, so the words are lit in between from the clock.
    @State private var anchorTime: TimeInterval = 0
    @State private var anchorDate = Date()

    private var isPlayingThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    private var nowIndex: Int? {
        guard isPlayingThis else { return nil }
        let time: TimeInterval = player.currentTime + 0.2
        return lines.lastIndex { $0.start <= time }
    }

    var body: some View {
        Group {
            if lines.isEmpty {
                TranscriptStatusView(episode: episode, onDark: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .task(id: episode.transcriptStateRaw) { load() }
        .onChange(of: episode.syncAnchorsData) { load() }
        .onChange(of: player.currentTime, initial: true) { _, time in
            anchorTime = time
            anchorDate = Date()
        }
        .sheet(item: $clip) { request in
            ClipView(episode: episode, line: request.line, quote: request.quote)
                .normalColours()
        }
    }

    private func load() {
        if let transcript = transcripts.transcript(for: episode) {
            lines = TranscriptLayout.lines(from: TranscriptAlign.aligned(transcript, anchors: episode.syncAnchors).segments)
        } else {
            lines = []
        }
    }

    private var list: some View {
        let now: Int? = nowIndex
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        if let chapter = chapterStarting(at: index) {
                            chapterRule(chapter.number, chapter.title)
                        }
                        row(line, index: index, now: now)
                            .id(index)
                    }
                }
                .padding(.vertical, 40)
            }
            .scrollIndicators(.hidden)
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                       .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting {
                    resume?.cancel()
                    followPaused = true
                } else if phase == .idle, followPaused {
                    resume?.cancel()
                    resume = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(6))
                        guard !Task.isCancelled else { return }
                        followPaused = false
                    }
                }
            }
            .onChange(of: now) { _, index in
                guard let index, !followPaused else { return }
                withAnimation(.easeInOut(duration: 0.7)) { proxy.scrollTo(index, anchor: UnitPoint(x: 0.5, y: 0.32)) }
            }
            .onAppear {
                if let now { proxy.scrollTo(now, anchor: UnitPoint(x: 0.5, y: 0.32)) }
            }
            .overlay(alignment: .bottom) {
                if followPaused, now != nil {
                    Button {
                        followPaused = false
                        if let now {
                            withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(now, anchor: UnitPoint(x: 0.5, y: 0.32)) }
                        }
                    } label: {
                        Text("Back to now")
                            .font(Theme.text(13, .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 36)
                            .frostedCard(radius: 18)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    @ViewBuilder private func row(_ line: TranscriptLayout.Line, index: Int, now: Int?) -> some View {
        let isNow: Bool = index == now
        let heard: Bool = now.map { index < $0 } ?? false
        Group {
            if isNow {
                TimelineView(.animation(minimumInterval: 0.1, paused: !player.isPlaying)) { context in
                    Text(litText(line, at: context.date))
                        .font(Theme.serif(25))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(line.text)
                    .font(Theme.text(16))
                    .foregroundStyle(Theme.ink.opacity(heard ? 0.38 : 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isPlayingThis {
                player.seek(to: line.start)
            } else {
                player.play(episode)
                player.seek(to: line.start)
            }
        }
        .contextMenu {
            Button("Share a clip", systemImage: "scissors") { clip = ClipRequest(line: line, quote: line.text) }
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = line.text }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays from here")
    }

    /// The line now with the words said so far in ink, the rest faded.
    private func litText(_ line: TranscriptLayout.Line, at date: Date) -> AttributedString {
        let words: [Substring] = line.text.split(separator: " ")
        let span: TimeInterval = max(0.5, line.end - line.start)
        let since: TimeInterval = player.isPlaying ? min(0.7, max(0, date.timeIntervalSince(anchorDate))) * player.speed : 0
        let time: TimeInterval = anchorTime + since
        let done: Double = min(1, max(0, (time - line.start) / span))
        let litCount: Int = Int((done * Double(words.count)).rounded(.up))
        var text = AttributedString()
        for (index, word) in words.enumerated() {
            var piece = AttributedString(String(word) + (index == words.count - 1 ? "" : " "))
            piece.foregroundColor = index < litCount ? Theme.ink : Theme.ink.opacity(0.3)
            text += piece
        }
        return text
    }

    /// The chapter that starts at this line (the first line at or after
    /// its start), if any.
    private func chapterStarting(at index: Int) -> (number: Int, title: String)? {
        let chapters = player.chapters
        guard isPlayingThis, !chapters.isEmpty, lines.indices.contains(index) else { return nil }
        let start: TimeInterval = lines[index].start
        let previous: TimeInterval = index > 0 ? lines[index - 1].start : -1
        guard let found = chapters.firstIndex(where: { $0.start > previous && $0.start <= start }) else { return nil }
        return (found + 1, chapters[found].title)
    }

    private func chapterRule(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.ink.opacity(0.2)).frame(height: 1)
            Text("\(number) · \(title)")
                .font(Theme.serif(16).italic())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle().fill(Theme.ink.opacity(0.2)).frame(height: 1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
