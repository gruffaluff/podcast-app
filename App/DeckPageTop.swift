import SwiftUI
import SwiftData
import UIKit
import PodcastCore

// Option C, "two pages you swipe between" (Paul, 27 Nov 2026: "Yes let's
// build it", from https://claude.ai/artifact/9pjRqhQGZ5Fd2BZf9CKfCW, C1–C4).
// Just two pages, Up next and Your shows; no tab strip at the bottom, only
// the mini player. Drag the mini player sideways to flip between them, or
// tap the two dots under it (Paul, 27 Nov 2026: "swipe on mini player", D
// from https://claude.ai/artifact/1dNa6zA1gtbdmsiUHHM4BE). Finding things:
// pull down on either page (or tap the search box) for one search over everything; with nothing typed it's a quick
// Discover. Browsing for new shows lives at the foot of Your shows
// (`DeckDiscoverSection`, DeckFind.swift).

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

/// The top of both pages: the Poddeck mark and Settings, and the search
/// box. The same on both, so nothing jumps when you switch.
struct DeckPageTop: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.deckOpenSearch) private var openSearch
    /// 0 Up next, 1 Your shows.
    let current: Int
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 12) {
            brand
            // The switch went to the mini player (Paul, 27 Nov 2026: "swipe
            // on mini player", D): drag it sideways, or tap the dots under it.
            searchBox
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

    /// Looks like a search box; tapping it opens the search with the
    /// keyboard up (as pulling the page down does).
    private var searchBox: some View {
        Button(action: openSearch) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .regular))
                Text("Search, or pull down")
                    .font(Theme.outfit(15, .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search shows, episodes and things people said")
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
