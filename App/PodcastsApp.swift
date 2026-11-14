import SwiftUI
import SwiftData
import UIKit

@main
struct PodcastsApp: App {
    private let container: ModelContainer
    @State private var store: LibraryStore
    @State private var player: PlayerModel
    @State private var downloads: DownloadManager
    @State private var transcripts: TranscriptService
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Self.styleSystemBars()
        // A roomier web cache for feeds and images (artwork has its own
        // cache too; see ArtworkImageCache).
        URLCache.shared = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        SettingsSync.shared.start()
        let container = Self.makeContainer()
        let store = LibraryStore(context: container.mainContext)
        self.container = container
        _store = State(initialValue: store)
        let player = PlayerModel(store: store)
        AppServices.store = store
        AppServices.player = player
        _player = State(initialValue: player)
        WidgetSync.shared.start(player: player, store: store)
        _downloads = State(initialValue: DownloadManager(store: store))
        let transcripts = TranscriptService(store: store)
        transcripts.registerBackgroundTask()
        BackgroundRefresh.register(store: store)
        _transcripts = State(initialValue: transcripts)
    }

    var body: some Scene {
        WindowGroup {
            SchemedRoot()
                .environment(store)
                .environment(player)
                .environment(downloads)
                .environment(transcripts)
        }
        .modelContainer(container)
    }

    /// Fraunces Soft titles (Paul's type pick) and plain tab labels.
    private static func styleSystemBars() {
        // Follows the scheme's light / dark (Night is dark).
        let ink = UIColor.label
        // Haar: big titles in SF Rounded bold.
        let plainLarge = UIFont.systemFont(ofSize: 34, weight: .bold)
        var largeFont: UIFont = plainLarge
        if Theme.isDeck {
            largeFont = UIFont(name: "Outfit-ExtraBold", size: 34) ?? plainLarge
        } else if Theme.isHaar {
            largeFont = UIFont(descriptor: plainLarge.fontDescriptor.withDesign(.rounded) ?? plainLarge.fontDescriptor, size: 34)
        }
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: largeFont, .foregroundColor: ink
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: ink
        ]
        UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 10, weight: .semibold)], for: .normal)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Podcast.self, PodcastEpisode.self, UpNextEntry.self, Bookmark.self, ListeningLog.self])
        // `.automatic` syncs with iCloud when the app has the iCloud
        // entitlement (signed builds) and keeps everything on the phone
        // otherwise (e.g. the unsigned cloud test build).
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)) {
            return container
        }
        // If iCloud can't be set up, keep using the library on the phone.
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)) {
            return container
        }
        // If the saved library can't be opened, still start (with nothing saved)
        // rather than crash on launch.
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}

struct RootView: View {
    /// Touch and hold the app icon (see QuickActions).
    private func handleQuickAction(_ action: String) {
        switch action {
        case QuickActions.playUpNext:
            tab = 0
            if let first = store.queue.first, let episode = store.episode(first.episode.id) {
                player.play(episode)
                showingPlayer = true
            }
        case QuickActions.search:
            tab = (Theme.isHaar || Theme.isDeck) ? 2 : 3
        default:
            tab = 0
        }
    }

    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.scenePhase) private var scenePhase
    /// Kept by `SchemedRoot`, so a redraw for a colour change doesn't
    /// close the player or change tab.
    @Binding var showingPlayer: Bool
    @Binding var tab: Int
    @State private var quickActions = QuickActions.shared
    @State private var showingWelcome = false

    /// Haar (phase 3): the player as home with Library and Find as layers
    /// and a floating dock. Every other scheme: iOS's tab bar with the
    /// mini player above it (Native warm).
    @ViewBuilder private var content: some View {
        if Theme.isDeck {
            // Deck (Paul, 14 Nov 2026): Up next · Shows · Find in a
            // floating pill, the player full screen over everything.
            DeckRoot(tab: $tab, showingPlayer: $showingPlayer)
                .onAppear { if tab > 2 { tab = 2 } }
        } else if Theme.isHaar {
            HaarRoot(tab: $tab)
                .onAppear { if tab > 2 { tab = 2 } }
        } else {
            TabView(selection: $tab) {
                Tab("Up Next", systemImage: "list.bullet", value: 0) { UpNextView() }
                Tab("Library", systemImage: "square.stack", value: 1) { LibraryView() }
                Tab("Discover", systemImage: "safari", value: 2) { DiscoverView() }
                Tab(value: 3, role: .search) { SearchView() }
            }
            .tabViewBottomAccessory {
                NowPlayingBar { showingPlayer = true }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }

    var body: some View {
        // Native warm (Paul, 11 Nov 2026): iOS's own tab bar, with the
        // mini player sitting above it as Apple Music does (the tab view's
        // bottom accessory). iOS lays the lists out round both, so nothing
        // overlaps a list (the dead spots of builds 140-141 came from our
        // own dock over iOS's hidden bar).
        content
        // Haar: this root page's fog is the one that drifts; every page,
        // layer and sheet inside draws its fog standing still, so only one
        // fog moves on screen (smoother scrolling).
        .environment(\.haarFogBehind, true)
        // Undo and No internet float above the tab bar (or Haar's dock)
        // while they show.
        .overlay(alignment: Theme.isHaar ? .top : .bottom) {
            // Deck: just above the pill (and the mini player).
            // Haar (prototype): toasts sit near the top, under the top bar.
            VStack(spacing: 6) {
                OfflineBar()
                UndoBar()
            }
            .padding(.horizontal, Theme.isHaar ? 20 : 12)
            .padding(.top, Theme.isHaar ? 64 : 0)
            .padding(.bottom, Theme.isHaar ? 0 : (Theme.isDeck ? 156 : 128))
        }
        .haarPage()
        .onChange(of: quickActions.pending, initial: true) { _, action in
            guard let action else { return }
            quickActions.pending = nil
            handleQuickAction(action)
        }
        .tint(Theme.ink)
        // The player fills the whole screen (Paul: no page showing through
        // at the top); swipe down to close it.
        .fullScreenCover(isPresented: Theme.isHaar ? Binding.constant(false) : $showingPlayer) {
            if Theme.isDeck { DeckPlayerView() } else { NowPlayingView() }
        }
        // Haar: the player is home, so "open the player" goes home.
        .onChange(of: showingPlayer) { _, open in
            guard open, Theme.isHaar else { return }
            showingPlayer = false
            tab = 0
        }
        .sheet(item: Binding(get: { store.showSheet == nil ? store.notesEpisode : nil },
                             set: { store.notesEpisode = $0 })) { episode in
            EpisodeNotesView(episode: episode)
        }
        .sheet(isPresented: $showingWelcome) {
            WelcomeView { tab = 2 }
        }
        .task {
            // First open with nothing followed: say what the app is.
            guard !UserDefaults.standard.bool(forKey: WelcomeView.seenKey) else { return }
            if ((try? store.context.fetchCount(FetchDescriptor<Podcast>())) ?? 0) == 0 {
                showingWelcome = true
            } else {
                UserDefaults.standard.set(true, forKey: WelcomeView.seenKey)
            }
        }
        .transcribeExplainer(enabled: !showingPlayer && !showingWelcome)
        // A show name / artwork in the player or on an episode page: close
        // what's open and go to the show in Library.
        .onChange(of: store.revealShow) { _, show in
            guard show != nil else { return }
            store.notesEpisode = nil
            // Haar: HaarRoot opens the show as a sheet where you are.
            guard !Theme.isHaar else { return }
            showingPlayer = false
            tab = 1
            // Library pushes the show page; clear the request once it has.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                store.revealShow = nil
            }
        }
        // The app's accent follows the episode playing (Theme.accentFill).
        .onChange(of: player.nowPlaying?.artworkURL, initial: true) { _, url in
            // A soft half-second fade to the new colour (Paul, 11 Nov 2026:
            // nothing should jump colour).
            Task {
                await ArtworkColors.shared.load(url)
                let colour = url.flatMap { ArtworkColors.shared.background(for: $0) }
                withAnimation(.easeInOut(duration: 0.5)) { AccentColour.shared.colour = colour }
            }
        }
        // Every followed show's colour is measured ahead, so a show's page
        // opens in its own colour (it's fixed when the page opens).
        .task { await store.preloadShowColours() }
        // "In Up Next · 2nd" on an episode page: close what's open, go to Up Next.
        .onChange(of: store.revealInUpNext) { _, id in
            guard id != nil else { return }
            store.notesEpisode = nil
            showingPlayer = false
            tab = 0
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                AppBadge.update(store: store)
                WidgetSync.shared.flush()
                transcripts.scheduleBackgroundWork()
                BackgroundRefresh.schedule()
            }
            // Check feeds when the app opens, at most once an hour.
            guard phase == .active else { return }
            AppBadge.appOpened(store: store)
            store.tidyAfterSync()
            store.cleanUpPlayedDownloads()
            transcripts.prepareUpNext()
            Task {
                if store.lastChecked.map({ Date().timeIntervalSince($0) > 3600 }) ?? true {
                    await store.refreshAll()
                }
            }
        }
    }
}

/// Draws the app in the chosen colour scheme. Changing the scheme redraws
/// everything (open sheets close), since every colour comes from it.
/// "Auto" (the default) follows the iPhone: Sand in light, Night in dark.
private struct SchemedRoot: View {
    @AppStorage(ColourScheme.key) private var setting = ColourScheme.auto
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    /// The iPhone's light / dark, followed only while the app is in use:
    /// when you leave the app, iOS briefly draws it in both looks for the
    /// app switcher, and following that redrew everything and closed the
    /// player (Paul, build 135).
    @State private var systemDark: Bool?
    /// Here, not in RootView, so a redraw keeps them.
    @State private var showingPlayer = false
    @State private var tab = 0

    var body: some View {
        let dark = systemDark ?? (systemScheme == .dark)
        let chosen = ColourScheme.resolve(setting, systemDark: dark)
        // Set before anything below is drawn, so every Theme colour matches.
        let _ = ColourScheme.use(chosen)
        RootView(showingPlayer: $showingPlayer, tab: $tab)
            .id(chosen)
            .onChange(of: systemScheme, initial: true) { _, scheme in
                if scenePhase == .active || systemDark == nil { systemDark = scheme == .dark }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { systemDark = systemScheme == .dark }
            }
            // Auto leaves light / dark to the iPhone; a picked scheme sets it.
            .preferredColorScheme(setting == ColourScheme.auto ? nil : (chosen.isDark ? .dark : .light))
    }
}
