import SwiftUI
import PodcastCore

/// Deck's full-screen player (Paul, 14 Nov 2026; prototype
/// design/deck/poddeck-prototype.html, `renderPlayer`). The whole screen
/// is a gradient from the show's artwork colour to its dark shade to near
/// black, all text white. Top: ⌄ close (or swipe down), "UP NEXT · n" (or
/// "PLAYING ON …"), ⋯ for the episode page. Then the dial (Paul, 15 Nov
/// 2026: dial; DeckPlayerDial.swift): round artwork in a progress ring you
/// drag round to scrub, tap it to turn it over to the words; the show (tap
/// for its page) and the title. At the bottom: the chapter pill
/// "‹ 4/6 · title ›" with Skip ad beside it during an ad, elapsed / ends /
/// left, skip · play · skip, and Options · Read along · AirPlay (chapters from the chapter row).
/// Read along (its button) slides the dial into the corner as a small
/// ringed circle and the words fill the space; there the straight
/// progress line comes back, as the dial isn't on screen.
/// Built in small pieces (DeckPlayerParts.swift, DeckPlayerReadAlong.swift,
/// DeckPlayerChapters.swift) so GitHub's check compiles it quickly.
struct DeckPlayerView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed when the player opens or the episode changes (Paul: nothing
    /// changes colour while you look at it); neutral until it's measured.
    @State private var colour: Color?
    @State private var episode: PodcastEpisode?
    /// The dial showing the words (shared with DeckPlayerDial).
    @AppStorage("deckDialWords") private var dialWords = false
    @State private var reading = false
    @State private var showingOptions = false
    @State private var showingChapters = false
    @State private var showingNotes = false
    /// How far a swipe down has pulled the player (it closes past 60, or a
    /// light flick: Paul, 14 Nov 2026, "too much effort to drag down").
    @State private var pull: CGFloat = 0
    /// Where a drag round the dial has got to (the dial and the times row).
    @State private var dialScrub = DeckDialScrub()

    static let neutral = Color(hex: 0x3A3833)
    static let bottomColour = Color(hex: 0x17161A)
    static let morph: Animation = .smooth(duration: 0.4)

    var body: some View {
        Group {
            if let item = player.nowPlaying {
                GeometryReader { geometry in
                    page(item, size: geometry.size)
                }
                .task(id: item.artworkURL) { await measure(item.artworkURL) }
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .offset(y: pull)
        .background { DeckPlayerBackground(colour: colour ?? Self.neutral).ignoresSafeArea() }
        .foregroundStyle(Color.white)
        .tint(Color.white)
        // Dark status text would be lost on the colour.
        .statusBarHidden(true)
        .overlay(alignment: .bottom) { undo }
        .onChange(of: player.nowPlaying?.episodeID, initial: true) { _, id in
            episodeChanged(id)
        }
        .sheet(isPresented: $showingOptions) {
            PlayerOptionsSheet().normalColours()
        }
        .sheet(isPresented: $showingChapters) {
            DeckPlayerChaptersSheet().normalColours()
        }
        .sheet(isPresented: $showingNotes) {
            if let episode { EpisodeNotesView(episode: episode).normalColours() }
        }
        .transcribeExplainer()
    }

    private var undo: some View {
        UndoBar()
            .padding(.horizontal, 12)
            .padding(.bottom, 96)
            .animation(.easeOut(duration: 0.2), value: store.undoAction?.id)
    }

    private func episodeChanged(_ id: String?) {
        episode = id.flatMap { store.episode($0) }
        colour = ArtworkColors.shared.background(for: player.nowPlaying?.artworkURL)
    }

    /// Measured just now (first time this artwork plays): fade in once.
    private func measure(_ url: URL?) async {
        await ArtworkColors.shared.load(url)
        if colour == nil, let measured = ArtworkColors.shared.background(for: url) {
            withAnimation(.easeInOut(duration: 0.4)) { colour = measured }
        }
    }

    // MARK: Layout

    private func page(_ item: PlayerModel.NowPlaying, size: CGSize) -> some View {
        let volume: Bool = size.height > 760
        return VStack(spacing: 0) {
            topRow
                .contentShape(Rectangle())
                .gesture(closeSwipe)
            middle(item, size: size, volume: volume)
            controls(volume: volume)
        }
        .padding(.bottom, 8)
        .frame(width: size.width, height: size.height)
        .overlayPreferenceValue(DeckArtworkSpot.self) { (spot: Anchor<CGRect>?) in
            GeometryReader { (proxy: GeometryProxy) in
                if let spot {
                    DeckPlayerDial(item: item, episode: episode, rect: proxy[spot],
                                   colour: colour ?? Self.neutral, scrub: dialScrub)
                }
            }
        }
    }

    @ViewBuilder private func middle(_ item: PlayerModel.NowPlaying, size: CGSize, volume: Bool) -> some View {
        if reading {
            readingTop(item)
        } else {
            listenTop(item, side: artworkSide(size, volume: volume))
                .contentShape(Rectangle())
                .simultaneousGesture(closeSwipe)
        }
    }

    /// Room left for the dial once everything else has its place (the
    /// times row is 26 pt with its bigger numbers).
    private func artworkSide(_ size: CGSize, volume: Bool) -> CGFloat {
        let fixed: CGFloat = 44 + 92 + 40 + DeckDialTimes.height + 8 + 96 + 64 + (volume ? 34 : 0) + 40
        let byHeight: CGFloat = size.height - fixed
        return max(120, min(size.width - 72, byHeight))
    }

    // MARK: Top row

    private var topRow: some View {
        HStack(spacing: 0) {
            iconButton("chevron.down", size: 26, label: "Close player") { dismiss() }
            Spacer(minLength: 4)
            Text(topLabel)
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .lineLimit(1)
                .opacity(0.75)
            Spacer(minLength: 4)
            iconButton("ellipsis", size: 22, label: "Episode details") { showingNotes = true }
                .disabled(episode == nil)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var topLabel: String {
        if let device = player.outputName {
            return "PLAYING ON " + device.uppercased()
        }
        let playingID: String? = player.nowPlaying?.episodeID
        let count: Int = store.queue.filter { $0.episode.id != playingID }.count
        return "UP NEXT · \(count)"
    }

    private func iconButton(_ icon: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Swipe down on the top part of the player to close it.
    /// Paul, 15 Nov 2026 (recording): the pull was janky and hit and miss.
    /// The finger is now measured against the screen, not the player that
    /// moves with it (each movement counted twice, so it juddered); once
    /// it's clearly going down it follows the finger; letting go past
    /// 60 pt or on a light flick slides the player away first and then
    /// closes it without iOS's own animation on top (which made it jump).
    /// Paul, 15 Nov 2026 (after build 157): still needed "a real motion".
    /// It starts after 4 pt and closes past 64 pt, on any downward flick
    /// (300 pt/s) or a predicted 120 pt (`DeckPullToClose`, the same as the
    /// tab page, Paul, 16 Nov 2026: "consistent"); the gaps round the
    /// controls take it too.
    private var closeSwipe: some Gesture {
        DragGesture(minimumDistance: DeckPullToClose.start, coordinateSpace: .global)
            .onChanged { (value: DragGesture.Value) in
                let down: CGFloat = value.translation.height
                let sideways: CGFloat = abs(value.translation.width)
                guard pull > 0 || (down > 0 && down > sideways) else { return }
                var still = Transaction(animation: nil)
                still.disablesAnimations = true
                withTransaction(still) { pull = max(0, down) }
            }
            .onEnded { (value: DragGesture.Value) in
                guard pull > 0 else { return }
                let shut: Bool = DeckPullToClose.closes(translation: value.translation.height,
                                                        velocity: value.velocity.height,
                                                        predicted: value.predictedEndTranslation.height)
                if shut {
                    slideAwayAndClose()
                } else {
                    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { pull = 0 }
                }
            }
    }

    private func slideAwayAndClose() {
        withAnimation(.easeOut(duration: 0.18)) { pull = 1200 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            var quiet = Transaction(animation: nil)
            quiet.disablesAnimations = true
            withTransaction(quiet) { dismiss() }
        }
    }

    // MARK: Artwork and title

    /// Where the artwork sits in this mode: an empty spot that reports its
    /// place. One picture is drawn over it (`DeckPlayerDial`).
    private func artworkSpot() -> some View {
        Color.clear
            .contentShape(Rectangle())
            .anchorPreference(key: DeckArtworkSpot.self, value: .bounds) { $0 }
    }

    // The one picture drawn over the spot is the dial (DeckPlayerDial):
    // it slides and resizes between the listening spot and Read along's
    // corner (Paul, 15 Nov 2026: shrinking and growing was "a little
    // unsmooth" as two copies cross-faded), round in both, with the ring
    // following it into the corner (Paul, 15 Nov 2026: dial).

    /// Read along steps through (Paul, 16 Nov 2026: the words key's
    /// behaviour on the existing button, no extra key): first tap turns the
    /// dial over to the line being said, the next opens the full words,
    /// the next goes back to the artwork. Tapping the dial still swaps
    /// artwork and words.
    private func readAlongTapped() {
        if reading {
            setReading(false)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { dialWords = false }
        } else if dialWords {
            setReading(true)
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { dialWords = true }
        }
    }

    private func setReading(_ on: Bool) {
        withAnimation(reduceMotion ? nil : Self.morph) { reading = on }
    }

    private func listenTop(_ item: PlayerModel.NowPlaying, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 8)
            // The dial takes its own touches (drawn over this spot); Read
            // along opens from its button only (Paul, 15 Nov 2026: dial).
            artworkSpot()
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            // Spare height goes above the dial; the title sits close over
            // the chapter row and times (Paul, 16 Nov 2026: the gap was "an
            // empty no man's land").
            Spacer(minLength: 12)
                .frame(maxHeight: 22)
            titleBlock(item)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }

    private func titleBlock(_ item: PlayerModel.NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            showButton(item, size: 14)
            Text(item.title)
                .font(Theme.outfit(item.title.count > 60 ? 21 : 25, .heavy))
                .tracking(-0.6)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showButton(_ item: PlayerModel.NowPlaying, size: CGFloat) -> some View {
        Button(action: openShow) {
            Text(item.showTitle)
                .font(Theme.outfit(size, .semibold))
                .lineLimit(1)
                .opacity(0.8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the show")
    }

    /// RootView closes the player and opens the show.
    private func openShow() {
        guard let show = episode?.podcast else { return }
        store.revealShow = show
        dismiss()
    }

    // MARK: Read along

    private func readingTop(_ item: PlayerModel.NowPlaying) -> some View {
        VStack(spacing: 0) {
            readingHeader(item)
                .contentShape(Rectangle())
                .simultaneousGesture(closeSwipe)
            Group {
                if let episode {
                    DeckReadAlong(episode: episode)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Pull down to close from the words too, when they're scrolled
            // to their top (Paul, 16 Nov 2026: "I can't pull down to close
            // when the transcript is open"); otherwise they scroll.
            .gesture(DeckPullDown(handle: pulledOnWords))
            .transition(AnyTransition.opacity.combined(with: .offset(y: 40)))
        }
    }

    /// The pull down that started on the read-along words.
    private func pulledOnWords(_ event: DeckPullEvent) {
        switch event {
        case .moved(let down):
            var still = Transaction(animation: nil)
            still.disablesAnimations = true
            withTransaction(still) { pull = down }
        case .ended(let close):
            if close {
                slideAwayAndClose()
            } else {
                withAnimation(.spring(duration: 0.3, bounce: 0.1)) { pull = 0 }
            }
        }
    }

    private func readingHeader(_ item: PlayerModel.NowPlaying) -> some View {
        HStack(spacing: 12) {
            Button { setReading(false) } label: {
                artworkSpot()
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show artwork")
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Theme.outfit(16, .heavy))
                    .lineLimit(2)
                showButton(item, size: 13)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: Controls

    private func controls(volume: Bool) -> some View {
        VStack(spacing: 0) {
            DeckChapterRow(openChapters: { showingChapters = true })
                .padding(.bottom, 6)
            // The dial replaces the straight line (Paul, 15 Nov 2026: dial);
            // in Read along the line comes back above the same times row,
            // which shrinks smoothly rather than swapping.
            VStack(spacing: 2) {
                if reading {
                    DeckPlayerScrub(shared: dialScrub)
                        .transition(.opacity)
                }
                DeckDialTimes(scrub: dialScrub, compact: reading)
            }
            DeckPlayerTransport()
                .padding(.top, 10)
            if volume {
                DeckPlayerVolume()
                    .padding(.top, 6)
            }
            bottomRow
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        // Not in Read along: its scrub line's drag slows down as the finger
        // goes lower, so a pull there must stay a scrub.
        .simultaneousGesture(closeSwipe, including: reading ? .subviews : .all)
    }

    private var bottomRow: some View {
        HStack(spacing: 0) {
            DeckPlayerButton(icon: "slider.horizontal.3", label: optionsLabel, on: optionsOn) { showingOptions = true }
            DeckPlayerButton(icon: "text.quote", label: "Read along", on: reading || dialWords) { readAlongTapped() }
            DeckAirPlayButton()
        }
        .padding(.horizontal, -6)
    }

    private var optionsOn: Bool {
        player.speed != 1 || player.trimSilences || player.boostVoices || player.sleepTimer != nil
    }

    /// "1.2× · Trim" when anything is on, else "Options".
    private var optionsLabel: String {
        var parts: [String] = []
        if player.speed != 1 {
            parts.append(player.speed.formatted(.number.precision(.fractionLength(0...2))) + "×")
        }
        if player.trimSilences { parts.append("Trim") }
        if player.boostVoices { parts.append("Boost") }
        if player.sleepTimer != nil { parts.append("Sleep") }
        return parts.isEmpty ? "Options" : parts.joined(separator: " · ")
    }
}

/// The player's backdrop: the show's colour at the top, its dark shade by
/// the middle, near black at the foot (the prototype's gradient).
struct DeckPlayerBackground: View {
    let colour: Color

    static func shade(_ colour: Color) -> Color {
        colour.mix(with: .black, by: 0.5)
    }

    var body: some View {
        LinearGradient(stops: [.init(color: colour, location: 0),
                               .init(color: Self.shade(colour), location: 0.46),
                               .init(color: DeckPlayerView.bottomColour, location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .accessibilityHidden(true)
    }
}

/// Where the player's artwork should be drawn (see `movingArtwork`).
private struct DeckArtworkSpot: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
