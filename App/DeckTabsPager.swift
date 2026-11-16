import SwiftUI
import SwiftData
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): an open tab, full screen,
// like a web page in Safari. Swipe sideways between the group's tabs. Each
// is the episode in its show's colour with a big ring showing how far
// through, Play / Pause and a few keys. Safari's bar at the bottom: ‹ title
// › and the tab count; swipe along it for the next tab, up (or tap the
// count) for the overview. Pull the page down to close it too.

struct DeckTabsPager: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""
    /// Opens the player once this pager has closed.
    let openPlayer: () -> Void

    @State private var current: String?
    @State private var notes: PodcastEpisode?

    var body: some View {
        let tabs: [PodcastEpisode] = DeckTabSource.tabs(model.group, store: store, player: player,
                                                        unplayed: unplayed, triaged: triaged, saved: savedRaw)
        let ids: [String] = tabs.map(\.episodeID)
        ZStack(alignment: .bottom) {
            backdrop(tabs)
            pages(tabs)
            VStack(spacing: 10) {
                UndoBar()
                    .padding(.horizontal, 4)
                DeckTabsPagerBar(tabs: tabs, current: current, step: { step(by: $0, ids: ids) }, close: close)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        // Smoother pull down (Paul, 16 Nov 2026): how far it's pulled lives
        // in its own modifier, so following the finger doesn't work out the
        // tabs (a fetch) and redraw every page on each frame.
        .modifier(DeckPagerPullDown(close: close))
        .onAppear {
            current = model.start ?? ids.first
            if let id = current { prepareColour(tabs.first { $0.episodeID == id }) }
        }
        .onChange(of: ids) { old, new in idsChanged(old: old, new: new) }
        .onChange(of: model.start) { _, start in
            if let start, ids.contains(start) { current = start }
        }
        .sheet(item: $notes) { episode in EpisodeNotesView(episode: episode) }
    }

    private func pages(_ tabs: [PodcastEpisode]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.episodeID) { index, episode in
                    DeckTabPage(episode: episode, index: index, count: tabs.count,
                                close: close, notes: { notes = $0 }, openPlayer: openPlayerNow)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(episode.episodeID)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
    }

    /// The current tab's show colour behind every page, changing as you
    /// settle on another tab.
    private func backdrop(_ tabs: [PodcastEpisode]) -> some View {
        let episode: PodcastEpisode? = tabs.first { $0.episodeID == current }
        var colour: Color = DeckPlayerView.bottomColour
        if let episode {
            colour = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.showTitle)
        }
        return DeckPlayerBackground(colour: colour)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: current)
    }

    // MARK: Moving between tabs

    private func step(by delta: Int, ids: [String]) {
        guard !ids.isEmpty else { return }
        let at: Int = current.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next: Int = min(ids.count - 1, max(0, at + delta))
        guard next != at else { return }
        withAnimation(.snappy(duration: 0.3)) { current = ids[next] }
    }

    /// A tab closed (marked played, removed): show the one now in its
    /// place, or go back to the overview when none are left.
    private func idsChanged(old: [String], new: [String]) {
        guard let id = current, !new.contains(id) else { return }
        guard !new.isEmpty else {
            close()
            return
        }
        let at: Int = old.firstIndex(of: id) ?? 0
        current = new[min(at, new.count - 1)]
    }

    private func close() {
        withAnimation(.spring(duration: 0.35)) { model.pagerOpen = false }
    }

    /// The player is a cover of the root view: close this one first.
    private func openPlayerNow() {
        model.pagerOpen = false
        let open: () -> Void = openPlayer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open() }
    }

    private func prepareColour(_ episode: PodcastEpisode?) {
        guard let url = episode?.artwork else { return }
        Task { await ArtworkColors.shared.load(url) }
    }
}

/// Pull a tab down to go back to the overview (like Safari's swipe down on
/// a tab): the page follows the finger and shrinks a little.
private struct DeckPagerPullDown: ViewModifier {
    let close: () -> Void
    /// How far the page is pulled down.
    @State private var pull: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: pull)
            .scaleEffect(1 - min(0.08, pull / 3000))
            .simultaneousGesture(pullDown)
    }

    private var pullDown: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged { (value: DragGesture.Value) in
                let dy: CGFloat = value.translation.height
                let dx: CGFloat = value.translation.width
                guard dy > 0, dy > abs(dx) * 1.3 || pull > 0 else { return }
                pull = dy
            }
            .onEnded { (value: DragGesture.Value) in
                guard pull > 0 else { return }
                let flick: Bool = value.predictedEndTranslation.height > 260
                if pull > 110 || flick {
                    close()
                    pull = 0
                } else {
                    withAnimation(.spring(duration: 0.3)) { pull = 0 }
                }
            }
    }
}

// MARK: - One tab

private struct DeckTabPage: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    let index: Int
    let count: Int
    let close: () -> Void
    let notes: (PodcastEpisode) -> Void
    let openPlayer: () -> Void

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }
    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        GeometryReader { geometry in
            let ring: CGFloat = min(geometry.size.width - 96, geometry.size.height * 0.36, 300)
            VStack(spacing: 0) {
                top
                Spacer(minLength: 12)
                Button {
                    if isOn { openPlayer() } else { actions.playNow(episode) }
                } label: {
                    DeckTabPageRing(episode: episode, size: max(120, ring))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOn ? "Open the player" : "Play " + episode.title)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 12)
                words
                transport
                    .padding(.top, 18)
                keys
                    .padding(.top, 18)
                Spacer(minLength: 0)
                    .frame(height: 140)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundStyle(Color.white)
        .task(id: episode.episodeID) { await ArtworkColors.shared.load(episode.artwork) }
    }

    private var top: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to the tabs")
            Spacer()
            Text("TAB \(index + 1) OF \(count)")
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .monospacedDigit()
                .opacity(0.75)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(episode.showTitle)
                .font(Theme.outfit(14, .semibold))
                .opacity(0.8)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(22, .heavy))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Text(detail)
                .font(Theme.outfit(13, .medium))
                .monospacedDigit()
                .opacity(0.7)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transport: some View {
        HStack(spacing: 14) {
            Button { actions.playNow(episode) } label: {
                Image(systemName: isOn && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOn && player.isPlaying ? "Pause" : "Play")
            if isOn {
                Button(action: openPlayer) {
                    Text("Open player")
                        .font(Theme.outfit(15, .bold))
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var keys: some View {
        HStack(spacing: 10) {
            key("Play next", icon: "text.line.first.and.arrowtriangle.forward") { actions.playNext(episode) }
            key("Notes", icon: "doc.text") { notes(episode) }
            key("Played", icon: "checkmark") { actions.close(episode) }
        }
    }

    private func key(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(Theme.outfit(12, .bold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.14)))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "Played" && model.group == .saved ? "Remove from Saved" : title)
    }

    /// "9 Nov · 52m", "9 Nov · 12m left".
    private var detail: String {
        let date: String = episode.published.formatted(.dateTime.day().month(.abbreviated))
        guard let duration = episode.duration, duration > 0 else { return date }
        let left: TimeInterval = episode.timeLeft ?? duration
        if isOn || (episode.position > 30 && left > 0) {
            return date + " · " + DeckUpNextTime.length(left) + " left"
        }
        return date + " · " + DeckUpNextTime.length(duration)
    }
}

/// The big ring round the artwork. The episode playing follows the
/// player's clock (only this view does); others show their saved place.
private struct DeckTabPageRing: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let size: CGFloat

    var body: some View {
        DeckRingArtwork(url: episode.artwork, showTitle: episode.showTitle, size: size,
                        progress: progress, lineWidth: 6, gap: 6,
                        colour: Color.white, track: Color.white.opacity(0.22))
            .shadow(color: Color.black.opacity(0.25), radius: 20, y: 12)
    }

    private var progress: Double {
        if player.nowPlaying?.episodeID == episode.episodeID, player.duration > 0 {
            return min(1, max(0, player.currentTime / player.duration))
        }
        return DeckRing.progress(of: episode)
    }
}

// MARK: - Safari's bar

private struct DeckTabsPagerBar: View {
    let tabs: [PodcastEpisode]
    let current: String?
    let step: (Int) -> Void
    let close: () -> Void

    var body: some View {
        let at: Int = current.flatMap { id in tabs.firstIndex { $0.episodeID == id } } ?? 0
        let episode: PodcastEpisode? = tabs.indices.contains(at) ? tabs[at] : nil
        HStack(spacing: 4) {
            arrow("chevron.left", label: "Previous tab", enabled: at > 0) { step(-1) }
            VStack(spacing: 1) {
                Text(episode?.title ?? "")
                    .font(Theme.outfit(13, .bold))
                    .lineLimit(1)
                Text(episode?.showTitle ?? "")
                    .font(Theme.outfit(11, .medium))
                    .foregroundStyle(Color(hex: 0x6B675F))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            arrow("chevron.right", label: "Next tab", enabled: at < tabs.count - 1) { step(1) }
            Button(action: close) {
                DeckTabCountSquare(count: tabs.count, colour: Color(hex: 0x1C1B1A))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs, \(tabs.count) open")
            .accessibilityHint("Back to the tab overview")
        }
        .foregroundStyle(Color(hex: 0x1C1B1A))
        .padding(.horizontal, 6)
        .frame(height: DeckTabsBar.height)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .highPriorityGesture(DeckBarSwipe.gesture.onEnded { value in swiped(value) })
    }

    private func swiped(_ value: DragGesture.Value) {
        guard let swipe = DeckBarSwipe.resolve(value) else { return }
        switch swipe {
        case .up: close()
        case .next: step(1)
        case .previous: step(-1)
        }
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}
