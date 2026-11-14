import SwiftUI
import UIKit
import MediaPlayer
import PodcastCore

/// Haar (Paul, 13 Nov 2026; reworked to the prototype the same night): the
/// player is home, on the fog. Top to bottom: AirPlay, a grab handle (swipe
/// down for Find) and ⋯; the artwork (280, rounded 46) with a Read along
/// pill; the show and the title in the serif; the plain progress line with
/// the times and the chapter control (‹ 3 Title ˅ ›) between them; speed,
/// skip, the big play, skip, sleep; a thin volume line; and what's up next
/// as a small stack of frosted cards.
/// Read along and Up next open in place: the artwork shrinks to the
/// corner (with the title beside it and ⌄ to go back) and the words, or
/// the Up next cards, fill the page.
/// Prototype: https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7.
struct HaarNowView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Up next open in place (HaarRoot keeps it, for its swipes).
    @Binding var showingUpNext: Bool
    /// Read along on (kept between launches by HaarRoot).
    @Binding var reading: Bool
    /// Opens Find (when there's nothing to play).
    var openFind: () -> Void
    /// Room left at the bottom for the floating dock.
    var bottomRoom: CGFloat = 76

    @State private var episode: PodcastEpisode?
    @State private var showingOptions = false
    @State private var showingChapters = false
    @State private var showingNotes = false
    @State private var confirmRemove = false
    /// The pill that shows when a new chapter starts.
    @State private var flash: ChapterFlash?
    @Namespace private var art

    /// The prototype's motion: a long, soft ease-out.
    // Shorter, smoother moves (Paul, 14 Nov 2026: animations "a bit
    // jerky"; the 0.7 s curve read as lag).
    static let morph: Animation = .smooth(duration: 0.4)
    static let rise: Animation = .smooth(duration: 0.35)

    struct ChapterFlash: Equatable {
        let number: Int
        let title: String
    }

    enum Mode { case listen, reading, upNext }

    private var mode: Mode {
        if showingUpNext { return .upNext }
        return reading && player.nowPlaying != nil ? .reading : .listen
    }

    var body: some View {
        GeometryReader { geometry in
            page(size: geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .overlay(alignment: .top) { toasts }
        .onChange(of: player.nowPlaying?.episodeID, initial: true) { _, id in
            episode = id.flatMap { store.episode($0) }
        }
        .onChange(of: player.currentChapterIndex) { old, new in
            showFlash(from: old, to: new)
        }
        .sheet(isPresented: $showingOptions) { PlayerOptionsSheet() }
        .sheet(isPresented: $showingChapters) {
            HaarChaptersSheet()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingNotes) {
            if let episode { EpisodeNotesView(episode: episode) }
        }
        .alert("Remove the download?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let episode { store.removeDownload(episode) }
            }
        } message: {
            Text("It will stream instead, or you can download it again.")
        }
    }

    @ViewBuilder private func page(size: CGSize) -> some View {
        switch mode {
        case .listen:
            if let item = player.nowPlaying {
                listen(item, size: size)
            } else {
                idle(size: size)
            }
        case .reading:
            if let item = player.nowPlaying {
                readAlong(item, size: size)
            }
        case .upNext:
            upNext(size: size)
        }
    }

    private func setReading(_ on: Bool) {
        withAnimation(reduceMotion ? nil : Self.morph) { reading = on }
    }

    private func closeUpNext() {
        withAnimation(reduceMotion ? nil : Self.morph) { showingUpNext = false }
    }

    private func openUpNext() {
        withAnimation(reduceMotion ? nil : Self.morph) { showingUpNext = true }
    }

    /// Whether the episode has words to read along to.
    private var hasWords: Bool { episode?.transcriptState == .ready }

    // MARK: Listen

    private func listen(_ item: PlayerModel.NowPlaying, size: CGSize) -> some View {
        let volume: Bool = Self.roomForVolume(size)
        let titleSize: CGFloat = item.title.count > 44 ? 25 : 33
        let side: CGFloat = artworkSide(size: size, title: item.title, titleSize: titleSize, volume: volume)
        return VStack(spacing: 0) {
            topBar
            Spacer(minLength: 4)
            bigArtwork(item, side: side)
            titleBlock(item, size: titleSize, compact: false)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            if let episode {
                episodeKeys(episode)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
            Spacer(minLength: 10)
            controls(item, volume: volume)
                .padding(.horizontal, 24)
            HaarUpNextStack(open: openUpNext, openFind: openFind)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .offset(y: 30)))
        }
        .padding(.bottom, bottomRoom)
    }

    /// The volume line only where there's room (not on an iPhone SE).
    static func roomForVolume(_ size: CGSize) -> Bool { size.height > 680 }

    /// The artwork takes what the rest leaves, 280 at most.
    private func artworkSide(size: CGSize, title: String, titleSize: CGFloat, volume: Bool) -> CGFloat {
        let textWidth: CGFloat = max(100, size.width - 48)
        let perLine: CGFloat = max(8, textWidth / (titleSize * 0.43))
        let lines: CGFloat = min(3, max(1, (CGFloat(title.count) / perLine).rounded(.up)))
        let titleHeight: CGFloat = 20 + lines * titleSize * 1.12
        let controlsHeight: CGFloat = HaarScrubLine.blockHeight + 10 + 70 + (volume ? 30 : 0)
        let fixed: CGFloat = 44 + 8 + 20 + titleHeight + Self.keysHeight + 6 + 12 + controlsHeight + 12 + HaarUpNextStack.height + bottomRoom
        let room: CGFloat = size.height - fixed
        return max(110, min(280, size.width - 48, room))
    }

    // MARK: Top

    /// AirPlay on the left, a grab handle in the middle (swipe down, or
    /// tap it, for Find), ⋯ on the right. They fade while a new chapter's
    /// name shows.
    private var topBar: some View {
        HStack(spacing: 0) {
            airPlay
            Spacer(minLength: 4)
            Button(action: openFind) {
                Capsule()
                    .fill(Theme.ink.opacity(0.2))
                    .frame(width: 40, height: 5)
                    .frame(width: 80, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Find")
            .accessibilityHint("Or swipe down on the player")
            Spacer(minLength: 4)
            optionsMenu
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .opacity(flash == nil ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: flash == nil)
    }

    private var airPlay: some View {
        Image(systemName: player.outputName == nil ? "airplayaudio" : "airplayaudio.circle.fill")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(player.outputName == nil ? Theme.ink : Theme.accentText)
            .frame(width: 44, height: 44)
            .allowsHitTesting(false)
            .background(RoutePicker(tint: .clear))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playing on \(player.outputName ?? "iPhone"). Choose another device")
            .accessibilityAddTraits(.isButton)
    }

    /// Episode options: speed and sound, chapters, notes, the show,
    /// download, transcript, share, mark played.
    @ViewBuilder private var optionsMenu: some View {
        if let episode {
            Menu {
                Button("Speed and sound…", systemImage: "slider.horizontal.3") { showingOptions = true }
                Button("Chapters", systemImage: "list.bullet") { showingChapters = true }
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
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Episode options")
        } else {
            Color.clear.frame(width: 44, height: 44)
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

    // MARK: Episode keys

    static let keysHeight: CGFloat = 36

    /// Download · Transcribe · Mark played as three words spread evenly
    /// under the title (Paul, 13 Nov 2026, D on
    /// https://claude.ai/artifact/X49sL6x7gvwQoJMX3dqhed). Words you can
    /// tap are in the accent; done ones are grey with a tick; while a
    /// download or transcript is on its way the word fills with the accent
    /// left to right as it goes (tap to stop).
    private func episodeKeys(_ episode: PodcastEpisode) -> some View {
        HStack(spacing: 0) {
            downloadKey(episode)
            transcriptKey(episode)
            HaarKeyWord(text: "Mark played", state: .action, action: markPlayed)
        }
        .frame(height: Self.keysHeight)
    }

    private func downloadKey(_ episode: PodcastEpisode) -> some View {
        if let fraction = downloads.progress[episode.episodeID] {
            return HaarKeyWord(text: "Downloading \(Int(fraction * 100))%", state: .working(fraction)) {
                store.removeDownload(episode)
            }
        }
        if store.localAudioURL(for: episode) != nil {
            return HaarKeyWord(text: "Downloaded", state: .done) { confirmRemove = true }
        }
        return HaarKeyWord(text: "Download", state: .action) { downloads.download(episode) }
    }

    private func transcriptKey(_ episode: PodcastEpisode) -> some View {
        let id: String = episode.episodeID
        if transcripts.isQueued(episode) {
            let fraction: Double = episode.transcriptState == .transcribing
                ? (transcripts.progress[id] ?? 0)
                : (downloads.progress[id] ?? 0)
            let text: String = episode.transcriptState == .transcribing
                ? "Transcribing \(Int(fraction * 100))%"
                : "Waiting…"
            return HaarKeyWord(text: text, state: .working(fraction)) { transcripts.stop(episode) }
        }
        if episode.transcriptState == .ready {
            return HaarKeyWord(text: "Read along", state: .done) { setReading(true) }
        }
        if !transcripts.canTranscribeNow(episode) {
            return HaarKeyWord(text: "Read along", state: .action) { setReading(true) }
        }
        return HaarKeyWord(text: "Transcribe", state: .action) { transcripts.transcribeNow(episode) }
    }

    // MARK: Artwork and title

    /// The artwork, filling whatever frame it's given (so it can grow and
    /// shrink as it moves between the middle and the corner).
    private func artworkImage(_ item: PlayerModel.NowPlaying, radius: CGFloat) -> some View {
        Color.clear
            .overlay {
                CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .matchedGeometryEffect(id: "artwork", in: art)
            .accessibilityHidden(true)
    }

    private func bigArtwork(_ item: PlayerModel.NowPlaying, side: CGFloat) -> some View {
        Button { setReading(true) } label: {
            artworkImage(item, radius: side > 200 ? 46 : side * 0.16)
                .frame(width: side, height: side)
                .shadow(color: Color(hex: 0x28323C).opacity(0.22), radius: 30, y: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Artwork")
        .accessibilityHint("Shows the words as they're said")
    }

    /// The show (tap for its page) above the title (tap to read along).
    private func titleBlock(_ item: PlayerModel.NowPlaying, size: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            Button {
                if let show = episode?.podcast { store.revealShow = show }
            } label: {
                Text(item.showTitle.uppercased() + " ›")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.accentText)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.showTitle)
            .accessibilityHint("Opens the show")
            Button { setReading(!reading) } label: {
                Text(item.title)
                    .font(Theme.serif(size))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(compact ? 2 : 3)
                    .minimumScaleFactor(compact ? 1 : 0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(reading ? "Back to the artwork" : "Shows the words as they're said")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .matchedGeometryEffect(id: "title", in: art, properties: .position, anchor: .topLeading)
    }

    /// Read along and Up next: the artwork in the corner, the show and
    /// title beside it, ⌄ to go back.
    private func cornerHeader(_ item: PlayerModel.NowPlaying, backLabel: String, back: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Button(action: back) {
                artworkImage(item, radius: 17)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(hex: 0x28323C).opacity(0.14), radius: 8, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(backLabel)
            titleBlock(item, size: 15, compact: true)
            Spacer(minLength: 6)
            backButton(backLabel, action: back)
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 12)
    }

    private func backButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Controls

    /// The progress line with the times and chapter, the transport and the
    /// volume: the same block in Listen and Read along, so it glides
    /// between the two.
    private func controls(_ item: PlayerModel.NowPlaying, volume: Bool) -> some View {
        VStack(spacing: 0) {
            HaarScrubLine(episodeID: item.episodeID, openChapters: { showingChapters = true })
            HaarTransport()
                .padding(.top, 10)
            if volume {
                HaarVolumeLine()
                    .padding(.top, 10)
            }
        }
        .matchedGeometryEffect(id: "controls", in: art)
    }

    // MARK: Read along

    private func readAlong(_ item: PlayerModel.NowPlaying, size: CGSize) -> some View {
        VStack(spacing: 0) {
            cornerHeader(item, backLabel: "Back to player") { setReading(false) }
            Group {
                if let episode {
                    HaarReadAlong(episode: episode)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(AnyTransition.opacity.combined(with: .offset(y: 40)).animation(reduceMotion ? nil : Self.rise))
            controls(item, volume: Self.roomForVolume(size))
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
        .padding(.bottom, bottomRoom)
    }

    // MARK: Up next

    private func upNext(size: CGSize) -> some View {
        VStack(spacing: 0) {
            if let item = player.nowPlaying {
                cornerHeader(item, backLabel: "Close Up next", back: closeUpNext)
            } else {
                HStack {
                    Spacer()
                    backButton("Close Up next", action: closeUpNext)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            HaarUpNextList(close: closeUpNext, openFind: openFind)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.bottom, max(0, bottomRoom - 12))
    }

    // MARK: Toasts

    /// A new chapter's name at the very top, and the ad pill under the
    /// top bar.
    private var toasts: some View {
        VStack(spacing: 0) {
            ZStack {
                if let flash {
                    chapterPill(flash)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(height: 44)
            if mode != .upNext {
                adToast
                    .padding(.top, 24)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.1), value: player.currentAd?.start)
        .animation(.spring(duration: 0.45, bounce: 0.1), value: player.lastSkippedAd?.start)
    }

    private func showFlash(from old: Int?, to new: Int?) {
        // Only when playing moves on into a new chapter, not on opening.
        guard player.isPlaying, let old, let new, new != old else { return }
        let chapters = player.chapters
        guard chapters.indices.contains(new) else { return }
        let card = ChapterFlash(number: new + 1, title: chapters[new].title)
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) { flash = card }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if flash == card {
                withAnimation(.easeOut(duration: 0.4)) { flash = nil }
            }
        }
    }

    private func chapterPill(_ card: ChapterFlash) -> some View {
        HStack(spacing: 8) {
            Text("CHAPTER \(card.number)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Theme.accentText)
            Text(card.title)
                .font(Theme.serif(18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .haarQueueCard(radius: 18)
        .padding(.horizontal, 40)
        .onTapGesture { showingChapters = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// While an ad plays: "Ad · Skip". Just after a skip: "Ad skipped ·
    /// Play it". Touch and hold for Not an ad.
    @ViewBuilder private var adToast: some View {
        if let adBreak = player.currentAd {
            adPill(text: "Ad", action: "Skip") { player.skipCurrentAd() }
                .contextMenu {
                    Button("Not an ad", systemImage: "xmark.circle") { player.notAnAd(adBreak, transcripts: transcripts) }
                }
                .accessibilityHint("Show resumes at \(TimeFormat.clock(adBreak.end))")
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let adBreak = player.lastSkippedAd {
            adPill(text: "Ad skipped", action: "Play it") { player.playAd(adBreak) }
                .contextMenu {
                    Button("Not an ad", systemImage: "xmark.circle") { player.notAnAd(adBreak, transcripts: transcripts) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func adPill(text: String, action: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                Text("·")
                    .font(.system(size: 14))
                    .opacity(0.6)
                Text(action)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Color(hex: 0xF4F2EE))
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0x1F2328)))
            .shadow(color: Color(hex: 0x1F2328).opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text). \(action)")
    }

    // MARK: Nothing playing

    /// Nothing playing: the top of Up Next ready to play, or a way to find
    /// something.
    private func idle(size: CGSize) -> some View {
        let upcoming: PodcastEpisode? = store.queue.first.flatMap { store.episode($0.episode.id) }
        let side: CGFloat = max(110, min(260, size.width - 48, size.height - bottomRoom - 420))
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: openFind) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.2))
                        .frame(width: 40, height: 5)
                        .frame(width: 80, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Find")
                Spacer()
            }
            Spacer(minLength: 8)
            if let upcoming {
                idleUpcoming(upcoming, side: side)
            } else {
                idleEmpty
            }
            Spacer(minLength: 8)
            if upcoming != nil {
                HaarUpNextStack(open: openUpNext, openFind: openFind, skipFirst: true)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, bottomRoom)
        .frame(maxWidth: .infinity)
    }

    private func idleUpcoming(_ upcoming: PodcastEpisode, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { player.play(upcoming) } label: {
                Color.clear
                    .frame(width: side, height: side)
                    .overlay {
                        CachedImage(url: upcoming.artwork) { Theme.placeholderColor(for: upcoming.showTitle) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: side > 200 ? 46 : side * 0.16, style: .continuous))
                    .shadow(color: Color(hex: 0x28323C).opacity(0.22), radius: 30, y: 30)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Play \(upcoming.title)")
            Text((upcoming.position > 5 ? "Carry on · " : "Up next · ") + upcoming.showTitle)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accentText)
                .lineLimit(1)
                .padding(.top, 24)
            Text(upcoming.title)
                .font(Theme.serif(upcoming.title.count > 44 ? 25 : 33))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
            HStack {
                Text(HaarQueueText.meta(upcoming, speed: player.speed, transcripts: transcripts))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                HaarPlayCircle(playing: false) { player.play(upcoming) }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
    }

    private var idleEmpty: some View {
        VStack(spacing: 0) {
            Text("Nothing playing")
                .font(Theme.serif(34))
                .foregroundStyle(Theme.ink)
            Text("Up next is empty. Find a show, or pick an episode in your Library.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 40)
            Button(action: openFind) {
                Text("Find something")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }
}

// MARK: - Transport

/// The big play key: a filled circle in the colour of what's playing.
/// One of the Now screen's episode keys: a word taking an equal share of
/// the row. While something is on its way it fills with the accent from
/// left to right as it goes.
struct HaarKeyWord: View {
    enum Kind: Equatable {
        case action
        case done
        case working(Double)
    }

    let text: String
    let state: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var label: some View {
        switch state {
        case .action:
            word(text).foregroundStyle(Theme.accentText)
        case .done:
            // No tick (Paul, 14 Nov 2026): done ones are just quieter.
            word(text).foregroundStyle(Theme.muted)
        case .working(let fraction):
            word(text)
                .foregroundStyle(Theme.muted.opacity(0.55))
                .overlay(alignment: .leading) {
                    word(text)
                        .foregroundStyle(Theme.accentText)
                        .mask(alignment: .leading) {
                            GeometryReader { geometry in
                                Rectangle()
                                    .frame(width: geometry.size.width * CGFloat(min(1, max(0, fraction))))
                            }
                        }
                }
                .animation(.easeOut(duration: 0.4), value: fraction)
        }
    }

    private func word(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var accessibilityText: String {
        switch state {
        case .working: "\(text), tap to stop"
        default: text
        }
    }
}

struct HaarPlayCircle: View {
    let playing: Bool
    var size: CGFloat = 70
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.37, weight: .semibold))
                .foregroundStyle(Color.white)
                .offset(x: playing ? 0 : size * 0.035)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.accentFill))
                .shadow(color: Theme.accentFill.opacity(0.35), radius: 17, y: 14)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "Pause" : "Play")
    }
}

/// Speed, skip back, play, skip forward, sleep. Speed and sleep step
/// through their usual choices with each tap (the full choices are in
/// ⋯ → Speed and sound…).
struct HaarTransport: View {
    @Environment(PlayerModel.self) private var player

    private static let speeds: [Double] = [1, 1.3, 1.5, 2]
    private static let sleeps: [SleepTimerOption] = [.minutes(15), .minutes(30), .minutes(45), .minutes(60), .endOfEpisode]

    var body: some View {
        HStack(spacing: 0) {
            speedButton
            Spacer(minLength: 4)
            SkipButton(direction: .back, iconSize: 30, frame: 56)
            Spacer(minLength: 4)
            HaarPlayCircle(playing: player.isPlaying) { player.togglePlayPause() }
            Spacer(minLength: 4)
            SkipButton(direction: .forward, iconSize: 30, frame: 56)
            Spacer(minLength: 4)
            sleepButton
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .frame(height: 70)
    }

    private var speedButton: some View {
        Button { player.setSpeed(Self.nextSpeed(after: player.speed)) } label: {
            Text(PlayerOptions.speedLabel(player.speed))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(player.speed == 1 ? Theme.ink : Theme.accentText)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speed \(PlayerOptions.speedLabel(player.speed))")
        .accessibilityHint("Tap for the next speed")
    }

    /// 1 → 1.3 → 1.5 → 2 → 1 (a speed in between goes to the next one up).
    static func nextSpeed(after speed: Double) -> Double {
        let current: Double = (speed * 10).rounded() / 10
        return speeds.first { $0 > current + 0.01 } ?? 1
    }

    private var sleepButton: some View {
        let on: Bool = player.sleepTimer != nil
        return Button { stepSleep() } label: {
            // The moon never moves: the minutes sit under it as an overlay
            // (Paul, 13 Nov 2026: it jumped up as the text came in).
            Image(systemName: on ? "moon.fill" : "moon")
                .font(.system(size: 20, weight: .regular))
                .frame(width: 24, height: 24)
                .overlay(alignment: .bottom) {
                    if on {
                        sleepLabel
                            .fixedSize()
                            .offset(y: 14)
                    }
                }
                .foregroundStyle(on ? Theme.accentText : Theme.ink)
                .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Sleep timer on" : "Sleep timer off")
        .accessibilityHint("Tap for the next sleep time")
    }

    /// Minutes left on the sleep timer, or "end".
    private var sleepLabel: some View {
        TimelineView(.periodic(from: Date(), by: 15)) { context in
            Text(sleepText(at: context.date))
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
        }
    }

    private func sleepText(at date: Date) -> String {
        if player.sleepTimer == .endOfEpisode { return "END" }
        guard let ends = player.sleepEndsAt else { return "" }
        let minutes: Int = max(1, Int((ends.timeIntervalSince(date) / 60).rounded(.up)))
        return "\(minutes)M"
    }

    /// Off → 15 → 30 → 45 → 60 → end of episode → off.
    private func stepSleep() {
        guard let current = player.sleepTimer else {
            player.chooseSleepTimer(Self.sleeps[0])
            return
        }
        if let index = Self.sleeps.firstIndex(of: current), index + 1 < Self.sleeps.count {
            player.chooseSleepTimer(Self.sleeps[index + 1])
        } else if current == .endOfEpisode {
            player.setSleepTimer(nil)
        } else {
            // A time set elsewhere (5 minutes, or extended): on to the next one up.
            let minutesNow: Int = player.sleepEndsAt.map { Int($0.timeIntervalSinceNow / 60) } ?? 0
            let next: SleepTimerOption = Self.sleeps.first { (option: SleepTimerOption) -> Bool in
                if case .minutes(let minutes) = option { return minutes > minutesNow }
                return true
            } ?? .endOfEpisode
            player.chooseSleepTimer(next)
        }
    }
}

/// The volume as a thin line the width of the progress line, a small
/// speaker at each end; the dot only shows while it's touched (Paul's
/// pick "A", 13 Nov 2026).
struct HaarVolumeLine: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            HaarVolumeSlider()
                .frame(height: 24)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .frame(height: 24)
    }
}

/// The iPhone's own volume slider, drawn as a 2-point ink line; its knob
/// is invisible until touched.
struct HaarVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> CentredVolumeView {
        // Made with a real size (not .zero): iOS decides whether to hide
        // its own volume bar from how the slider looks when it joins the
        // window.
        let view = CentredVolumeView(frame: CGRect(x: 0, y: 0, width: 200, height: 24))
        let ink = UIColor(Theme.ink)
        view.tintColor = ink
        view.setVolumeThumbImage(Self.dot(16, colour: .clear), for: .normal)
        view.setVolumeThumbImage(Self.dot(16, colour: ink), for: .highlighted)
        view.setMinimumVolumeSliderImage(Self.track(ink), for: .normal)
        view.setMaximumVolumeSliderImage(Self.track(ink.withAlphaComponent(0.16)), for: .normal)
        return view
    }

    func updateUIView(_ view: CentredVolumeView, context: Context) {}

    private static func dot(_ size: CGFloat, colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            colour.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: size - 4, height: size - 4)).fill()
        }
    }

    /// A 2 pt rounded line that stretches.
    private static func track(_ colour: UIColor) -> UIImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 2)).image { _ in
            colour.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 5, height: 2), cornerRadius: 1).fill()
        }
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2))
    }
}

/// Keeps iOS's own volume bar from popping up at the side of the screen
/// when the volume buttons are pressed (Paul, build 152). iOS leaves its
/// bar away only while a volume slider is in the window, shown and not
/// see-through; the visible line comes and goes (not in Up next, nothing
/// playing, short screens, and it's remade on every Read along morph), so
/// this tiny, almost invisible one stays on the Haar screens all the time.
/// It is 2 points, at 1% opacity, and takes no touches.
struct HaarVolumeHUDHider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        if view.alpha < 0.01 { view.alpha = 0.01 }
    }
}

/// ‹ 3 The bunker ˅ ›: the chapter now; ‹ › skip between chapters, the
/// middle opens the chapter list (even when the episode has none).
struct HaarChapterControl: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    var body: some View {
        let chapters: [Chapter] = player.chapters
        let index: Int? = player.currentChapterIndex
        let canNext: Bool = !chapters.isEmpty && (index ?? -1) < chapters.count - 1
        HStack(spacing: 0) {
            arrow("chevron.left", label: "Previous chapter", enabled: !chapters.isEmpty) { player.previousChapter() }
            Button(action: open) { middle(chapters: chapters, index: index) }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibility(chapters: chapters, index: index))
                .accessibilityHint("Shows every chapter")
            arrow("chevron.right", label: "Next chapter", enabled: canNext) { player.nextChapter() }
        }
    }

    private func middle(chapters: [Chapter], index: Int?) -> some View {
        let title: String = index.flatMap { chapters.indices.contains($0) ? chapters[$0].title : nil } ?? "Chapters"
        return HStack(spacing: 5) {
            Text(index.map { "\($0 + 1)" } ?? "—")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.accentText)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(label)
    }

    private func accessibility(chapters: [Chapter], index: Int?) -> String {
        guard let index, chapters.indices.contains(index) else { return "Chapters" }
        return "Chapter \(index + 1) of \(chapters.count), \(chapters[index].title)"
    }
}

// MARK: - Progress line

/// The progress line, plain like Poddeck's (Paul, 13 Nov 2026: the
/// waveform's shape needn't mimic the sound, simplify it): a thin line
/// split by small gaps at chapters, played part in ink, the rest faded,
/// ad breaks fainter, a dot at the play point that grows while you drag.
/// Drag anywhere along it: it moves by how far the finger travels (a touch
/// never jumps), finger lower down for finer, a bubble shows the chapter
/// and time, and a jump of 2 minutes or more offers Undo.
/// Under it: the time played, the chapter control, and the time left at
/// this speed (tap it for when it ends: Paul's pick "B").
struct HaarScrubLine: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let episodeID: String
    /// Opens the chapter list.
    let openChapters: () -> Void

    @State private var scrubTime: TimeInterval?
    @State private var scrubStart: TimeInterval?
    @State private var lastX: CGFloat?
    @State private var speedLabel: String?
    /// Show "ends 21:42" instead of "−41:48".
    @AppStorage("haarShowEnds") private var showEnds = false

    /// The touch band; the line sits in its middle.
    static let height: CGFloat = 30
    /// The line plus the time row under it.
    static let blockHeight: CGFloat = 30 + 2 + 36

    var body: some View {
        let duration: TimeInterval = max(player.duration, 1)
        let shown: TimeInterval = scrubTime ?? player.currentTime
        let left: TimeInterval = max(0, player.duration - shown)
        VStack(spacing: 2) {
            line(shown: shown, left: left, duration: duration)
            timeRow(shown: shown, left: left)
        }
    }

    private func line(shown: TimeInterval, left: TimeInterval, duration: TimeInterval) -> some View {
        GeometryReader { geometry in
            let width: CGFloat = max(1, geometry.size.width)
            ZStack(alignment: .topLeading) {
                PlainLine(progress: shown / duration, chapterStarts: chapterStarts, ads: adFractions,
                          grow: scrubTime == nil ? 0 : 1)
                    .frame(width: width, height: Self.height)
                    .animation(.easeOut(duration: 0.18), value: scrubTime == nil)
                if scrubTime != nil {
                    bubble(at: shown, x: CGFloat(shown / duration) * width, width: width)
                }
            }
            .contentShape(Rectangle())
            .gesture(scrub(width: width, duration: duration))
        }
        .frame(height: Self.height)
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

    /// Played · chapter · left (or ends).
    private func timeRow(shown: TimeInterval, left: TimeInterval) -> some View {
        let atSpeed: TimeInterval = left / max(player.speed, 0.5)
        let ends: Date = Date().addingTimeInterval(atSpeed)
        return HStack(spacing: 4) {
            Text(TimeFormat.clock(shown))
                .frame(minWidth: 56, alignment: .leading)
            Spacer(minLength: 0)
            middle
            Spacer(minLength: 0)
            Button { showEnds.toggle() } label: {
                Text(showEnds ? "ends " + UpNextTimes.clock(ends) : "−" + TimeFormat.clock(atSpeed))
                    .lineLimit(1)
                    .frame(minWidth: 56, minHeight: 36, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showEnds ? "Ends at \(UpNextTimes.clock(ends))" : "\(TimeFormat.clock(atSpeed)) left")
            .accessibilityHint(showEnds ? "Shows the time left" : "Shows when it ends")
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(Theme.muted)
        .frame(height: 36)
    }

    /// The chapter control, or how fast it's scrubbing while dragging.
    @ViewBuilder private var middle: some View {
        if let speedLabel {
            Text(speedLabel)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            HaarChapterControl(open: openChapters)
                .layoutPriority(1)
        }
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.compactMap { ad in
            let start = ad.start / player.duration, end = ad.end / player.duration
            return start <= end ? start...end : nil
        }
    }

    /// Where each chapter starts, as a fraction of the episode.
    private var chapterStarts: [Double] {
        guard player.duration > 0 else { return [] }
        return player.chapters.map { $0.start / player.duration }
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
}

/// Draws the line: chapter gaps, played in ink, ahead faded, ads fainter,
/// and the play-point dot. `grow` (0 at rest, 1 while dragging) animates
/// it a little thicker with a bigger dot.
private struct PlainLine: View, Animatable {
    let progress: Double
    let chapterStarts: [Double]
    let ads: [ClosedRange<Double>]
    var grow: Double

    var animatableData: Double {
        get { grow }
        set { grow = newValue }
    }

    var body: some View {
        Canvas { context, size in
            Self.draw(in: context, size: size, progress: progress, chapterStarts: chapterStarts, ads: ads, grow: CGFloat(grow))
        }
        .accessibilityHidden(true)
    }

    // Split out (with explicit types) so the compiler checks it quickly.
    private static func draw(in context: GraphicsContext, size: CGSize, progress: Double,
                             chapterStarts: [Double], ads: [ClosedRange<Double>], grow: CGFloat) {
        let ink: Color = Theme.ink
        let dot: CGFloat = 12 + 6 * grow
        let x0: CGFloat = dot / 2
        let span: CGFloat = max(1, size.width - dot)
        let thickness: CGFloat = 5 + 4 * grow
        let top: CGFloat = (size.height - thickness) / 2
        let playedX: CGFloat = x0 + span * CGFloat(min(1, max(0, progress)))
        let inner: [Double] = chapterStarts.filter { $0 > 0.002 && $0 < 0.998 }.sorted()
        let cuts: [Double] = [0] + inner + [1]
        let gap: CGFloat = 3
        for index in 0..<(cuts.count - 1) {
            let start: CGFloat = x0 + span * CGFloat(cuts[index]) + (index > 0 ? gap / 2 : 0)
            let end: CGFloat = x0 + span * CGFloat(cuts[index + 1]) - (index < cuts.count - 2 ? gap / 2 : 0)
            guard end > start else { continue }
            let shape = Path(roundedRect: CGRect(x: start, y: top, width: end - start, height: thickness),
                             cornerRadius: thickness / 2)
            var segment = context
            segment.clip(to: shape)
            segment.fill(shape, with: .color(ink.opacity(0.16)))
            if playedX > start {
                let played = CGRect(x: start, y: top, width: min(end, playedX) - start, height: thickness)
                segment.fill(Path(played), with: .color(ink))
            }
            for ad in ads {
                let adStart: CGFloat = max(start, x0 + span * CGFloat(ad.lowerBound))
                let adEnd: CGFloat = min(end, x0 + span * CGFloat(ad.upperBound))
                guard adEnd > adStart else { continue }
                // Ads read paler than the rest, played or not.
                let adRect = CGRect(x: adStart, y: top, width: adEnd - adStart, height: thickness)
                segment.fill(Path(adRect), with: .color(Theme.background.opacity(0.55)))
            }
        }
        let dotRect = CGRect(x: playedX - dot / 2, y: (size.height - dot) / 2, width: dot, height: dot)
        context.fill(Path(ellipseIn: dotRect), with: .color(ink))
    }
}


// MARK: - Read along

/// The transcript as you listen: the line now in the serif with each word
/// lit as it's said (timed across the line; transcripts give a time per
/// line, not per word): the word now in the show's colour, words said in
/// ink, words to come faint. Other lines smaller and muted, heard ones
/// fainter; the speaker's name when it changes; chapter breaks as a fine
/// rule with the chapter's name. Tap a line to play from it; touch and
/// hold to share a clip or copy. Scrolling by hand stops it following for
/// a few seconds (or tap Back to now). Make a clip under it.
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

    private static let anchor = UnitPoint(x: 0.5, y: 0.32)

    private var isPlayingThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    private var nowIndex: Int? {
        guard isPlayingThis else { return nil }
        let time: TimeInterval = player.currentTime + 0.2
        return lines.lastIndex { $0.start <= time }
    }

    var body: some View {
        Group {
            if lines.isEmpty {
                HaarWordsOnTheWay(episode: episode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    list
                    clipButton
                }
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
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        entry(line, index: index, now: now)
                            .id(index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .scrollIndicators(.hidden)
            .mask { Self.fade }
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
                withAnimation(.easeInOut(duration: 0.7)) { proxy.scrollTo(index, anchor: Self.anchor) }
            }
            .onAppear {
                if let now { proxy.scrollTo(now, anchor: Self.anchor) }
            }
            .overlay(alignment: .bottom) {
                if followPaused, let now {
                    backToNow { withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(now, anchor: Self.anchor) } }
                }
            }
        }
    }

    private static var fade: LinearGradient {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                               .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    private func backToNow(_ scroll: @escaping () -> Void) -> some View {
        Button {
            followPaused = false
            scroll()
        } label: {
            Text("Back to now")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .haarQueueCard(radius: 18)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
    }

    /// A chapter rule and the speaker's name where they belong, then the line.
    @ViewBuilder private func entry(_ line: TranscriptLayout.Line, index: Int, now: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let chapter = chapterStarting(at: index) {
                chapterRule(chapter)
                    .padding(.bottom, 4)
            }
            if let speaker = speakerChange(at: index) {
                Text(speaker.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.accentText)
                    .lineLimit(1)
            }
            row(line, index: index, now: now)
        }
    }

    @ViewBuilder private func row(_ line: TranscriptLayout.Line, index: Int, now: Int?) -> some View {
        let isNow: Bool = index == now
        let heard: Bool = now.map { index < $0 } ?? false
        Group {
            if isNow {
                TimelineView(.animation(minimumInterval: 0.1, paused: !player.isPlaying)) { context in
                    Text(litText(line, at: context.date))
                        .font(Theme.serif(31))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(line.text)
                    .font(.system(size: 16))
                    .lineSpacing(7)
                    .foregroundStyle(Theme.muted)
                    .opacity(heard ? 0.5 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { play(from: line) }
        .contextMenu {
            Button("Share a clip", systemImage: "scissors") { clip = ClipRequest(line: line, quote: line.text) }
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = line.text }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays from here")
    }

    private func play(from line: TranscriptLayout.Line) {
        if isPlayingThis {
            player.seek(to: line.start)
        } else {
            player.play(episode)
            player.seek(to: line.start)
        }
    }

    /// The line now: words said in ink, the word now in the show's
    /// colour, words to come faint.
    private func litText(_ line: TranscriptLayout.Line, at date: Date) -> AttributedString {
        let words: [Substring] = line.text.split(separator: " ")
        let span: TimeInterval = max(0.5, line.end - line.start)
        let since: TimeInterval = player.isPlaying ? min(0.7, max(0, date.timeIntervalSince(anchorDate))) * player.speed : 0
        let time: TimeInterval = anchorTime + since
        let done: Double = min(1, max(0, (time - line.start) / span))
        let litCount: Int = Int((done * Double(words.count)).rounded(.up))
        let ink: Color = Theme.ink
        let accent: Color = Theme.accentText
        let faint: Color = Theme.ink.opacity(0.32)
        var text = AttributedString()
        for (index, word) in words.enumerated() {
            var piece = AttributedString(String(word) + (index == words.count - 1 ? "" : " "))
            if index < litCount - 1 {
                piece.foregroundColor = ink
            } else if index == litCount - 1 {
                piece.foregroundColor = accent
            } else {
                piece.foregroundColor = faint
            }
            text += piece
        }
        return text
    }

    /// The speaker's name when it changes from the line before.
    private func speakerChange(at index: Int) -> String? {
        guard lines.indices.contains(index), let speaker = lines[index].speaker, !speaker.isEmpty else { return nil }
        let previous: String? = index > 0 ? lines[index - 1].speaker : nil
        return speaker == previous ? nil : speaker
    }

    /// The chapter that starts at this line (the first line at or after
    /// its start), if any.
    private func chapterStarting(at index: Int) -> String? {
        let chapters = player.chapters
        guard isPlayingThis, !chapters.isEmpty, lines.indices.contains(index) else { return nil }
        let start: TimeInterval = lines[index].start
        let previous: TimeInterval = index > 0 ? lines[index - 1].start : -1
        guard let found = chapters.firstIndex(where: { $0.start > previous && $0.start <= start }) else { return nil }
        return chapters[found].title
    }

    private func chapterRule(_ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.accentText.opacity(0.3)).frame(height: 1)
            Text(title)
                .font(Theme.serif(16))
                .foregroundStyle(Theme.accentText)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle().fill(Theme.accentText.opacity(0.3)).frame(height: 1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter: \(title)")
    }

    /// Make a clip of the line now (or the first line).
    private var clipButton: some View {
        Button {
            let index: Int = nowIndex ?? 0
            guard lines.indices.contains(index) else { return }
            clip = ClipRequest(line: lines[index], quote: lines[index].text)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .font(.system(size: 13, weight: .semibold))
                Text("Make a clip")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

/// Read along before there are words: where the transcript has got to, a
/// short note, and Transcribe now (made on the iPhone from the download).
struct HaarWordsOnTheWay: View {
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode

    private var working: Bool {
        episode.transcriptState == .transcribing || transcripts.isQueued(episode) || transcripts.isRequested(episode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label = statusLabel {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)
                    .monospacedDigit()
                    .foregroundStyle(Theme.accentText)
                    .padding(.bottom, 10)
            }
            Text(headline)
                .font(Theme.serif(34))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let fraction = progress {
                bar(fraction)
                    .padding(.top, 16)
            }
            Text("Chapters, search and clips switch on once the words are in. Poddeck makes them on your phone, from the downloaded episode.")
                .font(.system(size: 14))
                .lineSpacing(7)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
            actions
                .padding(.top, 12)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var headline: String {
        switch episode.transcriptState {
        case .failed: return "No words this time."
        case .none where !working && !transcripts.isFetchingPublisher(episode): return "No words yet."
        default: return "Words are on their way."
        }
    }

    /// "TRANSCRIBING ON YOUR PHONE · 64%", "DOWNLOADING FIRST · 40%",
    /// "WAITING TO TRANSCRIBE"…
    private var statusLabel: String? {
        let id: String = episode.episodeID
        switch episode.transcriptState {
        case .transcribing:
            if let fraction = transcripts.progress[id] { return "TRANSCRIBING ON YOUR PHONE · \(Int(fraction * 100))%" }
            return "TRANSCRIBING ON YOUR PHONE"
        case .failed:
            return "COULDN'T MAKE A TRANSCRIPT"
        default:
            if transcripts.isFetchingPublisher(episode) { return "GETTING THE SHOW'S TRANSCRIPT" }
            guard working else { return nil }
            if let fraction = downloads.progress[id] { return "DOWNLOADING FIRST · \(Int(fraction * 100))%" }
            return "WAITING TO TRANSCRIBE"
        }
    }

    private var progress: Double? {
        let id: String = episode.episodeID
        if episode.transcriptState == .transcribing { return transcripts.progress[id] }
        guard working else { return nil }
        return downloads.progress[id]
    }

    private func bar(_ fraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.14))
                Capsule()
                    .fill(Theme.accentFill)
                    .frame(width: geometry.size.width * CGFloat(min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.4), value: fraction)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var actions: some View {
        if working {
            HStack(spacing: 18) {
                Text("Transcribing now…")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentText.opacity(0.7))
                Button("Stop") { transcripts.stop(episode) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop transcribing")
            }
            .frame(minHeight: 44)
        } else if !transcripts.isFetchingPublisher(episode) {
            Button { transcripts.transcribeNow(episode) } label: {
                Text(episode.transcriptState == .failed ? "Try again" : "Transcribe now")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
