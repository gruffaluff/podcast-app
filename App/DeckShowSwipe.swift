import SwiftUI
import UIKit

// Deck (Paul, 14 Nov 2026): full-card swipes on the show page's episodes
// (prototype: "swipe right: a little = next, far = bottom"). Like
// `posterSwipe` (Poster.swift), with a second, further line on the right:
// let go past the first for `leading` (Play next), past the second for
// `leadingFar` (Play last). Left is `trailing` (Played). A copy rather than
// a change to PosterSwipe, so every existing swipe stays as it is.

extension View {
    func deckShowSwipe(leading: PosterSwipeAction?, leadingFar: PosterSwipeAction?,
                   trailing: PosterSwipeAction?, radius: CGFloat = 20) -> some View {
        modifier(DeckShowSwipe(leading: leading, leadingFar: leadingFar, trailing: trailing, radius: radius))
    }
}

private struct DeckShowSwipe: ViewModifier {
    let leading: PosterSwipeAction?
    let leadingFar: PosterSwipeAction?
    let trailing: PosterSwipeAction?
    let radius: CGFloat
    @State private var offset: CGFloat = 0
    /// 0 none, 1 past the first line, 2 past the far line (right only).
    @State private var stage = 0
    /// Which side's action shows, fixed for the whole swipe and its return.
    @State private var side: CGFloat = 0

    private static let trigger: CGFloat = 80
    private static let farTrigger: CGFloat = 190

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { block }
            .gesture(DeckShowPan(isEnabled: leading != nil || trailing != nil, changed: moved, ended: released))
            .accessibilityActions {
                if let leading { Button(leading.title, action: leading.action) }
                if let leadingFar { Button(leadingFar.title, action: leadingFar.action) }
                if let trailing { Button(trailing.title, action: trailing.action) }
            }
    }

    private func moved(_ translation: CGFloat) {
        var x: CGFloat = translation
        if side == 0, x != 0 { side = x > 0 ? 1 : -1 }
        if side > 0 { x = max(0, x) } else if side < 0 { x = min(0, x) }
        if x > 0, leading == nil { x = 0 }
        if x < 0, trailing == nil { x = 0 }
        let limit: CGFloat = (x > 0 && leadingFar != nil) ? Self.farTrigger : Self.trigger
        if abs(x) > limit { x = (x > 0 ? 1 : -1) * (limit + (abs(x) - limit) * 0.35) }
        offset = x
        update(stage: stageFor(x))
    }

    private func stageFor(_ x: CGFloat) -> Int {
        if x >= Self.farTrigger, leadingFar != nil { return 2 }
        return abs(x) >= Self.trigger ? 1 : 0
    }

    private func update(stage new: Int) {
        guard new != stage else { return }
        if new > stage { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        stage = new
    }

    private func released(_ velocity: CGFloat) {
        let flick: Bool = abs(offset) > 36 && abs(velocity) > 700 && (velocity > 0) == (offset > 0)
        let reached: Int = max(stage, flick ? 1 : 0)
        let fire: PosterSwipeAction? = chosen(reached)
        stage = 0
        guard let fire else {
            withAnimation(.spring(duration: 0.3)) { offset = 0 } completion: { side = 0 }
            return
        }
        let direction: CGFloat = offset > 0 ? 1 : -1
        withAnimation(.easeOut(duration: 0.18)) { offset = direction * 480 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(LibraryStore.listChange) { fire.action() }
            withAnimation(.spring(duration: 0.35)) { offset = 0 } completion: { side = 0 }
        }
    }

    private func chosen(_ reached: Int) -> PosterSwipeAction? {
        guard reached > 0 else { return nil }
        if offset < 0 { return trailing }
        return reached == 2 ? (leadingFar ?? leading) : leading
    }

    @ViewBuilder private var block: some View {
        let action: PosterSwipeAction? = side > 0 ? (stage == 2 ? leadingFar : leading) : (side < 0 ? trailing : nil)
        if let action {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(action.colour)
                .overlay(alignment: side > 0 ? .leading : .trailing) { label(action) }
                .accessibilityHidden(true)
        }
    }

    private func label(_ action: PosterSwipeAction) -> some View {
        HStack(spacing: 6) {
            Image(systemName: action.icon)
                .font(.system(size: 14, weight: .bold))
            Text(action.title)
                .font(Theme.outfit(13, .bold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 18)
        .scaleEffect(stage > 0 ? 1.08 : 1)
    }
}
