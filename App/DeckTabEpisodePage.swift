import SwiftUI
import PodcastCore

// One tab = player + episode page + show settings (Paul, 16 Nov 2026:
// "when you tap through on a card can it open the episode in a player mode
// with all the standard player interface and the show settings folded in …
// so we don't have a separate player and episode screen, they're all the
// same tab"; mock-up https://claude.ai/artifact/BRGBBkaHhpuDnarzHTxBPS).
// In tabs mode an open tab is one scrolling page for its episode:
// - the player at the top, on the show's colour: the dial, chapter row,
//   times, transport, Options · Read along · Chapters · AirPlay. A tab that
//   isn't the one playing has the same layout at rest (its saved place on
//   the ring) with a big Play; pressing it makes it the playing episode and
//   the page goes live;
// - then the episode (place in Up next, download, transcript, played, save
//   for later, Go to show, notes) on the app's own page colour. The show's
//   settings live on its show page (Paul, 16 Nov 2026: "drop all the 'This
//   show' details from the episode player card").
// Scrolled down past the player, a slim bar at the top keeps play / pause
// and the time. Pull down from the top of the page for the overview
// (DeckPullDown); swipe sideways on the page for the next / previous tab
// (DeckTabsPager, which no longer has Safari's bar). Card deck mode keeps
// DeckPlayerView and DeckEpisodePage.

struct DeckTabEpisodePage: View {
    let episode: PodcastEpisode
    let index: Int
    let count: Int
    /// The screen's safe area (the pager lays the pages out edge to edge,
    /// so the colour runs up behind the status bar; the controls start
    /// below it: Paul, 16 Nov 2026, "the top of the player screen is being
    /// lost under the dynamic island").
    let insets: EdgeInsets
    let close: () -> Void
    /// A pull down from the top of the page (the pager moves and closes it).
    let pulled: (DeckPullEvent) -> Void

    @State private var reading = false
    @State private var scrolledPast = false
    @State private var position = ScrollPosition(edge: .top)
    /// Where a pull down may not start (in the scroll content), by name.
    @State private var keepOut: [String: CGRect] = [:]

    private var colour: Color {
        ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.showTitle)
    }

    var body: some View {
        GeometryReader { (geometry: GeometryProxy) in
            // Only what the page doesn't already get from iOS.
            let top: CGFloat = max(0, insets.top - geometry.safeAreaInsets.top)
            let bottom: CGFloat = max(0, insets.bottom - geometry.safeAreaInsets.bottom)
            let visible: CGFloat = geometry.size.height - top - bottom
            let playerHeight: CGFloat = max(480, visible)
            scroller(width: geometry.size.width, playerHeight: playerHeight, top: top, bottom: bottom)
        }
        .task(id: episode.episodeID) { await ArtworkColors.shared.load(episode.artwork) }
    }

    private func scroller(width: CGFloat, playerHeight: CGFloat, top: CGFloat, bottom: CGFloat) -> some View {
        let threshold: CGFloat = playerHeight - 140
        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                DeckTabPlayerSection(episode: episode, index: index, count: count, colour: colour,
                                     width: width, height: playerHeight, reading: $reading,
                                     keepOut: $keepOut, close: close)
                    .frame(height: playerHeight)
                    .padding(.top, top)
                    .contentShape(Rectangle())
                    .gesture(DeckPullDown(keepOut: pullKeepOut, handle: pulled))
                DeckTabEpisodeBelow(episode: episode, bottomRoom: bottom + 24, close: close, readAlong: readAlong)
            }
            .coordinateSpace(.named(DeckPullDown.space))
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self, of: { (geometry: ScrollGeometry) -> Bool in
            geometry.contentOffset.y + geometry.contentInsets.top > threshold
        }, action: { (_: Bool, past: Bool) in
            withAnimation(.easeOut(duration: 0.2)) { scrolledPast = past }
        })
        .overlay(alignment: .top) { slimBar(top: top) }
    }

    @ViewBuilder private func slimBar(top: CGFloat) -> some View {
        if scrolledPast {
            DeckTabSlimBar(episode: episode, colour: colour, tap: scrollToTop)
                .padding(.horizontal, 12)
                .padding(.top, top + 4)
                .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Only the places that are on screen in this mode: a dial or scrub
    /// line left over from the other mode (its rect can outlive it while
    /// the two cross-fade) would otherwise block the read-along header.
    private var pullKeepOut: [CGRect] {
        let skip: String = reading ? "dial" : "scrub"
        return keepOut.filter { $0.key != skip }.map { $0.value }
    }

    private func scrollToTop() {
        withAnimation(.smooth(duration: 0.4)) { position.scrollTo(edge: .top) }
    }

    /// From the transcript row below: back up to the player, words showing.
    private func readAlong() {
        scrollToTop()
        withAnimation(DeckPlayerView.morph) { reading = true }
    }
}

/// Closing the tab page before going somewhere else in the app (the page is
/// a cover over everything, like the old player).
@MainActor
enum DeckTabNavigation {
    static func openShow(_ show: Podcast, store: LibraryStore, model: DeckTabsModel) {
        model.pagerOpen = false
        // RootView switches to Shows and pushes the show once the page has gone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { store.revealShow = show }
    }
}

// MARK: - The player part

/// The top of a tab's page: the Deck player's pieces, live for the episode
/// playing, at rest (saved place, big Play) for any other.
private struct DeckTabPlayerSection: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let episode: PodcastEpisode
    let index: Int
    let count: Int
    let colour: Color
    let width: CGFloat
    let height: CGFloat
    @Binding var reading: Bool
    /// The dial showing the words (shared with DeckPlayerDial).
    @AppStorage("deckDialWords") private var dialWords = false
    /// Where a pull down may not start (in the page's scroll content), by
    /// name: the live dial, the read-along scrub line, the volume.
    @Binding var keepOut: [String: CGRect]
    let close: () -> Void

    @State private var showingOptions = false
    @State private var showingChapters = false
    @State private var showingMore = false
    /// Where a drag round the dial has got to (the dial and the times row).
    @State private var dialScrub = DeckDialScrub()

    private var live: PlayerModel.NowPlaying? {
        guard let now = player.nowPlaying, now.episodeID == episode.episodeID else { return nil }
        return now
    }

    private var volume: Bool { height > 700 }

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }

    var body: some View {
        let now: PlayerModel.NowPlaying? = live
        VStack(spacing: 0) {
            DeckTabTopRow(episode: episode, index: index, count: count, live: now != nil,
                          close: close, more: { showingMore = true })
            middle(now)
            controls(now)
        }
        .padding(.bottom, 8)
        .frame(width: width, height: height)
        .foregroundStyle(Color.white)
        .tint(Color.white)
        .sheet(isPresented: $showingOptions) {
            PlayerOptionsSheet().normalColours()
        }
        .sheet(isPresented: $showingChapters) {
            DeckPlayerChaptersSheet().normalColours()
        }
        .sheet(isPresented: $showingMore) {
            DeckTabMoreSheet(episode: episode, live: now != nil)
        }
    }

    // MARK: Middle

    @ViewBuilder private func middle(_ now: PlayerModel.NowPlaying?) -> some View {
        if reading {
            readingTop
        } else {
            listenTop(now)
        }
    }

    /// Room left for the dial once everything else has its place (the
    /// times row is 26 pt with its bigger numbers).
    private var side: CGFloat {
        let fixed: CGFloat = 44 + 92 + 38 + DeckDialTimes.height + 86 + 68 + (volume ? 34 : 0) + 40
        return max(120, min(width - 72, height - fixed))
    }

    /// Spare height goes above the dial; the title sits close over the
    /// chapter row and times (Paul, 16 Nov 2026: the gap between the title
    /// and the times was "an empty no man's land").
    private func listenTop(_ now: PlayerModel.NowPlaying?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 8)
            dial(now)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 12)
                .frame(maxHeight: 22)
            titleBlock
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder private func dial(_ now: PlayerModel.NowPlaying?) -> some View {
        if let now {
            GeometryReader { (proxy: GeometryProxy) in
                DeckPlayerDial(item: now, episode: episode, rect: CGRect(origin: .zero, size: proxy.size),
                               colour: colour, scrub: dialScrub)
            }
            // The dial keeps its drags (scrubbing); a pull down can't start on it.
            .keepingOut("dial", in: $keepOut)
        } else {
            Button { actions.playNow(episode) } label: {
                DeckTabRestingDial(episode: episode, side: side)
            }
            .buttonStyle(.plain)
            .onAppear { keepOut["dial"] = nil }
            .accessibilityLabel("Play " + episode.title)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            showButton(size: 14)
            Text(episode.title)
                .font(Theme.outfit(episode.title.count > 60 ? 21 : 25, .heavy))
                .tracking(-0.6)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showButton(size: CGFloat) -> some View {
        Button(action: openShow) {
            Text(episode.showTitle)
                .font(Theme.outfit(size, .semibold))
                .lineLimit(1)
                .opacity(0.8)
        }
        .buttonStyle(.plain)
        .disabled(episode.podcast == nil)
        .accessibilityHint("Opens the show")
    }

    private func openShow() {
        guard let show = episode.podcast else { return }
        DeckTabNavigation.openShow(show, store: store, model: model)
    }

    private var readingTop: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { setReading(false) } label: {
                    DeckTabRing(episode: episode, size: 56, lineWidth: 3, gap: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show artwork")
                VStack(alignment: .leading, spacing: 1) {
                    Text(episode.title)
                        .font(Theme.outfit(16, .heavy))
                        .lineLimit(2)
                    showButton(size: 13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 4)
            DeckReadAlong(episode: episode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The words scroll; a pull down starts on them only when
                // they're scrolled to their top (`DeckPullDown`), and always
                // from the rows above them.
                .transition(AnyTransition.opacity.combined(with: .offset(y: 40)))
        }
    }

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
        withAnimation(reduceMotion ? nil : DeckPlayerView.morph) { reading = on }
    }

    // MARK: Controls

    private func controls(_ now: PlayerModel.NowPlaying?) -> some View {
        VStack(spacing: 0) {
            chapterRow(now)
                .padding(.bottom, 6)
            times(now)
            transport(now)
                .padding(.top, 10)
            if volume {
                DeckPlayerVolume()
                    .keepingOut("volume", in: $keepOut)
                    .padding(.top, 6)
            }
            bottomRow(now)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder private func chapterRow(_ now: PlayerModel.NowPlaying?) -> some View {
        if now != nil {
            DeckChapterRow(openChapters: { showingChapters = true })
        } else {
            Color.clear.frame(height: 32)
        }
    }

    @ViewBuilder private func times(_ now: PlayerModel.NowPlaying?) -> some View {
        if now == nil {
            DeckTabRestingTimes(episode: episode)
        } else {
            // One times row that shrinks under the line in Read along
            // (smooth, like the chapter pill) rather than two rows swapped.
            VStack(spacing: 2) {
                if reading {
                    DeckPlayerScrub(shared: dialScrub)
                        .keepingOut("scrub", in: $keepOut)
                        .transition(.opacity)
                }
                DeckDialTimes(scrub: dialScrub, compact: reading)
            }
        }
    }

    @ViewBuilder private func transport(_ now: PlayerModel.NowPlaying?) -> some View {
        if now != nil {
            DeckPlayerTransport()
        } else {
            DeckTabRestingTransport(play: { actions.playNow(episode) })
        }
    }

    private func bottomRow(_ now: PlayerModel.NowPlaying?) -> some View {
        HStack(spacing: 0) {
            DeckPlayerButton(icon: "slider.horizontal.3", label: optionsLabel, on: optionsOn) { showingOptions = true }
            DeckPlayerButton(icon: "text.quote", label: "Read along", on: reading || dialWords) { readAlongTapped() }
            DeckPlayerButton(icon: "list.bullet", label: "Chapters", on: false) { showingChapters = true }
                .disabled(now == nil || player.chapters.isEmpty)
            DeckAirPlayButton()
        }
        .padding(.horizontal, -6)
    }

    private var optionsOn: Bool {
        player.speed != 1 || player.trimSilences || player.boostVoices || player.sleepTimer != nil
    }

    /// "1.2× · Trim" when anything is on, else "Options" (as the player).
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

/// ⌄ (back to the tabs), where this tab stands ("PLAYING NOW", "2ND IN UP
/// NEXT", "TAB 3 OF 7") and ⋯ for a few more things to do.
private struct DeckTabTopRow: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    let index: Int
    let count: Int
    let live: Bool
    let close: () -> Void
    let more: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: close) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to the tabs")
            Spacer(minLength: 4)
            Text(label)
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .monospacedDigit()
                .lineLimit(1)
                .opacity(0.75)
            Spacer(minLength: 4)
            menu
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var label: String {
        if live {
            if let device = player.outputName { return "PLAYING ON " + device.uppercased() }
            return "PLAYING NOW"
        }
        if let place = DeckTabPlace.place(of: episode, store: store, player: player) {
            return DeckTabPlace.words(place).uppercased()
        }
        return "TAB \(index + 1) OF \(count)"
    }

    /// ⋯ opens a short sheet in the app's own colours (Paul, 16 Nov 2026:
    /// iOS's menu over the show's colour came out with "a kind of purple
    /// tint which is off from the rest of the app").
    private var menu: some View {
        Button(action: more) {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }
}

/// Where an episode stands in Up next, after the one playing (the tab
/// cards' numbers: 1 is next).
@MainActor
enum DeckTabPlace {
    static func place(of episode: PodcastEpisode, store: LibraryStore, player: PlayerModel) -> Int? {
        let playing: String? = player.nowPlaying?.episodeID
        let ids: [String] = store.queue.map(\.episode.id).filter { $0 != playing }
        return ids.firstIndex(of: episode.episodeID).map { $0 + 1 }
    }

    /// "Next in Up next", "2nd in Up next".
    static func words(_ place: Int) -> String {
        place == 1 ? "Next in Up next" : EpisodeStatusRows.ordinal(place) + " in Up next"
    }
}

// MARK: - At rest (a tab that isn't playing)

/// The dial at rest: round artwork in the white ring at the saved place.
private struct DeckTabRestingDial: View {
    let episode: PodcastEpisode
    let side: CGFloat

    var body: some View {
        let geometry = DeckDialGeometry(side: side)
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: side,
                        progress: DeckRing.progress(of: episode), lineWidth: geometry.lineWidth,
                        gap: geometry.gap, colour: Color.white, track: Color.white.opacity(0.2))
            .shadow(color: Color.black.opacity(0.3), radius: 24, y: 16)
            .contentShape(Circle())
    }
}

/// The saved place, "34m left" and the length, where the live times sit.
private struct DeckTabRestingTimes: View {
    let episode: PodcastEpisode

    var body: some View {
        let duration: TimeInterval = episode.duration ?? 0
        let at: TimeInterval = episode.played ? 0 : min(episode.position, duration > 0 ? duration : episode.position)
        let left: TimeInterval = max(0, duration - at)
        return HStack(spacing: 4) {
            Text(TimeFormat.clock(at))
                .font(DeckDialTimes.clockFont)
                .frame(minWidth: 72, alignment: .leading)
            Spacer(minLength: 0)
            Text(middle(at: at, left: left))
                .font(DeckDialTimes.middleFont)
                .lineLimit(1)
                .opacity(0.75)
            Spacer(minLength: 0)
            Text(duration > 0 ? "−" + TimeFormat.clock(left) : "")
                .font(DeckDialTimes.clockFont)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(height: DeckDialTimes.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(middle(at: at, left: left))
    }

    private func middle(at: TimeInterval, left: TimeInterval) -> String {
        guard let duration = episode.duration, duration > 0 else { return "Not started" }
        if at > 30 { return TimeFormat.length(left) + " left" }
        return TimeFormat.length(duration)
    }
}

/// The skips (dim: they'd move the episode that's on) and a big white Play.
private struct DeckTabRestingTransport: View {
    @Environment(PlayerModel.self) private var player
    let play: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            skip("gobackward.\(player.skipBackSeconds)")
            Button(action: play) {
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(DeckPlayerColours.ink)
                    .offset(x: 2)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play")
            skip("goforward.\(player.skipForwardSeconds)")
        }
        .frame(maxWidth: .infinity)
    }

    private func skip(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 30))
            .frame(width: 56, height: 56)
            .opacity(0.3)
            .accessibilityHidden(true)
    }
}

/// Round artwork in a ring: live for the episode playing (only this small
/// view follows the clock), the saved place otherwise.
struct DeckTabRing: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let size: CGFloat
    var lineWidth: CGFloat = 4
    var gap: CGFloat = 4

    var body: some View {
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: size,
                        progress: progress, lineWidth: lineWidth, gap: gap,
                        colour: Color.white, track: Color.white.opacity(0.22))
    }

    private var progress: Double {
        if player.nowPlaying?.episodeID == episode.episodeID, player.duration > 0 {
            return min(1, max(0, player.currentTime / player.duration))
        }
        return DeckRing.progress(of: episode)
    }
}

// MARK: - ⋯ sheet

/// The tab page's ⋯: a short sheet on the app's warm page with white card
/// rows, ink words and icons (Paul, 16 Nov 2026: iOS's menu over the show's
/// colour had "a kind of purple tint"). Sized to what's in it; Done or
/// swipe down.
private struct DeckTabMoreSheet: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    @Environment(DeckTabsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let episode: PodcastEpisode
    let live: Bool

    @State private var height: CGFloat = 260

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            DeckSetCard { rows }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Theme.background)
    }

    private var header: some View {
        ZStack {
            Text(episode.title)
                .font(Theme.outfit(15, .bold))
                .lineLimit(1)
                .padding(.horizontal, 64)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.outfit(16, .semibold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
    }

    @ViewBuilder private var rows: some View {
        let queued: Bool = actions.isQueued(episode)
        if !live {
            row(icon: "text.line.first.and.arrowtriangle.forward", title: "Play next") {
                actions.playNext(episode)
            }
            DeckSetLine()
        }
        if queued && !live {
            row(icon: "minus.circle", title: "Remove from Up next") {
                actions.removeFromUpNext(episode)
            }
            DeckSetLine()
        }
        row(icon: "square.stack", title: "Open show") { openShow() }
            .disabled(episode.podcast == nil)
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            DeckSetRowLabel(icon: icon, title: title, chevron: nil)
        }
        .buttonStyle(.plain)
    }

    /// The sheet goes first, then the tab page, then Shows opens the show.
    private func openShow() {
        guard let show = episode.podcast else { return }
        // Read now: the sheet's environment is gone once it has closed.
        let library: LibraryStore = store
        let tabs: DeckTabsModel = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            DeckTabNavigation.openShow(show, store: library, model: tabs)
        }
    }
}

private extension View {
    /// Reports this view's place in the page under `name` while it's shown,
    /// so a pull down to close never starts on it (it keeps its own drags).
    func keepingOut(_ name: String, in places: Binding<[String: CGRect]>) -> some View {
        self
            .onGeometryChange(for: CGRect.self) { (proxy: GeometryProxy) -> CGRect in
                proxy.frame(in: .named(DeckPullDown.space))
            } action: { (rect: CGRect) in
                places.wrappedValue[name] = rect
            }
            .onDisappear { places.wrappedValue[name] = nil }
    }
}
