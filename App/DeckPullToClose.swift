import SwiftUI
import UIKit

// Pull down to close, like iOS's own sheets (Paul, 16 Nov 2026, after build
// 163: "swiping down on the player to close is still a bit too sticky and
// inconsistent"). The tab page used to close only when its scroll view was
// pulled more than 80 pt past the top and let go, watched through
// onScrollGeometryChange: hit and miss, as the scroll view's own bounce
// fought it. Now a UIKit pan on the player part of the page:
// - it only begins when the page is scrolled to the top and the finger is
//   going down (more down than sideways), and not on the dial or the
//   read-along words (they keep their own drags);
// - the page's own scrolling waits for it to decide (about 10 pt), so a
//   pull down moves the whole page with the finger instead of bouncing the
//   scroll view, and an upward drag scrolls as usual;
// - the finger is measured against the screen, not the moving page.
// The distances are in `DeckPullToClose`.
// Read along (Paul, 16 Nov 2026: "I can't pull down to close when the
// transcript is open"): the words filled most of the page and were kept
// out, so there was nowhere to pull. Now a pull may also start on the words
// when they're scrolled right up to their top (nothing above to scroll
// back to); otherwise a drag on them scrolls them as before. The rule is
// general: whatever scroll view is under the finger (the words, or the page
// itself) must be at its top, and it waits for the pull to decide.

/// The shared distances for pulling a player down to close it.
enum DeckPullToClose {
    /// A drag must go this far before it counts.
    static let start: CGFloat = 4
    /// Let go past this: close.
    static let distance: CGFloat = 64
    /// Or a downward flick this fast (points per second).
    static let speed: CGFloat = 300
    /// Or heading for this far by the time it would stop.
    static let predicted: CGFloat = 120

    static func closes(translation: CGFloat, velocity: CGFloat, predicted end: CGFloat) -> Bool {
        translation > distance || velocity > speed || end > predicted
    }
}

/// What the pull is doing.
enum DeckPullEvent {
    /// How far down the finger has gone (never below 0).
    case moved(CGFloat)
    /// Let go: close, or spring back.
    case ended(close: Bool)
}

/// The pan for the tab page.
/// `keepOut` holds the places where a pull may not start (the dial, the
/// scrub line, the volume), measured in `DeckPullDown.space`: a coordinate
/// space on the page's scroll content, so they don't change as it scrolls
/// (and nothing redraws while scrolling). A scroll view under the finger
/// (the read-along words) only lets a pull start when it's at its top.
struct DeckPullDown: UIGestureRecognizerRepresentable {
    static let space: String = "deckPullDownPage"

    var keepOut: [CGRect] = []
    let handle: (DeckPullEvent) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        context.coordinator.keepOut = keepOut
        context.coordinator.handle = handle
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Never switched on and off (that resets it mid-touch).
        context.coordinator.keepOut = keepOut
        context.coordinator.handle = handle
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.act(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var keepOut: [CGRect] = []
        var handle: ((DeckPullEvent) -> Void)?

        func act(_ pan: UIPanGestureRecognizer) {
            let down: CGFloat = pan.translation(in: nil).y
            switch pan.state {
            case .began, .changed:
                handle?(.moved(max(0, down)))
            case .ended:
                let velocity: CGFloat = pan.velocity(in: nil).y
                // Where it would end up if it carried on slowing (about as
                // SwiftUI's predictedEndTranslation works it out).
                let end: CGFloat = down + velocity * 0.2
                handle?(.ended(close: DeckPullToClose.closes(translation: down, velocity: velocity, predicted: end)))
            case .cancelled, .failed:
                handle?(.ended(close: false))
            default:
                break
            }
        }

        /// The page's scroll view: the nearest one above the recognizer.
        private func pageScroll(_ recognizer: UIGestureRecognizer) -> UIScrollView? {
            var up: UIView? = recognizer.view?.superview
            while let at = up {
                if let scroll = at as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 1 {
                    return scroll
                }
                up = at.superview
            }
            return nil
        }

        private func atTop(_ scroll: UIScrollView?) -> Bool {
            guard let scroll else { return true }
            return scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 2
        }

        /// The innermost scroll view under a point in the window: the
        /// read-along words when the finger is on them, else the page.
        private func scrollUnder(_ point: CGPoint, in window: UIWindow?) -> UIScrollView? {
            var hit: UIView? = window?.hitTest(point, with: nil)
            while let at = hit {
                if let scroll = at as? UIScrollView { return scroll }
                hit = at.superview
            }
            return nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let moved: CGPoint = pan.translation(in: nil)
            let velocity: CGPoint = pan.velocity(in: nil)
            let downward: Bool = (moved.y > 0 || velocity.y > 0) && abs(moved.y) >= abs(moved.x)
            let scroll: UIScrollView? = pageScroll(pan)
            guard downward, atTop(scroll) else { return false }
            // Where the finger went down, in the scroll content's points
            // (a scroll view's own coordinates are its content's).
            let now: CGPoint = pan.location(in: nil)
            let start = CGPoint(x: now.x - moved.x, y: now.y - moved.y)
            let point: CGPoint = scroll?.convert(start, from: nil) ?? start
            guard !keepOut.contains(where: { $0.contains(point) }) else { return false }
            // On the words: only when they're scrolled right up to the top.
            return atTop(scrollUnder(start, in: pan.view?.window))
        }

        /// The page's own scrolling (and the pager's sideways paging), and
        /// the read-along words' scrolling inside it, wait for this one to
        /// decide; it fails at once for anything that isn't a pull down from
        /// the top, so they carry on after about 10 pt.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard otherGestureRecognizer is UIPanGestureRecognizer,
                  let scroll = otherGestureRecognizer.view as? UIScrollView,
                  let view = gestureRecognizer.view else { return false }
            return view.isDescendant(of: scroll) || scroll.isDescendant(of: view)
        }
    }
}
