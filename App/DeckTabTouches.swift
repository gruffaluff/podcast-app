import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// One touch handler per tab card (Paul, 16 Nov 2026, build 162: "Hold and
// drag isn't working at all"). In 162 each card had three gestures that
// competed for the same finger: a SwiftUI Button (tap to open), a sideways
// pan (swipe to close) and a long press on the cell around them. The long
// press was outside the button, so SwiftUI made it wait for the button's
// tap to fail, and a still finger never makes a tap fail: the hold could
// never begin (let go and the tab simply opened). It also made every pan,
// the page's scrolling included, wait for it.
//
// Now one UIKit recognizer owns the whole touch and decides once what it is:
// - let go before 0.35 s without moving: a tap;
// - still for 0.35 s: a hold (lift the tab, or its menu), then it keeps
//   reporting where the finger is until it lifts, and scrolls the page when
//   the finger nears the top or bottom;
// - moved more than 8 pt first, clearly sideways: a swipe;
// - moved more than 8 pt first any other way: not ours, it fails at once
//   and the page scrolls as usual (nothing waits for it).

/// What a touch on a tab card turned out to be.
enum DeckTabTouch {
    case tap
    case holdBegan
    /// How far the finger has gone since the hold (against the screen), and
    /// how far the page has scrolled by itself since.
    case holdMoved(CGSize, CGFloat)
    case holdEnded(cancelled: Bool)
    /// How far the finger has gone sideways (against the screen).
    case swipeMoved(CGFloat)
    /// Sideways travel and speed (points per second) as the finger lifts.
    case swipeEnded(CGFloat, CGFloat, cancelled: Bool)
}

/// The recognizer: tap, hold or swipe, decided by the first 8 pt or 0.35 s.
final class DeckTabTouchRecognizer: UIGestureRecognizer {
    enum Mode { case pending, tap, hold, swipe }

    static let holdDelay: TimeInterval = 0.35
    static let slop: CGFloat = 8

    private(set) var mode: Mode = .pending
    /// Where the finger went down and is now, in window points.
    private(set) var start: CGPoint = .zero
    private(set) var current: CGPoint = .zero
    private(set) var velocityX: CGFloat = 0
    /// The page the card sits in.
    private(set) weak var scrollView: UIScrollView?

    private weak var finger: UITouch?
    private var lastX: CGFloat = 0
    private var lastTime: TimeInterval = 0
    /// Changes whenever a waiting hold should no longer fire.
    private var holdToken: Int = 0

    var travel: CGSize { CGSize(width: current.x - start.x, height: current.y - start.y) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if finger != nil || touches.count != 1 {
            // A second finger: give up if nothing has started, else ignore it.
            if mode == .pending {
                state = .failed
            } else {
                for touch in touches where touch !== finger { ignore(touch, for: event) }
            }
            return
        }
        guard let touch = touches.first else { return }
        finger = touch
        start = touch.location(in: nil)
        current = start
        lastX = start.x
        lastTime = touch.timestamp
        scrollView = findScrollView()
        // A touch that stops the page scrolling isn't a tap on a tab.
        if let scrollView, scrollView.isDecelerating {
            state = .failed
            return
        }
        holdToken += 1
        let token: Int = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDelay) { [weak self] in
            guard let self, self.holdToken == token else { return }
            self.holdFired()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        track(touch)
        switch mode {
        case .pending:
            let moved: CGSize = travel
            guard hypot(moved.width, moved.height) > Self.slop else { return }
            holdToken += 1
            if abs(moved.width) > abs(moved.height) * 1.2 {
                mode = .swipe
                state = .began
            } else {
                state = .failed
            }
        case .hold, .swipe:
            state = .changed
        case .tap:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        holdToken += 1
        // A finger that stopped before lifting isn't a flick.
        if touch.timestamp - lastTime > 0.1 { velocityX = 0 }
        current = touch.location(in: nil)
        switch mode {
        case .pending:
            mode = .tap
            state = .ended
        case .hold, .swipe:
            state = .ended
        case .tap:
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        guard let touch = finger, touches.contains(touch) else { return }
        holdToken += 1
        state = mode == .pending ? .failed : .cancelled
    }

    override func reset() {
        super.reset()
        holdToken += 1
        mode = .pending
        finger = nil
        velocityX = 0
        scrollView = nil
    }

    private func holdFired() {
        guard state == .possible, mode == .pending, finger != nil else { return }
        mode = .hold
        state = .began
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

    /// The scroll view above the card: up from the recognizer's view, else
    /// up from whatever is under the finger.
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

/// The tab card's one gesture. The handler gets every event; the card
/// keeps taps and swipes and passes holds to the grid.
struct DeckTabTouches: UIGestureRecognizerRepresentable {
    let handle: (DeckTabTouch) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> DeckTabTouchRecognizer {
        let recognizer = DeckTabTouchRecognizer()
        recognizer.delegate = context.coordinator
        context.coordinator.handle = handle
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: DeckTabTouchRecognizer, context: Context) {
        // Never toggled on and off (that resets it mid-touch): the handler
        // decides what to do with each event.
        context.coordinator.handle = handle
    }

    func handleUIGestureRecognizerAction(_ recognizer: DeckTabTouchRecognizer, context: Context) {
        context.coordinator.act(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var handle: ((DeckTabTouch) -> Void)?
        private weak var recognizer: DeckTabTouchRecognizer?
        private weak var scroll: UIScrollView?
        private var startOffset: CGFloat = 0
        private var link: CADisplayLink?

        /// How far the page has scrolled by itself since the hold began.
        private var shift: CGFloat {
            guard let scroll else { return 0 }
            return scroll.contentOffset.y - startOffset
        }

        func act(_ recognizer: DeckTabTouchRecognizer) {
            let state: UIGestureRecognizer.State = recognizer.state
            switch recognizer.mode {
            case .tap:
                if state == .ended { handle?(.tap) }
            case .hold:
                hold(recognizer, state: state)
            case .swipe:
                swipe(recognizer, state: state)
            case .pending:
                break
            }
        }

        private func hold(_ recognizer: DeckTabTouchRecognizer, state: UIGestureRecognizer.State) {
            switch state {
            case .began:
                self.recognizer = recognizer
                scroll = recognizer.scrollView
                startOffset = scroll?.contentOffset.y ?? 0
                stopScrolling()
                startAutoScroll()
                handle?(.holdBegan)
            case .changed:
                handle?(.holdMoved(recognizer.travel, shift))
            case .ended, .cancelled, .failed:
                stopAutoScroll()
                handle?(.holdEnded(cancelled: state != .ended))
            default:
                break
            }
        }

        private func swipe(_ recognizer: DeckTabTouchRecognizer, state: UIGestureRecognizer.State) {
            switch state {
            case .began:
                scroll = recognizer.scrollView
                stopScrolling()
                handle?(.swipeMoved(recognizer.travel.width))
            case .changed:
                handle?(.swipeMoved(recognizer.travel.width))
            case .ended, .cancelled, .failed:
                handle?(.swipeEnded(recognizer.travel.width, recognizer.velocityX, cancelled: state != .ended))
            default:
                break
            }
        }

        /// The page's own pan lets go of this touch (switching it off and on
        /// again cancels it), so a lifted or swiped tab never scrolls it.
        private func stopScrolling() {
            guard let pan = scroll?.panGestureRecognizer else { return }
            pan.isEnabled = false
            pan.isEnabled = true
        }

        // MARK: Scrolling while a tab is lifted

        private func startAutoScroll() {
            stopAutoScroll()
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        private func stopAutoScroll() {
            link?.invalidate()
            link = nil
        }

        /// Within 90 pt of the page's visible top or bottom the page scrolls
        /// that way, faster the nearer the edge (up to 12 pt a frame).
        @objc private func tick() {
            guard let recognizer, recognizer.mode == .hold, let scroll, scroll.window != nil else { return }
            let frame: CGRect = scroll.convert(scroll.bounds, to: nil)
            let insets: UIEdgeInsets = scroll.adjustedContentInset
            let top: CGFloat = frame.minY + insets.top
            let bottom: CGFloat = frame.maxY - insets.bottom
            let y: CGFloat = recognizer.current.y
            let zone: CGFloat = 90
            var step: CGFloat = 0
            if y < top + zone {
                step = -(3 + 9 * min(1, (top + zone - y) / zone))
            } else if y > bottom - zone {
                step = 3 + 9 * min(1, (y - (bottom - zone)) / zone)
            }
            guard step != 0 else { return }
            let lowest: CGFloat = -insets.top
            let highest: CGFloat = max(lowest, scroll.contentSize.height - scroll.bounds.height + insets.bottom)
            let next: CGFloat = min(highest, max(lowest, scroll.contentOffset.y + step))
            guard abs(next - scroll.contentOffset.y) > 0.5 else { return }
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: next), animated: false)
            handle?(.holdMoved(recognizer.travel, shift))
        }

        // MARK: Delegate

        /// The page's pan may run alongside until this touch turns out to be
        /// a hold or a swipe (then it's cancelled), so neither waits for the
        /// other.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
        }
    }
}
