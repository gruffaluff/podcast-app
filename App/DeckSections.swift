import SwiftUI
import UIKit

// Moving between the three main sections in tabs mode (Paul, 15 Nov 2026:
// "I need a better way to switch between find, your shows and discover",
// then "add it all and build"). Discover is part of Find (an empty search
// box shows New to you and the charts), so there are three sections: Tabs,
// Your shows and Find. Each one has the same row of words at the top, and
// a swipe that starts at the screen's left or right edge moves to the
// section before or after. Swiping along the bottom bar still moves
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

/// A thin strip at one edge of the screen that turns a swipe inwards into
/// "go to the next / previous section".
private struct DeckSectionEdge: View {
    let leading: Bool
    let move: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 20)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onEnded { (value: DragGesture.Value) in
                        let dx: CGFloat = value.translation.width
                        let dy: CGFloat = value.translation.height
                        let flick: CGFloat = value.predictedEndTranslation.width
                        guard abs(dx) > abs(dy) else { return }
                        let inward: Bool = leading ? (dx > 40 || flick > 160) : (dx < -40 || flick < -160)
                        if inward { move() }
                    }
            )
            .accessibilityHidden(true)
    }
}

private struct DeckSectionsModifier: ViewModifier {
    @Environment(\.deckSelectTab) private var selectTab
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @AppStorage(DeckHome.key) private var home: String = DeckHome.tabs
    let current: Int

    func body(content: Content) -> some View {
        if home != DeckHome.deck {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    DeckSectionSwitcher(current: current, tabCount: tabCount)
                }
                .overlay(alignment: .leading) {
                    if current > 0 {
                        DeckSectionEdge(leading: true) { go(current - 1) }
                    }
                }
                .overlay(alignment: .trailing) {
                    if current < 2 {
                        DeckSectionEdge(leading: false) { go(current + 1) }
                    }
                }
        } else {
            content
        }
    }

    private var tabCount: Int {
        let playing: String? = player.nowPlaying?.episodeID
        let queued: Int = store.queue.filter { $0.episode.id != playing }.count
        return queued + (playing == nil ? 0 : 1)
    }

    private func go(_ index: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { selectTab(index) }
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
