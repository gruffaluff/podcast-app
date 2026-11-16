import SwiftUI
import UIKit
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): the overview's grid of tab
// cards, two across, in the group's order. Tap a tab to open it full
// screen; × or a swipe left closes it (like Safari).
//
// Reorder (Paul, 16 Nov 2026, build 159 recording: the lifted tab dropped
// down on its own and it wasn't clear which tab it replaced): a hand-made
// drag like Safari / the home screen. In Up next, touch and hold a tab
// (0.35 s): it lifts where it is, a little bigger with a shadow, and
// follows the finger; the other tabs slide into their new places as it
// moves, and the numbers in their corners follow; let go and it settles
// into the gap and Up next takes the new order. Hold and let go without
// moving gives the tab's menu. A swipe that starts without the hold
// scrolls as usual. The episode playing stays first and can't move.

struct DeckTabsGrid: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let tabs: [PodcastEpisode]

    /// The tab being dragged, while it is.
    @State private var lift: DeckTabLift?
    /// The tab whose menu is showing (after a still hold).
    @State private var menuFor: String?
    @State private var notes: PodcastEpisode?
    @State private var width: CGFloat = 360
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""

    static let gap: CGFloat = 10

    private static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: DeckTabsGrid.gap),
        GridItem(.flexible(), spacing: DeckTabsGrid.gap),
    ]

    private var cardWidth: CGFloat { max(40, (width - Self.gap) / 2) }
    /// Every card the same height, so the slots can be worked out.
    private var cardHeight: CGFloat { (cardWidth * 1.25).rounded() }
    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }
    private var playingID: String? { player.nowPlaying?.episodeID }

    var body: some View {
        let shown: [PodcastEpisode] = displayed
        ZStack(alignment: .topLeading) {
            LazyVGrid(columns: Self.columns, spacing: Self.gap) {
                ForEach(shown, id: \.episodeID) { episode in
                    cell(episode, shown: shown)
                }
            }
            liftedCard(shown: shown)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { new in width = new }
        .sheet(item: $notes) { episode in EpisodeNotesView(episode: episode) }
        // Never leave the page unable to scroll if the grid goes mid-drag.
        .onDisappear { dropLift() }
        .onChange(of: model.group) { _, _ in dropLift() }
    }

    private func dropLift() {
        if lift != nil { lift = nil }
        if model.reordering { model.reordering = false }
    }

    // MARK: Cells

    private func canMove(_ episode: PodcastEpisode) -> Bool {
        model.group == .upNext && episode.episodeID != playingID
    }

    @ViewBuilder private func cell(_ episode: PodcastEpisode, shown: [PodcastEpisode]) -> some View {
        let movable: Bool = canMove(episode)
        let hidden: Bool = lift?.id == episode.episodeID
        ZStack {
            DeckTabCard(episode: episode, place: place(of: episode, in: shown), reorderable: movable,
                        hooks: movable ? hooks(for: episode) : nil)
                .opacity(hidden ? 0 : 1)
            if hidden {
                DeckTabGap()
            }
        }
        .frame(height: cardHeight)
        .gesture(DeckTabHold(isEnabled: movable && (lift == nil || hidden),
                             began: { began(episode.episodeID) },
                             changed: { moved($0) },
                             ended: { cancelled in ended(cancelled: cancelled) }))
        .confirmationDialog(episode.title, isPresented: menuBinding(episode), titleVisibility: .visible) {
            holdMenu(episode)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    /// The menu a still hold gives a tab that can move (the others keep
    /// iOS's own hold menu).
    @ViewBuilder private func holdMenu(_ episode: PodcastEpisode) -> some View {
        let on: Bool = episode.episodeID == playingID && player.isPlaying
        let saved: Bool = SaveForLater.isSaved(episode.episodeID, in: savedRaw)
        Button(on ? "Pause" : "Play now") { actions.playNow(episode) }
        Button("Play next") { actions.playNext(episode) }
        if actions.isQueued(episode) {
            Button("Remove from Up next", role: .destructive) { actions.removeFromUpNext(episode) }
        }
        Button("Episode notes") { notes = episode }
        Button(saved ? "Remove from Saved for later" : "Save for later") { SaveForLater.toggle(episode.episodeID) }
        Button("Cancel", role: .cancel) {}
    }

    private func hooks(for episode: PodcastEpisode) -> DeckTabHooks {
        DeckTabHooks(earlier: { step(episode.episodeID, by: -1) },
                     later: { step(episode.episodeID, by: 1) },
                     more: { menuFor = episode.episodeID })
    }

    private func menuBinding(_ episode: PodcastEpisode) -> Binding<Bool> {
        let id: String = episode.episodeID
        return Binding(get: { menuFor == id }, set: { on in if !on && menuFor == id { menuFor = nil } })
    }

    /// The lifted card: drawn over the grid where the finger has taken it.
    /// Only its own lift and drop animate; the other tabs' moves don't
    /// carry it along (it stays under the finger).
    @ViewBuilder private func liftedCard(shown: [PodcastEpisode]) -> some View {
        if let lift, let episode = shown.first(where: { $0.episodeID == lift.id }) {
            let raised: Bool = lift.phase == .raised
            DeckTabCard(episode: episode, place: place(of: episode, in: shown), lifted: true)
                .frame(width: cardWidth, height: cardHeight)
                .scaleEffect(raised ? 1.05 : 1)
                .shadow(color: Color.black.opacity(raised ? 0.24 : 0.08), radius: raised ? 18 : 6, y: raised ? 10 : 2)
                .offset(liftOffset(lift))
                .allowsHitTesting(false)
                .animation(.spring(duration: 0.26, bounce: 0.15), value: lift.phase)
                .transaction { $0.animation = nil }
                .accessibilityHidden(true)
        }
    }

    // MARK: Order

    /// The tabs as shown: the order being dragged into, while dragging.
    private var displayed: [PodcastEpisode] {
        guard let lift else { return tabs }
        var byID: [String: PodcastEpisode] = [:]
        for tab in tabs where byID[tab.episodeID] == nil { byID[tab.episodeID] = tab }
        var list: [PodcastEpisode] = []
        if let first = tabs.first, first.episodeID == playingID {
            list.append(first)
            byID[first.episodeID] = nil
        }
        for id in lift.order {
            if let tab = byID.removeValue(forKey: id) { list.append(tab) }
        }
        // Anything that arrived mid-drag goes on the end.
        list += tabs.filter { byID[$0.episodeID] != nil }
        return list
    }

    /// Up next's order on each tab (Paul, 16 Nov 2026: "add a number to
    /// the up next tabs to make it clear the order"): "Now" on the one
    /// playing, then 1, 2, 3… for what comes after (live while dragging).
    /// None in New / Saved.
    private func place(of episode: PodcastEpisode, in shown: [PodcastEpisode]) -> String? {
        guard model.group == .upNext else { return nil }
        let playing: String? = playingID
        if episode.episodeID == playing { return "Now" }
        var number: Int = 0
        for tab in shown where tab.episodeID != playing {
            number += 1
            if tab.episodeID == episode.episodeID { return String(number) }
        }
        return nil
    }

    // MARK: Slots

    private func slotOrigin(_ slot: Int) -> CGPoint {
        let column: Int = slot % 2
        let row: Int = slot / 2
        return CGPoint(x: CGFloat(column) * (cardWidth + Self.gap), y: CGFloat(row) * (cardHeight + Self.gap))
    }

    private func liftOffset(_ lift: DeckTabLift) -> CGSize {
        if lift.phase == .dropping {
            let index: Int = lift.order.firstIndex(of: lift.id) ?? 0
            let origin: CGPoint = slotOrigin(lift.lead + index)
            return CGSize(width: origin.x, height: origin.y)
        }
        let start: CGPoint = slotOrigin(lift.startSlot)
        return CGSize(width: start.x + lift.translation.width, height: start.y + lift.translation.height)
    }

    /// The place in `order` the card's middle is over.
    private func target(for lift: DeckTabLift) -> Int {
        let start: CGPoint = slotOrigin(lift.startSlot)
        let midX: CGFloat = start.x + lift.translation.width + cardWidth / 2
        let midY: CGFloat = start.y + lift.translation.height + cardHeight / 2
        let column: Int = midX < width / 2 ? 0 : 1
        let row: Int = max(0, Int((midY / (cardHeight + Self.gap)).rounded(.down)))
        let index: Int = row * 2 + column - lift.lead
        return min(max(0, lift.order.count - 1), max(0, index))
    }

    // MARK: The hold and drag

    private func began(_ id: String) {
        guard lift == nil, model.group == .upNext else { return }
        let playing: String? = playingID
        guard id != playing, let slot = tabs.firstIndex(where: { $0.episodeID == id }) else { return }
        let order: [String] = tabs.map(\.episodeID).filter { $0 != playing }
        let lead: Int = (playing != nil && tabs.first?.episodeID == playing) ? 1 : 0
        lift = DeckTabLift(id: id, startSlot: slot, lead: lead, startOrder: order, order: order)
        model.reordering = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Raised on the next turn, so it grows from where it sat.
        DispatchQueue.main.async {
            if lift?.id == id && lift?.phase == .lifting { lift?.phase = .raised }
        }
    }

    private func moved(_ translation: CGSize) {
        guard var current = lift, current.phase != .dropping else { return }
        current.translation = translation
        if hypot(translation.width, translation.height) > 8 { current.moved = true }
        let to: Int = target(for: current)
        guard let from = current.order.firstIndex(of: current.id), from != to else {
            lift = current
            return
        }
        current.order.remove(at: from)
        current.order.insert(current.id, at: to)
        current.moved = true
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.28)) { lift = current }
    }

    private func ended(cancelled: Bool) {
        guard var current = lift else { return }
        model.reordering = false
        let still: Bool = !current.moved
        if cancelled || still {
            current.order = current.startOrder
        }
        commit(current)
        current.phase = .dropping
        withAnimation(.snappy(duration: 0.28)) { lift = current }
        let id: String = current.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if lift?.id == id && lift?.phase == .dropping { lift = nil }
            if still && !cancelled { menuFor = id }
        }
    }

    /// Up next takes the new order: the tab takes the place of the one
    /// that was there (placed by hand, like the other reorders).
    private func commit(_ lift: DeckTabLift) {
        guard let from = lift.startOrder.firstIndex(of: lift.id),
              let to = lift.order.firstIndex(of: lift.id), from != to,
              lift.startOrder.indices.contains(to) else { return }
        _ = actions.move(lift.id, onto: lift.startOrder[to])
    }

    /// VoiceOver: Move earlier / Move later.
    private func step(_ id: String, by offset: Int) {
        let order: [String] = tabs.map(\.episodeID).filter { $0 != playingID }
        guard let at = order.firstIndex(of: id), order.indices.contains(at + offset) else { return }
        _ = actions.move(id, onto: order[at + offset])
    }
}

/// The drag under way.
private struct DeckTabLift {
    enum Phase { case lifting, raised, dropping }

    let id: String
    /// Its place in the grid when lifted (counting the playing tab).
    let startSlot: Int
    /// 1 when the playing tab sits first (it never moves).
    let lead: Int
    /// The Up next tabs (not the one playing) before the drag.
    let startOrder: [String]
    /// The order it's being dragged into.
    var order: [String]
    var translation: CGSize = .zero
    var moved = false
    var phase: Phase = .lifting
}

/// The gap the lifted tab will drop into.
private struct DeckTabGap: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(Theme.ink.opacity(0.05))
            .overlay(shape.strokeBorder(Theme.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .accessibilityHidden(true)
    }
}

/// VoiceOver actions for a tab that can move.
private struct DeckTabHooks {
    let earlier: () -> Void
    let later: () -> Void
    let more: () -> Void
}

/// Touch and hold (0.35 s, the finger kept within 8 pt) to lift a tab;
/// then it reports how far the finger has gone (against the screen, as the
/// grid doesn't scroll while a tab is lifted). Pans (scrolling, the
/// card's swipe to close) wait until the hold has failed, so a swipe that
/// starts without the hold scrolls as usual and a lifted tab never
/// scrolls the page.
private struct DeckTabHold: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let began: () -> Void
    let changed: (CGSize) -> Void
    /// true when iOS cancelled it (a call, the app going away).
    let ended: (Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.35
        press.allowableMovement = 8
        press.delegate = context.coordinator
        press.isEnabled = isEnabled
        return press
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.isEnabled != isEnabled { recognizer.isEnabled = isEnabled }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let point: CGPoint = recognizer.location(in: nil)
        switch recognizer.state {
        case .began:
            context.coordinator.start = point
            began()
        case .changed:
            let start: CGPoint = context.coordinator.start
            changed(CGSize(width: point.x - start.x, height: point.y - start.y))
        case .ended:
            ended(false)
        case .cancelled, .failed:
            ended(true)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint = .zero

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}

// MARK: - The card

/// One tab, in full colour (Paul, 16 Nov 2026): the artwork fills the
/// card and fades at the foot into the show's colour, where the show, the
/// title and the time left (or date) sit in white with the small ring.
/// × top right on a soft dark circle, the order number in the top left
/// corner, and a dark edge with a white line inside on the tab playing.
private struct DeckTabCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    /// Its place in Up next ("Now", "1", "2"…), or nil.
    var place: String? = nil
    /// The copy that follows the finger while dragging.
    var lifted = false
    /// Can be dragged (Up next, not the one playing): no iOS hold menu.
    var reorderable = false
    var hooks: DeckTabHooks? = nil

    /// How far the card has been swiped sideways (left only).
    @State private var drag: CGFloat = 0
    @State private var width: CGFloat = 170
    @State private var closing = false
    @State private var notes: PodcastEpisode?

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }
    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    private var colour: Color { DeckRings.showColour(episode) }

    var body: some View {
        card
            .offset(x: drag)
            .opacity(1 - Double(min(0.6, abs(drag) / max(width, 1) * 0.6)))
            .gesture(DeckShowPan(isEnabled: !closing && !lifted && !model.reordering, changed: moved, ended: released))
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { new in width = new }
            .sheet(item: $notes) { episode in EpisodeNotesView(episode: episode) }
            .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
    }

    private var card: some View {
        Button { model.open(episode.episodeID) } label: { face }
            .buttonStyle(.plain)
            .accessibilityLabel("Open " + episode.title)
            .accessibilityValue(episode.showTitle + ", " + detail)
            .accessibilityActions { voiceOverActions }
            .overlay(alignment: .topLeading) { placeBadge }
            .overlay(alignment: .topTrailing) { closeButton }
            .clipShape(shape)
            .overlay { edge }
            .background {
                shape.fill(colour)
                    .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(lifted ? 0 : 0.12),
                            radius: 8, y: 3)
            }
            .contentShape(.contextMenuPreview, shape)
            .modifier(DeckTabContextMenu(enabled: !reorderable && !lifted) { menu })
    }

    @ViewBuilder private var voiceOverActions: some View {
        if let hooks {
            Button("Move earlier", action: hooks.earlier)
            Button("Move later", action: hooks.later)
            Button("More", action: hooks.more)
        }
        Button(model.group == .saved ? "Close tab, remove from Saved" : "Close tab, mark played", action: close)
    }

    /// Artwork, the fade into the show's colour, and the words.
    private var face: some View {
        ZStack(alignment: .bottomLeading) {
            colour
            artwork
            fade
            words
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var artwork: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    CachedImage(url: episode.artwork) { Theme.placeholderColor(for: episode.showTitle) }
                }
                .clipped()
            Spacer(minLength: 0)
        }
    }

    /// Clear at the top, the show's colour (solid) under the words, plus a
    /// little dark so white reads on pale colours too.
    private var fade: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: colour.opacity(0), location: 0.30),
                .init(color: colour.opacity(0.78), location: 0.54),
                .init(color: colour, location: 0.68),
            ], startPoint: .top, endPoint: .bottom)
            LinearGradient(stops: [
                .init(color: Color.black.opacity(0), location: 0.45),
                .init(color: Color.black.opacity(0.18), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(episode.showTitle.uppercased())
                .font(Theme.outfit(10, .bold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(14, .bold))
                .foregroundStyle(Color.white)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            timeRow
                .padding(.top, 3)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 2, y: 1)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var timeRow: some View {
        HStack(spacing: 6) {
            DeckRing(progress: DeckRing.progress(of: episode), lineWidth: 2.5,
                     colour: Color.white, track: Color.white.opacity(0.3))
                .frame(width: 16, height: 16)
            Text(detail)
                .font(Theme.outfit(11, .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    /// The tab playing: a dark edge with a white line inside, clear on any
    /// colour; the others a faint edge.
    @ViewBuilder private var edge: some View {
        if isOn {
            ZStack {
                shape.strokeBorder(Theme.ink, lineWidth: 3)
                shape.inset(by: 3)
                    .strokeBorder(Color.white, lineWidth: 1.5)
            }
            .allowsHitTesting(false)
        } else {
            shape.strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.4)))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    /// "Now", "1", "2"… as a plain white number in the artwork's corner,
    /// over a faint shade that fades in from the corner so it reads on
    /// pale artwork too (Paul, 16 Nov 2026: the ink pill was "a bit too
    /// strong"; picked B2 "corner shade" from
    /// https://claude.ai/artifact/PsQEdGqw4K5GF6Aq7SfHXn).
    @ViewBuilder private var placeBadge: some View {
        if let place {
            ZStack(alignment: .topLeading) {
                RadialGradient(colors: [Color.black.opacity(0.42), Color.black.opacity(0)],
                               center: .topLeading, startRadius: 0, endRadius: 64)
                    .frame(width: 72, height: 72)
                Text(place)
                    .font(Theme.outfit(14, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 1, y: 1)
                    .padding(.leading, 10)
                    .padding(.top, 7)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(place == "Now" ? "Playing now" : "Number \(place) in Up next")
        }
    }

    @ViewBuilder private var menu: some View {
        Button(isOn && player.isPlaying ? "Pause" : "Play now", systemImage: isOn && player.isPlaying ? "pause" : "play") {
            actions.playNow(episode)
        }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { actions.playNext(episode) }
        if actions.isQueued(episode) {
            Button("Remove from Up next", systemImage: "minus.circle") { actions.removeFromUpNext(episode) }
        }
        Button("Episode notes", systemImage: "doc.text") { notes = episode }
        DeckSaveForLaterMenuItem(episode: episode)
    }

    /// "Playing · 34m left", "34m left" once started, else "9 Nov · 52m".
    private var detail: String {
        let date: String = episode.published.formatted(.dateTime.day().month(.abbreviated))
        guard let duration = episode.duration, duration > 0 else { return isOn ? "Playing" : date }
        let left: TimeInterval = episode.timeLeft ?? duration
        if isOn { return "Playing · " + DeckUpNextTime.length(left) + " left" }
        if episode.position > 30 && left > 0 { return DeckUpNextTime.length(left) + " left" }
        return date + " · " + DeckUpNextTime.length(duration)
    }

    // MARK: Swipe to close (like Safari)

    private func moved(_ x: CGFloat) {
        guard !closing else { return }
        // Left only; a little give to the right.
        drag = x < 0 ? x : x * 0.15
    }

    private func released(_ velocity: CGFloat) {
        guard !closing else { return }
        let far: Bool = drag < -width * 0.35
        let flick: Bool = velocity < -700 && drag < -12
        if far || flick {
            closing = true
            withAnimation(.easeOut(duration: 0.2)) { drag = -width * 1.4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                close()
                // If Undo brings it back, it comes back in place.
                drag = 0
                closing = false
            }
        } else {
            withAnimation(.spring(duration: 0.3)) { drag = 0 }
        }
    }

    private func close() {
        actions.close(episode)
    }
}

/// iOS's own hold menu, only on tabs that can't be dragged (the hold
/// lifts the others).
private struct DeckTabContextMenu<Items: View>: ViewModifier {
    let enabled: Bool
    @ViewBuilder let items: () -> Items

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.contextMenu { items() }
        } else {
            content
        }
    }
}
