import SwiftUI
import PodcastCore

/// Deck's full-screen player (Paul, 14 Nov 2026; prototype
/// design/deck/poddeck-prototype.html, `renderPlayer`). The whole screen
/// is a gradient from the show's artwork colour to its dark shade to near
/// black, all text white. Top: ⌄ close (or swipe down), "UP NEXT · n" (or
/// "PLAYING ON …"), ⋯ for the episode page. Then the big rounded artwork
/// (tap it for Read along: it shrinks beside the title and the words fill
/// the space), the show (tap for its page) and the title. At the bottom:
/// the chapter pill "‹ 4/6 · title ›" with Skip ad beside it during an
/// ad, the progress line, elapsed / ends / left, skip · play · skip, and
/// Options · Read along · Chapters · AirPlay.
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
    @State private var reading = false
    @State private var showingOptions = false
    @State private var showingChapters = false
    @State private var showingNotes = false
    /// How far a swipe down has pulled the player (it closes past 110).
    @State private var pull: CGFloat = 0
    @Namespace private var art

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

    /// Room left for the artwork once everything else has its place.
    private func artworkSide(_ size: CGSize, volume: Bool) -> CGFloat {
        let fixed: CGFloat = 44 + 92 + 44 + 62 + 96 + 64 + (volume ? 34 : 0) + 40
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
    private var closeSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { (value: DragGesture.Value) in
                let down: CGFloat = value.translation.height
                pull = down > 0 && abs(down) > abs(value.translation.width) ? down : 0
            }
            .onEnded { (value: DragGesture.Value) in
                if value.translation.height > 110 || value.predictedEndTranslation.height > 260 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { pull = 0 }
                }
            }
    }

    // MARK: Artwork and title

    private func artworkImage(_ item: PlayerModel.NowPlaying, radius: CGFloat) -> some View {
        Color.clear
            .overlay {
                CachedImage(url: item.artworkURL) { Theme.placeholderColor(for: item.showTitle) }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .matchedGeometryEffect(id: "artwork", in: art)
            .accessibilityHidden(true)
    }

    private func setReading(_ on: Bool) {
        withAnimation(reduceMotion ? nil : Self.morph) { reading = on }
    }

    private func listenTop(_ item: PlayerModel.NowPlaying, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 8)
            Button { setReading(true) } label: {
                artworkImage(item, radius: 28)
                    .frame(width: side, height: side)
                    .shadow(color: Color.black.opacity(0.35), radius: 30, y: 24)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Artwork")
            .accessibilityHint("Shows the words as they're said")
            Spacer(minLength: 12)
            titleBlock(item)
                .padding(.horizontal, 24)
            Spacer(minLength: 8)
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
            .transition(AnyTransition.opacity.combined(with: .offset(y: 40)))
        }
    }

    private func readingHeader(_ item: PlayerModel.NowPlaying) -> some View {
        HStack(spacing: 12) {
            Button { setReading(false) } label: {
                artworkImage(item, radius: 13)
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
                .padding(.bottom, 10)
            DeckPlayerScrub()
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
    }

    private var bottomRow: some View {
        HStack(spacing: 0) {
            DeckPlayerButton(icon: "slider.horizontal.3", label: optionsLabel, on: optionsOn) { showingOptions = true }
            DeckPlayerButton(icon: "text.quote", label: "Read along", on: reading) { setReading(!reading) }
            DeckPlayerButton(icon: "list.bullet", label: "Chapters", on: false) { showingChapters = true }
                .disabled(player.chapters.isEmpty)
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
