import SwiftUI
import PodcastCore

/// Haar, phase 3 (Paul, 13 Nov 2026; reworked to the prototype the same
/// night): getting around. The player is home; Library and Find fade in
/// over it in place (a quick fade since build 153; they slid before), with
/// a small floating dock (Now · Library · Find) on every screen instead of
/// iOS's tab bar. Read along and Up next open in place on the player.
/// From the player: swipe up for Up next, down for Find, left for Library.
/// In Read along: down or right goes back to the player, left to Library.
/// In Up next: down on the heading, or right, goes back. Every gesture has
/// a button too, and the dock closes Read along / Up next.
/// The layers stay made once opened, so each keeps its place.
struct HaarRoot: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    /// 0 Now, 1 Library, 2 Find (kept by `SchemedRoot`).
    @Binding var tab: Int
    /// Up next open in place on the player.
    @State private var showingUpNext = false
    /// Read along on the player (kept between launches).
    @State private var reading: Bool = UserDefaults.standard.bool(forKey: HaarRoot.readingKey)
    /// Made the first time they're opened, then kept.
    @State private var libraryMade = false
    @State private var findMade = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let dockRoom: CGFloat = 76
    static let readingKey = "haarReading"
    /// The layers' slide: the prototype's long, soft ease-out.
    static let slide: Animation = .smooth(duration: 0.4)
    /// Moving between Now, Library and Find: a quick cross-fade in place
    /// (Paul, 13 Nov 2026, after build 152; the layers used to slide).
    static let fade: Animation = .easeInOut(duration: 0.2)

    var body: some View {
        GeometryReader { geometry in
            let safeBottom: CGFloat = geometry.safeAreaInsets.bottom
            // The dock floats 24 points off the bottom edge (12 on iPhones
            // with a home button).
            let dockLift: CGFloat = safeBottom > 0 ? 24 : 12
            let nowRoom: CGFloat = max(12, dockLift + HaarDock.height + 12 - safeBottom)
            let fullHeight: CGFloat = geometry.size.height + geometry.safeAreaInsets.top + safeBottom
            ZStack {
                now(bottomRoom: nowRoom)
                if libraryMade || tab == 1 {
                    library(width: geometry.size.width)
                }
                if findMade || tab == 2 {
                    find(height: fullHeight)
                }
            }
            // Keeps iOS's volume bar from popping up over the app (the
            // Now screen shows its own volume line).
            .background(alignment: .topLeading) {
                HaarVolumeHUDHider()
                    .frame(width: 2, height: 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                HaarDock(tab: tab, go: go)
                    .offset(y: safeBottom - dockLift)
            }
        }
        // A show opens as a sheet over wherever you are.
        .sheet(item: Binding(get: { store.showSheet }, set: { store.showSheet = $0 })) { show in
            HaarShowSheet(show: show)
                .presentationDetents([.large])
        }
        // The player's / an episode page's show name: open that show.
        .onChange(of: store.revealShow) { _, show in
            guard let show else { return }
            store.revealShow = nil
            guard store.showSheet?.feedURL != show.feedURL else { return }
            store.showSheet = nil
            showingUpNext = false
            // Let any sheet that's closing (the episode page) go first.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                store.showSheet = show
            }
        }
        // "In Up Next · 2nd" on an episode page.
        .onChange(of: store.revealInUpNext) { _, id in
            if id != nil {
                openUpNext()
                store.revealInUpNext = nil
            }
        }
        .onChange(of: reading) { _, on in
            UserDefaults.standard.set(on, forKey: Self.readingKey)
        }
    }

    // MARK: Layers

    private func now(bottomRoom: CGFloat) -> some View {
        HaarNowView(showingUpNext: $showingUpNext, reading: $reading, openFind: { go(2) }, bottomRoom: bottomRoom)
            .contentShape(Rectangle())
            .gesture(nowSwipes, including: showingUpNext ? .subviews : .all)
            .opacity(tab == 0 ? 1 : 0)
            .allowsHitTesting(tab == 0)
            .accessibilityHidden(tab != 0)
    }

    private func library(width: CGFloat) -> some View {
        LibraryView()
            .environment(\.haarGoHome, { go(0) })
            // Room under the last row so it scrolls clear of the dock. Set as
            // a scroll margin (it reaches the lists inside the layer's
            // navigation stack, and pages pushed on it); the safe-area
            // padding used before didn't, so the last rows stayed stuck
            // behind the dock (Paul's build 151 screenshot, Shelves).
            .contentMargins(.bottom, Self.dockRoom + 12, for: .scrollContent)
            // See-through layer over the player (LibraryView draws its own
            // fog page inside, so this shows only where that doesn't reach).
            .background { HaarLayerBackground() }
            .opacity(tab == 1 ? 1 : 0)
            .allowsHitTesting(tab == 1)
            .accessibilityHidden(tab != 1)
            .onAppear { libraryMade = true }
    }

    private func find(height: CGFloat) -> some View {
        HaarFindView(close: { go(0) })
            // Same room under the last row as Library.
            .contentMargins(.bottom, Self.dockRoom + 12, for: .scrollContent)
            // A see-through layer: the player shows faintly behind.
            .background { HaarLayerBackground() }
            .opacity(tab == 2 ? 1 : 0)
            .allowsHitTesting(tab == 2)
            .accessibilityHidden(tab != 2)
            .onAppear { findMade = true }
    }

    // MARK: Moving about

    private var motion: Animation? { reduceMotion ? nil : Self.slide }

    /// The dock (and the layers' own ways back). Going anywhere also
    /// closes Up next and Read along on the player.
    private func go(_ next: Int) {
        guard next != tab || showingUpNext || reading else { return }
        // Instant between Now, Library and Find (Paul, 14 Nov 2026: "make
        // transitions instant instead of fade"); closing Up next / Read
        // along on the way keeps its morph only when staying on Now.
        withAnimation(next != tab ? nil : motion) {
            showingUpNext = false
            reading = false
            tab = next
        }
    }

    private func openUpNext() {
        if tab != 0 { tab = 0 }
        withAnimation(motion) { showingUpNext = true }
    }

    private func setReading(_ on: Bool) {
        withAnimation(motion) { reading = on }
    }

    /// On the player: up for Up next, down for Find, left for Library. In
    /// Read along: down (from the top) or right back to the player, left
    /// for Library. Controls on the page (the progress line, the words,
    /// buttons) keep their own touches. Up next has its own (on its
    /// heading), so this is off there.
    private var nowSwipes: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dx: CGFloat = value.translation.width
                let dy: CGFloat = value.translation.height
                let across: Bool = abs(dx) > abs(dy)
                if reading && player.nowPlaying != nil {
                    readingSwipe(dx: dx, dy: dy, across: across, startY: value.startLocation.y)
                } else if across {
                    if dx < -48 { go(1) }
                } else if dy < -48 {
                    openUpNext()
                } else if dy > 48 {
                    go(2)
                }
            }
    }

    private func readingSwipe(dx: CGFloat, dy: CGFloat, across: Bool, startY: CGFloat) {
        if across {
            if dx > 48 {
                setReading(false)
            } else if dx < -48 {
                go(1)
            }
        } else if dy > 48, startY < 160 {
            setReading(false)
        }
    }
}

/// Behind Library and Find: a pale mist, so the player shows faintly
/// through. A plain see-through colour, not a material: a live blur over
/// the whole screen made scrolling the layers feel low frame rate.
struct HaarLayerBackground: View {
    var body: some View {
        Color(red: 232 / 255, green: 234 / 255, blue: 233 / 255).opacity(0.9)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The floating dock: Now · Library · Find as icons with small words, the
/// one you're on in ink, with one small dot under it that slides between
/// them.
struct HaarDock: View {
    let tab: Int
    let go: (Int) -> Void
    @Namespace private var dot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 58
    private static let off = Color(hex: 0x626970)

    var body: some View {
        HStack(spacing: 0) {
            item("Now", icon: "waveform", index: 0)
            item("Library", icon: "square.stack", index: 1)
            item("Find", icon: "magnifyingglass", index: 2)
        }
        .padding(.horizontal, 7)
        .frame(width: 224, height: Self.height)
        .background { background }
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.55), value: tab)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 29, style: .continuous)
        // Plain white, no material: content scrolls under the dock, and a
        // live blur there redrew on every frame of a scroll.
        return shape.fill(Color.white.opacity(0.86))
            .overlay(shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
            .shadow(color: Color(hex: 0x1F2328).opacity(0.14), radius: 15, y: 12)
    }

    private func item(_ title: String, icon: String, index: Int) -> some View {
        let on: Bool = tab == index
        return Button { go(index) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: on ? .semibold : .regular))
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                ZStack {
                    if on {
                        Circle()
                            .fill(Theme.ink)
                            .matchedGeometryEffect(id: "dot", in: dot)
                    }
                }
                .frame(width: 4, height: 4)
            }
            .foregroundStyle(on ? Theme.ink : Self.off)
            .frame(width: 70, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
