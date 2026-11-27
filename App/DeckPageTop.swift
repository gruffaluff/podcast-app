import SwiftUI
import SwiftData
import UIKit
import PodcastCore

// Option C, "two pages you swipe between" (Paul, 27 Nov 2026: "Yes let's
// build it", from https://claude.ai/artifact/9pjRqhQGZ5Fd2BZf9CKfCW, C1–C4).
// Just two pages, Up next and Your shows; no tab strip at the bottom, only
// the mini player. Switch with the Up next · Your shows pill at the top of
// both, or by dragging the mini player sideways (Paul, 27 Nov 2026: D from
// https://claude.ai/artifact/1dNa6zA1gtbdmsiUHHM4BE, keeping the pill too).
// Finding things: pull down on either page for one search over everything
// (there's no search box; it's hidden until you pull down); with nothing
// typed it's a quick Discover. Browsing for new shows lives at the foot of
// Your shows (`DeckDiscoverSection`, DeckFind.swift).

/// Opens the search (Find) with the keyboard up, from either page.
private struct DeckOpenSearchKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// Closes the search, back to the page it was opened from.
private struct DeckCloseSearchKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var deckOpenSearch: () -> Void {
        get { self[DeckOpenSearchKey.self] }
        set { self[DeckOpenSearchKey.self] = newValue }
    }

    var deckCloseSearch: () -> Void {
        get { self[DeckCloseSearchKey.self] }
        set { self[DeckCloseSearchKey.self] = newValue }
    }
}

/// The top of both pages: the Poddeck mark and Settings, and the Up next ·
/// Your shows switch. The same on both, so nothing jumps when you switch.
/// The search is hidden until you pull the page down (Paul, 27 Nov 2026).
struct DeckPageTop: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.deckSelectTab) private var selectTab
    @Query(sort: \Podcast.title) private var savedShows: [Podcast]
    /// 0 Up next, 1 Your shows.
    let current: Int
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 12) {
            brand
            // Both ways to switch (Paul, 27 Nov 2026): this pill at the top,
            // and dragging the mini player sideways at the bottom.
            DeckPageSwitch(current: current, upNext: upNextCount,
                           shows: savedShows.followedOnly.count, select: select)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .sheet(isPresented: $showingSettings) { DeckSettingsView() }
        // Demo mode only (Screenshots workflow): open on Settings.
        .task {
            guard current == 0, DemoMode.screen == .settings else { return }
            try? await Task.sleep(for: .milliseconds(600))
            showingSettings = true
        }
    }

    private var brand: some View {
        HStack(spacing: 8) {
            DeckMark(size: 30)
            Text("Poddeck")
                .font(Theme.outfit(26, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 6)
        .frame(height: 44)
    }

    /// Up next's length, counting the episode playing.
    private var upNextCount: Int {
        let playing: String? = player.nowPlaying?.episodeID
        let queued: Int = store.queue.filter { $0.episode.id != playing }.count
        return queued + (playing == nil ? 0 : 1)
    }

    /// Switches at once; tapping the side already showing goes back to its
    /// first screen (Your shows: closes a show page).
    private func select(_ index: Int) {
        if index == current {
            NotificationCenter.default.post(name: .deckPageToStart, object: index)
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { selectTab(index) }
    }
}

/// "Up next · 8 | Your shows · 12": the side showing is a white capsule.
/// Tap a side, or swipe along it.
struct DeckPageSwitch: View {
    let current: Int
    let upNext: Int
    let shows: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            side(upNext > 0 ? "Up next · \(upNext)" : "Up next", index: 0)
            side(shows > 0 ? "Your shows · \(shows)" : "Your shows", index: 1)
        }
        .padding(3)
        .background(Capsule().fill(Theme.ink.opacity(0.07)))
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            let dx: CGFloat = value.translation.width
            guard abs(dx) > abs(value.translation.height), abs(dx) > 30 else { return }
            let target: Int = dx < 0 ? 1 : 0
            if target != current { select(target) }
        })
    }

    private func side(_ title: String, index: Int) -> some View {
        let on: Bool = index == current
        return Button { select(index) } label: {
            Text(title)
                .font(Theme.outfit(14, on ? .bold : .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(on ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if on {
                        Capsule().fill(Theme.surface)
                            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                }
                .contentShape(Capsule())
                .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Pull the page down past its top to open the search (option C). The
/// pull also checks for new episodes, as pull to refresh did (at most
/// once every two minutes).
struct DeckPullToSearch: ViewModifier {
    @Environment(LibraryStore.self) private var store
    @Environment(\.deckOpenSearch) private var openSearch
    @State private var touching = false
    @State private var armed = true

    /// How far past the top the page must be pulled.
    private static let distance: CGFloat = 90

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                touching = phase == .interacting || phase == .tracking
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { (geometry: ScrollGeometry) -> CGFloat in
                geometry.contentOffset.y + geometry.contentInsets.top
            }, action: { (_: CGFloat, offset: CGFloat) in
                pulled(offset)
            })
    }

    private func pulled(_ offset: CGFloat) {
        if offset > -20 { armed = true }
        // Only while the finger is on the page: a flick that bounces past
        // the top doesn't count.
        guard armed, touching, offset < -Self.distance else { return }
        armed = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        openSearch()
        let last: Date = store.lastChecked ?? .distantPast
        if Date().timeIntervalSince(last) > 120 {
            Task { await store.refreshAll() }
        }
    }
}

extension View {
    func deckPullToSearch() -> some View { modifier(DeckPullToSearch()) }
}
