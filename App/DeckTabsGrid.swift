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
//
// Build 163 (Paul, 16 Nov 2026: "Hold and drag isn't working at all …
// Swipe left marks as played with a visual confirmation. Right gives us
// next or last"): every card has one touch handler (`DeckTabTouches`) that
// tells a tap, a hold and a sideways swipe apart, so nothing competes for
// the finger; the page scrolls by itself when a lifted tab nears the top or
// bottom. Swipe left = Played, right = Play next, further = Add to end.

struct DeckTabsGrid: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let tabs: [PodcastEpisode]

    /// The tab being dragged, while it is.
    @State private var lift: DeckTabLift?
    /// A hold on a tab that can't move, while the finger is down.
    @State private var still: DeckTabStill?
    /// The tab whose menu is showing (after a still hold).
    @State private var menuFor: String?
    @State private var notes: PodcastEpisode?
    @State private var width: CGFloat = 360
    /// The tabs as last shown (build 165, Paul: "the disappearing card
    /// animation when swiped away is very jerky"). `tabs` can change in a
    /// transaction with no animation (New's query catching up, Saved's
    /// stored list, the player moving on, Undo's played flags), so the grid
    /// follows it here inside its own animation: tabs leaving close up,
    /// ones coming back (Undo) fade and grow in, moved ones glide.
    @State private var mirror: [PodcastEpisode]?
    @State private var mirrorGroup: DeckTabGroup?
    /// Tabs just closed here: out of the grid at once, in the same
    /// animation, without waiting for the library to catch up.
    @State private var gone: Set<String> = []

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

    /// What the grid shows (before a drag's reordering): `tabs` as
    /// followed, less tabs just closed.
    private var base: [PodcastEpisode] {
        let followed: [PodcastEpisode] = (mirrorGroup == model.group ? mirror : nil) ?? tabs
        guard !gone.isEmpty else { return followed }
        return followed.filter { !gone.contains($0.episodeID) }
    }

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
        .onChange(of: tabs.map(\.episodeID), initial: true) { _, ids in follow(ids) }
        // Undo (or a close that didn't happen): bring back any tab that's
        // open again.
        .onChange(of: store.undoAction?.id) { _, _ in recheckGone() }
    }

    // MARK: Following the tabs

    private func follow(_ ids: [String]) {
        let present: Set<String> = Set(ids)
        let stale: Set<String> = gone.subtracting(present)
        if mirror == nil || mirrorGroup != model.group {
            // First showing, or another group: no animation.
            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true
            withTransaction(instant) {
                mirror = tabs
                mirrorGroup = model.group
                gone = []
            }
            return
        }
        guard mirror?.map(\.episodeID) != ids || !stale.isEmpty else { return }
        // What was playing last coming back on opening (or swapped in by
        // iCloud) takes first place as "Now" in one step, not a shuffle.
        if let restored = player.restoredEpisodeID, ids.first == restored,
           mirror?.first?.episodeID != restored {
            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true
            withTransaction(instant) {
                mirror = tabs
                if !stale.isEmpty { gone.subtract(stale) }
            }
            return
        }
        withAnimation(LibraryStore.listChange) {
            mirror = tabs
            // Already hidden, so letting them go changes nothing on screen.
            if !stale.isEmpty { gone.subtract(stale) }
        }
    }

    /// A tab closed with × or a swipe: out of the grid (the others close
    /// up) and marked played / off Saved, in one animation.
    private func leave(_ episode: PodcastEpisode) {
        let id: String = episode.episodeID
        withAnimation(LibraryStore.listChange) {
            _ = gone.insert(id)
            actions.close(episode)
        }
        // If the close didn't take, the tab comes back rather than staying
        // hidden.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { recheckGone() }
    }

    private func recheckGone() {
        guard !gone.isEmpty else { return }
        let back: Set<String> = gone.filter { id in
            guard let tab = tabs.first(where: { $0.episodeID == id }) else { return false }
            return stillOpen(tab)
        }
        guard !back.isEmpty else { return }
        withAnimation(LibraryStore.listChange) { gone.subtract(back) }
    }

    /// Whether a tab in `tabs` should still show (the library may lag).
    private func stillOpen(_ episode: PodcastEpisode) -> Bool {
        return !episode.played
    }

    private func dropLift() {
        if lift != nil { lift = nil }
        if still != nil { still = nil }
        if model.reordering { model.reordering = false }
    }

    // MARK: Cells

    private func canMove(_ episode: PodcastEpisode) -> Bool {
        model.group == .upNext && episode.episodeID != playingID
    }

    @ViewBuilder private func cell(_ episode: PodcastEpisode, shown: [PodcastEpisode]) -> some View {
        DeckTabCell(episode: episode, place: place(of: episode, in: shown),
                    hidden: lift?.id == episode.episodeID, height: cardHeight,
                    hooks: hooks(for: episode),
                    hold: { touch in held(touch, episode: episode) },
                    leave: { leave(episode) })
            .confirmationDialog(episode.title, isPresented: menuBinding(episode), titleVisibility: .visible) {
                holdMenu(episode)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    /// The menu a still hold gives any tab (build 163: iOS's own hold menu
    /// is gone from the cards, so it can't fight the hold either).
    @ViewBuilder private func holdMenu(_ episode: PodcastEpisode) -> some View {
        let on: Bool = episode.episodeID == playingID && player.isPlaying
        Button(on ? "Pause" : "Play now") { actions.playNow(episode) }
        if episode.episodeID != playingID {
            Button("Play next") { actions.playNextInOrder(episode) }
            Button("Add to end") { actions.addToEnd(episode) }
        }
        if actions.isQueued(episode) {
            Button("Remove from Up next", role: .destructive) { actions.removeFromUpNext(episode) }
        }
        Button("Episode notes") { notes = episode }
        Button("Cancel", role: .cancel) {}
    }

    private func hooks(for episode: PodcastEpisode) -> DeckTabHooks {
        let id: String = episode.episodeID
        guard canMove(episode) else { return DeckTabHooks(earlier: nil, later: nil, more: { menuFor = id }) }
        return DeckTabHooks(earlier: { step(id, by: -1) }, later: { step(id, by: 1) }, more: { menuFor = id })
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
                .overlay(alignment: .topTrailing) { DeckTabCloseGlyph() }
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
        let tabs: [PodcastEpisode] = base
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
        return CGSize(width: start.x + lift.translation.width, height: start.y + lift.translation.height + lift.shift)
    }

    /// The place in `order` the card's middle is over.
    private func target(for lift: DeckTabLift) -> Int {
        let start: CGPoint = slotOrigin(lift.startSlot)
        let midX: CGFloat = start.x + lift.translation.width + cardWidth / 2
        let midY: CGFloat = start.y + lift.translation.height + lift.shift + cardHeight / 2
        let column: Int = midX < width / 2 ? 0 : 1
        let row: Int = max(0, Int((midY / (cardHeight + Self.gap)).rounded(.down)))
        let index: Int = row * 2 + column - lift.lead
        return min(max(0, lift.order.count - 1), max(0, index))
    }

    // MARK: The hold and drag

    /// A hold on a card (from its `DeckTabTouches`).
    private func held(_ touch: DeckTabTouch, episode: PodcastEpisode) {
        let id: String = episode.episodeID
        switch touch {
        case .holdBegan:
            if canMove(episode) { began(id) } else { beganStill(id) }
        case .holdMoved(let travel, let shift):
            if still?.id == id {
                if hypot(travel.width, travel.height) > 8 { still?.moved = true }
            } else if lift?.id == id {
                moved(travel, shift: shift)
            }
        case .holdEnded(let cancelled):
            if still?.id == id {
                endedStill(cancelled: cancelled)
            } else if lift?.id == id {
                ended(cancelled: cancelled)
            }
        default:
            break
        }
    }

    /// A tab that can't move (the one playing, New, Saved): a still hold
    /// gives its menu when the finger lifts.
    private func beganStill(_ id: String) {
        guard lift == nil, still == nil else { return }
        still = DeckTabStill(id: id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endedStill(cancelled: Bool) {
        guard let current = still else { return }
        still = nil
        if !current.moved && !cancelled { menuFor = current.id }
    }

    private func began(_ id: String) {
        guard lift == nil, still == nil, model.group == .upNext else { return }
        let playing: String? = playingID
        let tabs: [PodcastEpisode] = base
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

    private func moved(_ translation: CGSize, shift: CGFloat) {
        guard var current = lift, current.phase != .dropping else { return }
        current.translation = translation
        current.shift = shift
        if hypot(translation.width, translation.height) > 8 || abs(shift) > 8 { current.moved = true }
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
        let stayed: Bool = !current.moved
        if cancelled || stayed {
            current.order = current.startOrder
        }
        commit(current)
        current.phase = .dropping
        withAnimation(.snappy(duration: 0.28)) { lift = current }
        let id: String = current.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if lift?.id == id && lift?.phase == .dropping { lift = nil }
            if stayed && !cancelled { menuFor = id }
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
        let order: [String] = base.map(\.episodeID).filter { $0 != playingID }
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
    /// How far the page has scrolled by itself since the lift.
    var shift: CGFloat = 0
    var moved = false
    var phase: Phase = .lifting
}

/// A hold on a tab that can't be dragged.
private struct DeckTabStill {
    let id: String
    var moved = false
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

/// VoiceOver actions: Move earlier / later for a tab that can move, and
/// the tab's menu.
private struct DeckTabHooks {
    let earlier: (() -> Void)?
    let later: (() -> Void)?
    let more: () -> Void
}


// MARK: - A cell: the card, its swipes and the block behind it

/// Where a sideways swipe has got to.
private enum DeckTabSwipeZone: Equatable {
    case idle
    /// Left: Played (Remove in Saved), armed past 38% of the card.
    case left(armed: Bool)
    /// Right, under 28%: nothing yet.
    case hint
    /// Right, 28–62%: Play next.
    case next
    /// Right, beyond 62%: Add to end.
    case end

    var isLeft: Bool {
        if case .left = self { return true }
        return false
    }

    var armed: Bool {
        switch self {
        case .left(let armed): return armed
        case .next, .end: return true
        case .idle, .hint: return false
        }
    }
}

/// One tab in the grid. Its `DeckTabTouches` gives taps (open) and swipes
/// to the cell and holds to the grid.
///
/// Swipe left (Paul, 16 Nov 2026: "Swipe left marks as played with a
/// visual confirmation"): the card follows the finger over a red block
/// with ✓ and "Played"; past 38% of its width (or a quick flick) it arms.
/// Build 165 (Paul: "the disappearing card animation when swiped away is
/// very jerky"): let go armed and the card keeps going the way it was
/// thrown, at the finger's speed, fading as it goes, while the ✓ on the
/// red block left in its slot grows (the confirmation); then the grid
/// closes the gap in one animation (`DeckTabsGrid.leave`) and it's marked
/// played (Undo brings it back the same way). × does the same with the
/// card shrinking away instead. Not armed: it springs back, the block
/// fading with it. Swipe right: Play next (green, 28–62%), further Add to
/// end (ink); let go and it springs back, then glides to its new place
/// with a ring pulse (Undo). Both keep each show in order. The tab
/// playing can only be swiped left; Saved tabs only left (off the Saved
/// list).
private struct DeckTabCell: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    let place: String?
    /// Lifted out (its copy follows the finger): only the gap shows here.
    let hidden: Bool
    let height: CGFloat
    let hooks: DeckTabHooks
    let hold: (DeckTabTouch) -> Void
    /// Close the tab: the grid takes it out (closing the gap) and marks it
    /// played / off Saved, all in one animation.
    let leave: () -> Void

    @State private var drag: CGFloat = 0
    @State private var width: CGFloat = 170
    @State private var zone: DeckTabSwipeZone = .idle
    /// A swipe's action is under way: further touches wait.
    @State private var busy = false
    /// On its way out: the card fades as it goes.
    @State private var leaving = false
    /// × pressed: the card shrinks away rather than sliding.
    @State private var tossed = false
    /// The ✓ on the block has grown: it's done.
    @State private var confirmed = false
    @State private var ringOpacity: Double = 0
    @State private var ringScale: CGFloat = 1

    /// Back into place when a swipe isn't let go far enough (or after a
    /// right swipe): a real spring the eye can follow.
    private static let springBack: Animation = .interpolatingSpring(duration: 0.42, bounce: 0.16)

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }
    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    /// Saved is gone (Paul, 16 Nov 2026): every group's left swipe is Played.
    private var saved: Bool { false }
    private var canGoRight: Bool { !isOn && !saved }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        content
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(DeckTabTouches(handle: touched))
            // Outside the gesture, so a tap on × is only ever ×.
            .overlay(alignment: .topTrailing) { closeButton }
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { new in width = new }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open " + episode.title)
            .accessibilityValue(episode.showTitle + ", " + DeckTabCard.detail(episode, isOn: isOn))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.open(episode.episodeID) }
            .accessibilityActions { voiceOverActions }
            // A grid can hand back a cell it kept from before the close.
            .onAppear { comeBack() }
    }

    private var content: some View {
        ZStack {
            DeckTabSwipeBlock(zone: zone, saved: saved, confirmed: confirmed)
                .opacity(blockOpacity)
            card
            pulseRing
            if hidden {
                DeckTabGap()
            }
        }
    }

    private var card: some View {
        DeckTabCard(episode: episode, place: place)
            .scaleEffect(tossed ? 0.84 : 1)
            .offset(x: drag, y: tossed ? -12 : 0)
            .opacity(hidden || leaving ? 0 : 1)
    }

    /// The block fades in over the first 30 pt (and out the same way as
    /// the card springs back).
    private var blockOpacity: Double {
        Double(min(1, abs(drag) / 30))
    }

    private var closeButton: some View {
        Button(action: closeTapped) { DeckTabCloseGlyph() }
            .buttonStyle(.plain)
            .scaleEffect(tossed ? 0.84 : 1)
            .offset(x: drag)
            .opacity(hidden || leaving ? 0 : 1)
            .allowsHitTesting(!hidden && !busy)
            .accessibilityHidden(true)
    }

    /// A brief ink ring after a right swipe moves the tab.
    private var pulseRing: some View {
        shape
            .strokeBorder(Theme.ink, lineWidth: 3)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var voiceOverActions: some View {
        if let earlier = hooks.earlier { Button("Move earlier", action: earlier) }
        if let later = hooks.later { Button("Move later", action: later) }
        Button("More", action: hooks.more)
        if canGoRight {
            Button("Play next") { actions.playNextInOrder(episode) }
            Button("Add to end") { actions.addToEnd(episode) }
        }
        Button(saved ? "Close tab, remove from Saved" : "Close tab, mark played", action: leave)
    }

    // MARK: Touches

    private func touched(_ touch: DeckTabTouch) {
        switch touch {
        case .tap:
            guard !busy, !model.reordering, !hidden else { return }
            model.open(episode.episodeID)
        case .holdBegan, .holdMoved, .holdEnded:
            guard !busy, drag == 0 else { return }
            hold(touch)
        case .swipeMoved(let x):
            swiped(x)
        case .swipeEnded(let x, let speed, let cancelled):
            released(x, speed: speed, cancelled: cancelled)
        }
    }

    private func zone(for dx: CGFloat) -> DeckTabSwipeZone {
        let w: CGFloat = max(width, 1)
        if dx < 0 { return .left(armed: -dx > w * 0.38) }
        guard dx > 0, canGoRight else { return .idle }
        if dx < w * 0.28 { return .hint }
        if dx < w * 0.62 { return .next }
        return .end
    }

    private func swiped(_ x: CGFloat) {
        guard !busy, !model.reordering, !hidden else { return }
        // Only a little give where there's nothing to do.
        let dx: CGFloat = (x > 0 && !canGoRight) ? x * 0.15 : x
        drag = dx
        let next: DeckTabSwipeZone = zone(for: dx)
        guard next != zone else { return }
        if next.armed {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = dx < 0 ? .medium : .light
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        zone = next
    }

    private func released(_ x: CGFloat, speed: CGFloat, cancelled: Bool) {
        guard !busy else { return }
        var chosen: DeckTabSwipeZone = zone
        if speed < -700 && drag < -12 { chosen = .left(armed: true) }
        if cancelled || model.reordering || hidden || !chosen.armed {
            settle()
            return
        }
        busy = true
        switch chosen {
        case .left:
            zone = chosen
            flyOff(speed: speed)
        case .next:
            moveRight(toEnd: false)
        case .end:
            moveRight(toEnd: true)
        case .hint, .idle:
            busy = false
        }
    }

    /// Springs back into its slot; the block fades out with it and is
    /// cleared once it's home.
    private func settle() {
        withAnimation(Self.springBack) { drag = 0 } completion: {
            if drag == 0 { zone = .idle }
        }
    }

    /// Armed and let go: the card carries on off its slot the way it was
    /// going, as fast as the finger was (0.2–0.28 s, easing out), fading as
    /// it goes; the ✓ on the red block grows; then the grid closes up.
    private func flyOff(speed: CGFloat) {
        let target: CGFloat = -(max(width, 1) + 30)
        let remaining: CGFloat = abs(target - drag)
        // An ease-out starts at about 1.8× its average speed, so this
        // starts the card at the finger's speed.
        let pace: CGFloat = max(-speed, 900)
        let time: Double = min(0.28, max(0.2, Double(remaining / pace) * 1.8))
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.easeOut(duration: time)) {
            drag = target
            leaving = true
        }
        withAnimation(.spring(duration: 0.34, bounce: 0.45)) { confirmed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + time + 0.1) { leave() }
        restoreIfStillHere(after: time + 1.4)
    }

    /// The tab came back after being closed (Undo, or added to Up next
    /// again soon after; Paul, 21 Nov 2026: the slot showed the red
    /// "Played" block with no card): put the card back in its slot
    /// rather than leave it flown off.
    private func restoreIfStillHere(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { comeBack() }
    }

    private func comeBack() {
        guard leaving || busy || drag != 0 || confirmed else { return }
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) {
            confirmed = false
            zone = .idle
            tossed = false
            drag = 0
        }
        withAnimation(.easeOut(duration: 0.25)) { leaving = false }
        busy = false
    }

    /// ×: the card shrinks and fades where it is, then the grid closes up.
    private func closeTapped() {
        guard !busy, !hidden, !model.reordering else { return }
        busy = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.22)) {
            leaving = true
            tossed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { leave() }
        restoreIfStillHere(after: 1.6)
    }

    /// Springs back, then Up next changes (the grid glides it to its new
    /// place) and a ring pulses round it.
    private func moveRight(toEnd: Bool) {
        withAnimation(Self.springBack) { drag = 0 } completion: {
            if drag == 0 { zone = .idle }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            if toEnd { actions.addToEnd(episode) } else { actions.playNextInOrder(episode) }
            busy = false
            pulse()
        }
    }

    private func pulse() {
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) {
            ringScale = 1
            ringOpacity = 0.55
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.9)) {
                ringScale = 1.08
                ringOpacity = 0
            }
        }
    }
}

/// What shows behind a card being swiped: red Played on the right for a
/// left swipe; grey, then green Play next, then ink Add to end on the left
/// for a right swipe. The icon goes white with an ink tick once it would
/// happen on letting go; once the card has gone (`confirmed`) the ✓ grows
/// and the block is the confirmation left in the tab's slot.
private struct DeckTabSwipeBlock: View {
    let zone: DeckTabSwipeZone
    let saved: Bool
    var confirmed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        row
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(colour))
            .animation(.easeOut(duration: 0.12), value: zone)
            .animation(.spring(duration: 0.34, bounce: 0.45), value: confirmed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var row: some View {
        if zone.isLeft {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                words(alignment: .trailing)
                icon
                    .padding(.horizontal, confirmed ? 8 : 0)
            }
        } else if zone != .idle {
            HStack(spacing: 8) {
                icon
                words(alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    private var icon: some View {
        let armed: Bool = zone.armed
        return ZStack {
            Circle().fill(armed ? Color.white : Color.white.opacity(0.22))
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(armed ? Color(hex: 0x1C1B1A) : Color.white)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(confirmed ? 1.6 : (armed ? 1.22 : 1))
    }

    private func words(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(Theme.outfit(15, .heavy))
            Text(hint)
                .font(Theme.outfit(11, .semibold))
                .opacity(confirmed ? 0 : 0.85)
        }
        .foregroundStyle(Color.white)
        .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }

    private var colour: Color {
        switch zone {
        case .left: return Color(hex: 0xD9503B)
        case .hint: return Color(hex: 0x8E8984)
        case .next: return Color(hex: 0x2F8F5B)
        case .end: return Color(hex: 0x1C1B1A)
        case .idle: return Color.clear
        }
    }

    private var symbol: String {
        switch zone {
        case .left: return saved ? "xmark" : "checkmark"
        case .hint, .next: return "arrow.up"
        case .end: return "arrow.down"
        case .idle: return "checkmark"
        }
    }

    private var title: String {
        switch zone {
        case .left: return saved ? "Remove" : "Played"
        case .hint, .next: return "Play next"
        case .end: return "Add to end"
        case .idle: return ""
        }
    }

    private var hint: String {
        switch zone {
        case .left(let armed): return armed ? "let go" : "keep going"
        case .hint: return "keep going"
        case .next: return "let go, or keep going"
        case .end: return "let go"
        case .idle: return ""
        }
    }
}

/// × on a dark circle (the cell's close key, and on the lifted copy).
/// Paul, 16 Nov 2026: it was "a little lost depending on the episode art",
/// so the circle is bigger and darker, with a fine light edge and a soft
/// shadow, so it reads on pale and busy artwork alike.
private struct DeckTabCloseGlyph: View {
    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color.white)
            .frame(width: 26, height: 26)
            .background {
                Circle().fill(Color.black.opacity(0.58))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}

// MARK: - The card

/// One tab, in full colour (Paul, 16 Nov 2026): the artwork fills the
/// card and fades at the foot into the show's colour, where the show, the
/// title and the time left (or date) sit in white with the small ring.
/// The order number in the top left corner, and a dark edge with a white
/// line inside on the tab playing. Only the look: touches, × and swipes
/// are the cell's (`DeckTabCell`).
private struct DeckTabCard: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    /// Its place in Up next ("Now", "1", "2"…), or nil.
    var place: String? = nil
    /// The copy that follows the finger while dragging.
    var lifted = false

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    private var colour: Color { DeckRings.showColour(episode) }

    var body: some View {
        face
            .overlay(alignment: .topLeading) { placeBadge }
            .clipShape(shape)
            .overlay { edge }
            .background {
                shape.fill(colour)
                    .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(lifted ? 0 : 0.12),
                            radius: 8, y: 3)
            }
            .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
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
            HStack(spacing: 5) {
                if fresh { newFlag }
                Text(episode.showTitle.uppercased())
                    .font(Theme.outfit(10, .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
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

    /// "Now", "1", "2"… as a plain white number in the artwork's corner,
    /// over a faint shade that fades in from the corner so it reads on
    /// pale artwork too (Paul, 16 Nov 2026: the ink pill was "a bit too
    /// strong"; picked B2 "corner shade" from
    /// https://claude.ai/artifact/PsQEdGqw4K5GF6Aq7SfHXn). Then (16 Nov:
    /// "a little lost depending on the episode art") the shade is darker
    /// and a little bigger, holding its strength further out before it
    /// fades, and the number has a firmer shadow; still no pill.
    @ViewBuilder private var placeBadge: some View {
        if let place {
            DeckCornerShadeLabel(text: place, corner: .topLeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(place == "Now" ? "Playing now" : "Number \(place) in Up next")
        }
    }

    /// Out in the last 48 hours and not started (`DeckTabSource.isFresh`).
    private var fresh: Bool { !isOn && DeckTabSource.isFresh(episode) }

    /// A small coral "NEW" pill before the show's name (Paul, 16 Nov 2026:
    /// New left the groups; new episodes sit in Up next flagged instead).
    private var newFlag: some View {
        Text("NEW")
            .font(Theme.outfit(9, .heavy))
            .tracking(0.6)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(DeckRings.coral))
            .fixedSize()
            .accessibilityLabel("New")
    }

    /// "Playing · 34m left", "34m left" once started, else "9 Nov · 52m".
    private var detail: String { Self.detail(episode, isOn: isOn) }

    static func detail(_ episode: PodcastEpisode, isOn: Bool) -> String {
        let date: String = episode.published.formatted(.dateTime.day().month(.abbreviated))
        guard let duration = episode.duration, duration > 0 else { return isOn ? "Playing" : date }
        let left: TimeInterval = episode.timeLeft ?? duration
        if isOn { return "Playing · " + DeckUpNextTime.length(left) + " left" }
        if episode.position > 30 && left > 0 { return DeckUpNextTime.length(left) + " left" }
        return date + " · " + DeckUpNextTime.length(duration)
    }
}

/// White heavy words in a picture's top corner over a dark shade that fades
/// out from the corner, so they read on pale artwork too: the order number
/// on a tab card ("Now", "1", "2"…) and "3 new" on a show tile (Paul, 16
/// Nov 2026: the black "1 new" pill on the show art "doesn't align with the
/// rest of the app … make it white with a shaded corner like in tabs").
struct DeckCornerShadeLabel: View {
    enum Corner { case topLeading, topTrailing }

    let text: String
    var corner: Corner = .topLeading

    var body: some View {
        let leading: Bool = corner == .topLeading
        let alignment: Alignment = leading ? .topLeading : .topTrailing
        let centre: UnitPoint = leading ? .topLeading : .topTrailing
        let side: Edge.Set = leading ? .leading : .trailing
        ZStack(alignment: alignment) {
            RadialGradient(stops: Self.stops, center: centre, startRadius: 0, endRadius: 78)
                .frame(width: 86, height: 86)
            Text(text)
                .font(Theme.outfit(15, .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .fixedSize()
                // Renumbers as tabs close up or move: it rolls, not jumps.
                .contentTransition(.numericText())
                .shadow(color: Color.black.opacity(0.55), radius: 3, y: 0)
                .shadow(color: Color.black.opacity(0.5), radius: 0.5, y: 1)
                .padding(side, 10)
                .padding(.top, 7)
        }
        .allowsHitTesting(false)
    }

    private static let stops: [Gradient.Stop] = [
        .init(color: Color.black.opacity(0.56), location: 0),
        .init(color: Color.black.opacity(0.34), location: 0.45),
        .init(color: Color.black.opacity(0), location: 1),
    ]
}
