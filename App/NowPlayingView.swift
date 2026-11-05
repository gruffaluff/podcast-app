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
    @AppStorage("playerShowsTranscript") private var showsTranscript = false

    private var currentEpisode: PodcastEpisode? {
        player.nowPlaying.flatMap { store.episode($0.episodeID) }
    }

    var body: some View {
        Group {
            if let item = player.nowPlaying {
                let tint = ArtworkColors.shared.background(for: item.artworkURL) ?? Theme.display
                ScrollView {
                    VStack(spacing: 0) {
                        hero(item, tint: tint)
                        VStack(spacing: 14) {
                            clock
                            scrubBar(tint: tint)
                            transport(tint: tint)
                            modeKeys(tint: tint)
                            nextUp
                            if let episode = currentEpisode {
                                EpisodeNotesText(episode: episode)
                                    .padding(.top, 6)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(edges: .top)
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
        .transcribeExplainer()
    }

    // MARK: Top area

    private func hero(_ item: PlayerModel.NowPlaying, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                deviceButton
                Spacer()
                moreMenu
            }
            Group {
                if showsTranscript, let episode = currentEpisode {
                    PlayerTranscriptPanel(episode: episode)
                } else {
                    artworkContent(item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            adBar
            modeSwitch(tint: tint)
        }
        .foregroundStyle(Theme.displayText)
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 18)
        .frame(height: 450)
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
        .background(.black.opacity(0.22), in: Capsule())
        .overlay(RoutePicker(tint: .clear).opacity(0.02))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playing on \(player.outputName ?? "iPhone"). Choose another device")
        .accessibilityAddTraits(.isButton)
    }

    private var moreMenu: some View {
        Menu {
            Button("Episode notes", systemImage: "doc.text") { showingNotes = true }
            if !player.chapters.isEmpty {
                Button("Chapters", systemImage: "list.number") { showingChapters = true }
            }
            Button("Full transcript", systemImage: "text.quote") { transcriptEpisode = currentEpisode }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .bold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.22), in: Circle())
        }
        .accessibilityLabel("More")
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

    private var clock: some View {
        let shown = scrubTime ?? player.currentTime
        return HStack(alignment: .firstTextBaseline) {
            Text(TimeFormat.clock(shown))
                .font(Theme.big(46))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(player.duration > 0 ? "−" + TimeFormat.clock(max(0, player.duration - shown)) : "")
                .font(Theme.mono(15, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }

    /// The wave progress bar; drag along it to scrub.
    private func scrubBar(tint: Color) -> some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        return GeometryReader { geometry in
            SegmentBar(progress: shown / duration, ads: adFractions, count: 44, height: 34, played: tint, track: Theme.hairline)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = min(1, max(0, value.location.x / max(1, geometry.size.width)))
                            scrubTime = fraction * duration
                        }
                        .onEnded { _ in
                            if let target = scrubTime { player.seek(to: target) }
                            scrubTime = nil
                        }
                )
        }
        .frame(height: 34)
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
    @ViewBuilder private var nextUp: some View {
        let playingID = player.nowPlaying?.episodeID
        let upcoming = store.queue.filter { $0.episode.id != playingID }
        if let next = upcoming.first {
            let episode = store.episode(next.episode.id)
            Button { dismiss() } label: {
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
                    Image(systemName: "chevron.up").font(.footnote.weight(.bold)).foregroundStyle(Theme.ink)
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Back to Up Next")
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
