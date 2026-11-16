import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// Moving between the three main sections in tabs mode (Paul, 15 Nov 2026:
// "I need a better way to switch between find, your shows and discover",
// then "add it all and build"). Discover is part of Find (an empty search
// box shows New to you and the charts), so there are three sections: Tabs,
// Your shows and Find. Each one has the same row of words at the top, and
// a swipe that starts at the screen's left or right edge moves to the
// section before or after, following the finger (`DeckSectionSwipe`). Swiping along the bottom bar still moves
// between episodes, and swiping up on it still shows the tabs.

/// Tabs · Your shows · Find, the current one underlined.
struct DeckSectionSwitcher: View {
    @Environment(\.deckSelectTab) private var selectTab
    let current: Int
    let tabCount: Int

    var body: some View {
        HStack(spacing: 20) {
            word("Tabs · \(tabCount)", index: 0)
            word("Your shows", index: 1)
            word("Find", index: 2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.cardEdge).frame(height: 1)
        }
    }

    private func word(_ title: String, index: Int) -> some View {
        let on: Bool = current == index
        return Button {
            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true
            withTransaction(instant) { selectTab(index) }
        } label: {
            Text(title)
                .font(Theme.outfit(17, .bold))
                .foregroundStyle(on ? Theme.ink : Theme.muted.opacity(0.7))
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(on ? Theme.ink : Color.clear)
                        .frame(height: 3)
                        .offset(y: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The section swipe in progress, shared with `DeckRoot`, which moves the
/// section on screen by `offset` and slides the one beside it in after it
/// (Paul, 16 Nov 2026: the swipe was instant, so "you can't tell if you're
/// activating it as it doesn't animate as you move"; now it follows the
/// finger like Safari's swipe between pages).
@Observable
final class DeckSectionSwipe {
    /// How far the section on screen has moved: + right, - left.
    var offset: CGFloat = 0
    /// The section sliding in beside it, while a swipe is on.
    var neighbour: Int? = nil
    /// The screen's width, for where the neighbour sits.
    var width: CGFloat = 390
    /// A finger is on it.
    var active = false
    /// Springing home or on to the next section.
    var settling = false

    /// How far along the swipe is, 0 to 1.
    var progress: CGFloat {
        guard width > 0 else { return 0 }
        return min(1, abs(offset) / width)
    }
}

private struct DeckSectionSwipeKey: EnvironmentKey {
    static let defaultValue = DeckSectionSwipe()
}

extension EnvironmentValues {
    var deckSectionSwipe: DeckSectionSwipe {
        get { self[DeckSectionSwipeKey.self] }
        set { self[DeckSectionSwipeKey.self] = newValue }
    }
}

private struct DeckSectionsModifier: ViewModifier {
    @Environment(\.deckSelectTab) private var selectTab
    @Environment(\.deckSectionSwipe) private var swipe
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @AppStorage(DeckHome.key) private var home: String = DeckHome.tabs
    @State private var armed = false
    let current: Int

    /// Past this share of the screen, letting go moves on.
    private static let commitShare: CGFloat = 0.35

    func body(content: Content) -> some View {
        if home != DeckHome.deck {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    DeckSectionSwitcher(current: current, tabCount: tabCount)
                }
                // One UIKit recognizer that only starts from within 20 pt of
                // the screen's edge and only when the finger goes sideways;
                // once it starts the page's own scrolling lets go, so it
                // doesn't twitch up and down under the swipe (Paul, 16 Nov
                // 2026). Anything else it gives up on at once.
                .gesture(DeckEdgeSwipe(handle: edgeEvent))
        } else {
            content
        }
    }

    private var tabCount: Int {
        let playing: String? = player.nowPlaying?.episodeID
        let queued: Int = store.queue.filter { $0.episode.id != playing }.count
        return queued + (playing == nil ? 0 : 1)
    }

    /// The section a swipe this way leads to, if there is one.
    private func target(for dx: CGFloat) -> Int? {
        let next: Int = dx > 0 ? current - 1 : current + 1
        return (0...2).contains(next) ? next : nil
    }

    private func edgeEvent(_ event: DeckEdgeSwipeEvent) {
        switch event {
        case .began(let width):
            guard !swipe.settling else { return }
            swipe.width = width
            swipe.active = true
            armed = false
        case .moved(let dx):
            guard swipe.active else { return }
            moved(dx)
        case .ended(let dx, let velocity, let cancelled):
            guard swipe.active else { return }
            swipe.active = false
            ended(dx, velocity: velocity, cancelled: cancelled)
        }
    }

    private func moved(_ dx: CGFloat) {
        let next: Int? = target(for: dx)
        let width: CGFloat = swipe.width
        swipe.neighbour = next
        // No section that way: it gives a little and pulls back.
        swipe.offset = next == nil ? Self.rubber(dx, width: width) : dx
        let past: Bool = next != nil && abs(dx) > width * Self.commitShare
        if past != armed {
            armed = past
            if past { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func ended(_ dx: CGFloat, velocity: CGFloat, cancelled: Bool) {
        let width: CGFloat = swipe.width
        let sameWay: Bool = (velocity > 0) == (dx > 0)
        let far: Bool = abs(dx) > width * Self.commitShare
        let flick: Bool = abs(velocity) > 550 && sameWay && abs(dx) > 30
        let flickBack: Bool = abs(velocity) > 300 && !sameWay
        if !cancelled, let next = target(for: dx), (far || flick), !flickBack {
            settle(to: next, leftward: dx < 0)
        } else {
            springBack()
        }
        armed = false
    }

    private func settle(to next: Int, leftward: Bool) {
        swipe.settling = true
        let model: DeckSectionSwipe = swipe
        let select = selectTab
        withAnimation(.spring(duration: 0.32, bounce: 0)) {
            model.offset = leftward ? -model.width : model.width
        } completion: {
            var instant = Transaction(animation: nil)
            instant.disablesAnimations = true
            withTransaction(instant) {
                select(next)
                model.offset = 0
                model.neighbour = nil
                model.settling = false
            }
        }
    }

    private func springBack() {
        swipe.settling = true
        let model: DeckSectionSwipe = swipe
        withAnimation(.spring(duration: 0.34, bounce: 0.12)) {
            model.offset = 0
        } completion: {
            model.neighbour = nil
            model.settling = false
        }
    }

    /// iOS-style give: moves less and less the further the finger goes.
    private static func rubber(_ dx: CGFloat, width: CGFloat) -> CGFloat {
        let pull: CGFloat = abs(dx) * 0.55
        let given: CGFloat = pull * width / (width + pull)
        return dx < 0 ? -given * 0.5 : given * 0.5
    }
}

// MARK: - The edge swipe's recognizer

enum DeckEdgeSwipeEvent {
    /// The swipe started; the screen's width.
    case began(CGFloat)
    /// How far the finger has gone sideways (against the screen).
    case moved(CGFloat)
    /// Sideways travel and speed (points per second) as the finger lifts.
    case ended(CGFloat, CGFloat, cancelled: Bool)
}

/// Begins only for a touch that starts within 20 pt of the screen's left
/// or right edge and then moves inwards, clearly sideways, by 8 pt.
/// Anything else fails at once, so the page scrolls as usual.
final class DeckEdgeSwipeRecognizer: UIGestureRecognizer {
    static let edge: CGFloat = 20
    static let slop: CGFloat = 8

    private(set) var start: CGPoint = .zero
    private(set) var current: CGPoint = .zero
    private(set) var velocityX: CGFloat = 0
    private(set) var screenWidth: CGFloat = 390
    /// The page under the finger.
    private(set) weak var scrollView: UIScrollView?

    private weak var finger: UITouch?
    private var fromLeft = true
    private var lastX: CGFloat = 0
    private var lastTime: TimeInterval = 0

    var travelX: CGFloat { current.x - start.x }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if finger != nil || touches.count != 1 {
            if state == .possible {
                state = .failed
            } else {
                for touch in touches where touch !== finger { ignore(touch, for: event) }
            }
            return
        }
        guard let touch = touches.first else { return }
        let width: CGFloat = view?.window?.bounds.width ?? UIScreen.main.bounds.width
        let point: CGPoint = touch.location(in: nil)
        guard point.x < Self.edge || point.x > width - Self.edge else {
            state = .failed
            return
        }
        finger = touch
        screenWidth = width
        fromLeft = point.x < Self.edge
        start = point
        current = point
        lastX = point.x
        lastTime = touch.timestamp
        scrollView = findScrollView()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        track(touch)
        guard state == .possible else {
            state = .changed
            return
        }
        let dx: CGFloat = current.x - start.x
        let dy: CGFloat = current.y - start.y
        guard hypot(dx, dy) > Self.slop else { return }
        let inwards: Bool = fromLeft ? dx > 0 : dx < 0
        state = (inwards && abs(dx) > abs(dy) * 1.2) ? .began : .failed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        // A finger that stopped before lifting isn't a flick.
        if touch.timestamp - lastTime > 0.1 { velocityX = 0 }
        current = touch.location(in: nil)
        state = state == .possible ? .failed : .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        state = state == .possible ? .failed : .cancelled
    }

    override func reset() {
        super.reset()
        finger = nil
        velocityX = 0
        scrollView = nil
    }

    private func track(_ touch: UITouch) {
        current = touch.location(in: nil)
        let elapsed: TimeInterval = touch.timestamp - lastTime
        if elapsed > 0 {
            let speed: CGFloat = (current.x - lastX) / CGFloat(elapsed)
            velocityX = velocityX * 0.3 + speed * 0.7
        }
        lastX = current.x
        lastTime = touch.timestamp
    }

    private func findScrollView() -> UIScrollView? {
        var up: UIView? = view
        while let at = up {
            if let scroll = at as? UIScrollView { return scroll }
            up = at.superview
        }
        var hit: UIView? = view?.window?.hitTest(start, with: nil)
        while let at = hit {
            if let scroll = at as? UIScrollView { return scroll }
            hit = at.superview
        }
        return nil
    }
}

/// The section edge swipe as a SwiftUI gesture.
struct DeckEdgeSwipe: UIGestureRecognizerRepresentable {
    let handle: (DeckEdgeSwipeEvent) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> DeckEdgeSwipeRecognizer {
        let recognizer = DeckEdgeSwipeRecognizer()
        recognizer.delegate = context.coordinator
        context.coordinator.handle = handle
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: DeckEdgeSwipeRecognizer, context: Context) {
        context.coordinator.handle = handle
    }

    func handleUIGestureRecognizerAction(_ recognizer: DeckEdgeSwipeRecognizer, context: Context) {
        context.coordinator.act(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var handle: ((DeckEdgeSwipeEvent) -> Void)?

        func act(_ recognizer: DeckEdgeSwipeRecognizer) {
            switch recognizer.state {
            case .began:
                stopScrolling(recognizer.scrollView)
                handle?(.began(recognizer.screenWidth))
                handle?(.moved(recognizer.travelX))
            case .changed:
                handle?(.moved(recognizer.travelX))
            case .ended, .cancelled, .failed:
                handle?(.ended(recognizer.travelX, recognizer.velocityX,
                               cancelled: recognizer.state != .ended))
            default:
                break
            }
        }

        /// The page's own pan lets go of this touch (switching it off and on
        /// again cancels it), so the page doesn't move under the swipe.
        private func stopScrolling(_ scroll: UIScrollView?) {
            guard let pan = scroll?.panGestureRecognizer else { return }
            pan.isEnabled = false
            pan.isEnabled = true
        }

        /// The page's pan runs alongside until this turns into a swipe (then
        /// it's cancelled), so neither waits for the other.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
        }
    }
}

extension View {
    /// The section words at the top and the edge swipes, in tabs mode.
    /// Put it on a section's first page (not on pages pushed on it, where
    /// the left edge is iOS's own swipe back).
    func deckSections(current: Int) -> some View {
        modifier(DeckSectionsModifier(current: current))
    }
}
