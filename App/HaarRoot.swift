import SwiftUI
import PodcastCore

/// Haar, phase 3 (Paul, 13 Nov 2026): getting around. The player is home;
/// Library and Find are layers over it, with a small floating dock (Now ·
/// Library · Find) on every screen instead of iOS's tab bar.
/// From home: swipe up for Up next, down for Find, left for Library.
/// Back the way you came: the dock, Find's handle (swipe it up), and Up
/// next is a sheet you swipe down. Every gesture has a button too.
/// The layers stay made once opened, so each keeps its place.
struct HaarRoot: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    /// 0 Now, 1 Library, 2 Find (kept by `SchemedRoot`).
    @Binding var tab: Int
    @State private var showingUpNext = false
    /// Made the first time they're opened, then kept.
    @State private var libraryMade = false
    @State private var findMade = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let dockRoom: CGFloat = 76

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HaarNowView(openUpNext: { showingUpNext = true }, openFind: { go(2) }, bottomRoom: Self.dockRoom)
                    .contentShape(Rectangle())
                    .gesture(homeSwipes)
                    .allowsHitTesting(tab == 0)
                    .accessibilityHidden(tab != 0)
                if libraryMade || tab == 1 {
                    LibraryView()
                        .safeAreaPadding(.bottom, Self.dockRoom - 10)
                        .offset(x: tab == 1 ? 0 : geometry.size.width + 30)
                        .opacity(tab == 1 ? 1 : 0)
                        .allowsHitTesting(tab == 1)
                        .accessibilityHidden(tab != 1)
                        .onAppear { libraryMade = true }
                }
                if findMade || tab == 2 {
                    HaarFindView(close: { go(0) })
                        .safeAreaPadding(.bottom, Self.dockRoom - 10)
                        .haarPage()
                        .offset(y: tab == 2 ? 0 : -(geometry.size.height + 60))
                        .opacity(tab == 2 ? 1 : 0)
                        .allowsHitTesting(tab == 2)
                        .accessibilityHidden(tab != 2)
                        .onAppear { findMade = true }
                }
            }
            .overlay(alignment: .bottom) {
                HaarDock(tab: tab, go: go)
                    .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $showingUpNext) {
            UpNextSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // "In Up Next · 2nd" on an episode page.
        .onChange(of: store.revealInUpNext) { _, id in
            if id != nil {
                showingUpNext = true
                store.revealInUpNext = nil
            }
        }
    }

    private func go(_ next: Int) {
        guard next != tab else { return }
        if reduceMotion {
            tab = next
        } else {
            withAnimation(.spring(duration: 0.45, bounce: 0.08)) { tab = next }
        }
    }

    /// Up for Up next, down for Find, left for Library. Controls on the
    /// page (the waveform, read-along, buttons) keep their own touches.
    private var homeSwipes: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                let dx: CGFloat = value.translation.width
                let dy: CGFloat = value.translation.height
                if abs(dy) > abs(dx) {
                    if dy < -60 {
                        showingUpNext = true
                    } else if dy > 60 {
                        go(2)
                    }
                } else if dx < -60 {
                    go(1)
                }
            }
    }
}

/// The floating dock: Now · Library · Find as icons with small words, the
/// one you're on in ink with a dot under it. Away from Now, a small play /
/// pause sits on the left while something's playing.
struct HaarDock: View {
    @Environment(PlayerModel.self) private var player
    let tab: Int
    let go: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if tab != 0, player.nowPlaying != nil {
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                .transition(.scale.combined(with: .opacity))
            }
            item("Now", icon: "waveform", index: 0)
            item("Library", icon: "square.stack", index: 1)
            item("Find", icon: "magnifyingglass", index: 2)
        }
        .padding(.horizontal, 10)
        .frostedCard(radius: 30)
        .animation(.easeOut(duration: 0.2), value: tab)
    }

    private func item(_ title: String, icon: String, index: Int) -> some View {
        let on: Bool = tab == index
        return Button { go(index) } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: on ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 10, weight: on ? .semibold : .medium))
                Circle()
                    .fill(on ? Theme.ink : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundStyle(on ? Theme.ink : Theme.muted)
            .frame(width: 70, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
