import AVKit
import SwiftUI
import PodcastCore

/// The full player, styled as a tape deck: artwork tile and title, a dark
/// display with a big counter and segmented progress (ads in amber, drag to
/// scrub), chunky transport keys, a Skip ad key while an ad plays, and mode
/// keys with lights for speed, Trim silences, Boost voices and the sleep timer.
struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.dismiss) private var dismiss
    /// While dragging along the progress bar, where it would play from.
    @State private var scrubTime: TimeInterval?
    @State private var showingChapters = false
    @State private var transcriptEpisode: PodcastEpisode?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let item = player.nowPlaying {
                ScrollView {
                    VStack(spacing: 14) {
                        heading(item)
                        display
                        transport
                        adKeys
                        modeKeys
                        bottomKeys
                        if let episode = store.episode(item.episodeID) {
                            EpisodeNotesText(episode: episode)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                Text("NOTHING PLAYING")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.muted)
                    .onAppear { dismiss() }
            }
        }
        .tint(Theme.ink)
        .sheet(isPresented: $showingChapters) { ChaptersView() }
        .sheet(item: $transcriptEpisode) { TranscriptView(episode: $0) }
    }

    // MARK: Heading

    private func heading(_ item: PlayerModel.NowPlaying) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Chapter artwork when the show provides it.
            ArtworkView(url: player.currentChapter?.imageURL ?? item.artworkURL, title: item.showTitle, size: 120, radius: 12)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.showTitle.uppercased())
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(item.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                chapterLink
            }
            Spacer(minLength: 0)
        }
    }

    /// Current chapter; tap for the list.
    @ViewBuilder private var chapterLink: some View {
        if let index = player.currentChapterIndex {
            Button { showingChapters = true } label: {
                Text("CH \(index + 1)/\(player.chapters.count) · \(player.chapters[index].title.uppercased()) ▸")
                    .font(Theme.mono(11, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chapter \(index + 1) of \(player.chapters.count), \(player.chapters[index].title)")
            .accessibilityHint("Shows all chapters")
        }
    }

    // MARK: Display

    private var display: some View {
        let shown = scrubTime ?? player.currentTime
        return DeckDisplay {
            HStack {
                if let episode = player.nowPlaying.flatMap({ store.episode($0.episodeID) }) {
                    EpisodeLights(episode: episode, onDark: true)
                }
                Spacer()
                Text(player.outputName.map { "ON: \($0.uppercased())" } ?? "ON: IPHONE")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.displayDim)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(TimeFormat.clock(shown))
                    .font(Theme.mono(40, .bold))
                    .monospacedDigit()
                Spacer()
                Text(player.duration > 0 ? "−" + TimeFormat.clock(max(0, player.duration - shown)) : "")
                    .font(Theme.mono(14))
                    .monospacedDigit()
                    .foregroundStyle(Theme.displayDim)
            }
            scrubBar
            HStack {
                if let first = player.adBreaks.first {
                    Text("■").foregroundStyle(Theme.adMarker)
                        + Text(" AD \(TimeFormat.clock(first.start))–\(TimeFormat.clock(first.end))\(player.adBreaks.count > 1 ? " +\(player.adBreaks.count - 1)" : "")")
                } else {
                    Text(PlayerOptions.speedLabel(player.speed) + (player.trimSilences ? " · TRIM" : "") + (player.boostVoices ? " · BOOST" : ""))
                }
                Spacer()
            }
            .font(Theme.mono(11))
            .foregroundStyle(Theme.displayDim)
            if let adBreak = player.currentAd {
                Text("▸ AD PLAYING · \(TimeFormat.clock(max(0, adBreak.end - player.currentTime))) LEFT")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.adMarker)
            } else if let adBreak = player.lastSkippedAd {
                Text("▸ AD SKIPPED AT \(TimeFormat.clock(adBreak.start))")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.adMarker)
            }
        }
    }

    /// The segmented progress bar; drag along it to scrub.
    private var scrubBar: some View {
        let shown = scrubTime ?? player.currentTime
        let duration = max(player.duration, 1)
        return GeometryReader { geometry in
            SegmentBar(progress: shown / duration, ads: adFractions, count: 32, height: 24)
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
        .frame(height: 24)
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

    // MARK: Keys

    private var transport: some View {
        HStack(spacing: 8) {
            SkipButton(direction: .back, iconSize: 24, frame: 72)
                .frame(maxWidth: .infinity)
                .background(keyFace)
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.darkKey)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            SkipButton(direction: .forward, iconSize: 24, frame: 72)
                .frame(maxWidth: .infinity)
                .background(keyFace)
        }
        .tint(Theme.ink)
    }

    /// A key's raised face (for the skip menus, which can't take a button style).
    private var keyFace: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.surface)
            .shadow(color: Theme.controlBorder, radius: 0, x: 0, y: 3)
    }

    /// While an ad plays: a big Skip ad key (like Spotify's). After a skip:
    /// Play ad / Not an ad for a little while.
    @ViewBuilder private var adKeys: some View {
        if let adBreak = player.currentAd {
            HStack(spacing: 8) {
                Button { player.skipCurrentAd() } label: {
                    Text("SKIP AD ▸▸ \(TimeFormat.clock(adBreak.end))")
                        .font(Theme.mono(15, .bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.accentKey)
                .accessibilityLabel("Skip ad")
                Button { player.notAnAd(adBreak, transcripts: transcripts) } label: {
                    Text("NOT\nAN AD")
                        .font(Theme.mono(11, .bold))
                        .multilineTextAlignment(.center)
                        .frame(width: 76, height: 56)
                }
                .buttonStyle(.key)
                .accessibilityLabel("Not an ad")
            }
        } else if let adBreak = player.lastSkippedAd {
            HStack(spacing: 8) {
                Button { player.playAd(adBreak) } label: {
                    Text("PLAY AD").font(Theme.mono(12, .bold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.key)
                Button { player.notAnAd(adBreak, transcripts: transcripts) } label: {
                    Text("NOT AN AD").font(Theme.mono(12, .bold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.key)
            }
        }
    }

    /// SPEED / TRIM / BOOST / SLEEP, each with a light.
    private var modeKeys: some View {
        HStack(spacing: 8) {
            Menu {
                Picker(player.speedIsForShow ? "Speed for this show" : "Speed", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(PlayerOptions.speeds, id: \.self) { speed in
                        Text(PlayerOptions.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                modeFace(player.speedIsForShow ? "SHOW" : "SPEED", value: PlayerOptions.speedLabel(player.speed), lit: player.speed != 1)
            }
            .accessibilityLabel("Speed, \(PlayerOptions.speedLabel(player.speed))")

            Button { player.setTrimSilences(!player.trimSilences) } label: {
                modeLabel("TRIM", value: player.trimSilences ? "ON" : "OFF", lit: player.trimSilences)
            }
            .buttonStyle(.key)
            .accessibilityLabel("Trim silences: speeds through pauses")
            .accessibilityAddTraits(player.trimSilences ? .isSelected : [])

            Button { player.setBoostVoices(!player.boostVoices) } label: {
                modeLabel("BOOST", value: player.boostVoices ? "ON" : "OFF", lit: player.boostVoices)
            }
            .buttonStyle(.key)
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
                sleepFace
            }
            .accessibilityLabel(player.sleepTimer == nil ? "Sleep timer" : "Sleep timer on")
        }
    }

    private func modeLabel(_ title: String, value: String, lit: Bool) -> some View {
        VStack(spacing: 6) {
            LED(on: lit, color: Theme.accentFill)
            Text(title).font(Theme.mono(12, .bold))
            Text(value).font(Theme.mono(10)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
    }

    /// A mode label on a key face (for menus).
    private func modeFace(_ title: String, value: String, lit: Bool) -> some View {
        modeLabel(title, value: value, lit: lit)
            .foregroundStyle(Theme.ink)
            .background(keyFace)
    }

    @ViewBuilder private var sleepFace: some View {
        if let ends = player.sleepEndsAt {
            let now = Date()
            VStack(spacing: 6) {
                LED(on: true, color: Theme.accentFill)
                Text("SLEEP").font(Theme.mono(12, .bold))
                Text(timerInterval: now...max(ends, now), countsDown: true)
                    .font(Theme.mono(10))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .foregroundStyle(Theme.ink)
            .background(keyFace)
        } else {
            modeFace("SLEEP", value: player.sleepTimer == .endOfEpisode ? "EP END" : "OFF", lit: player.sleepTimer != nil)
        }
    }

    /// Transcript, chapters and where the sound is going.
    private var bottomKeys: some View {
        HStack(spacing: 8) {
            Button {
                transcriptEpisode = player.nowPlaying.flatMap { store.episode($0.episodeID) }
            } label: {
                Text("TRANSCRIPT").font(Theme.mono(12, .bold)).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.key)
            Button { showingChapters = true } label: {
                Text("CHAPTERS").font(Theme.mono(12, .bold)).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.key)
            RoutePicker(tint: UIColor(Theme.ink))
                .frame(width: 56, height: 48)
                .background(keyFace)
                .accessibilityLabel(player.outputName.map { "Playing on \($0). Choose another device" } ?? "Play on another device")
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
