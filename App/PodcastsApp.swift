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

    /// Big heavy condensed titles and plain tab labels.
    private static func styleSystemBars() {
        // Follows the scheme's light / dark (Night is dark).
        let ink = UIColor.label
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 40, weight: .black, width: .condensed), .foregroundColor: ink
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .heavy, width: .condensed), .foregroundColor: ink
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
            tab = 3
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

    var body: some View {
        TabView(selection: $tab) {
            UpNextView()
                .miniPlayer($showingPlayer, tab: $tab)
                .tabItem { Label("Up Next", systemImage: "list.bullet") }
                .tag(0)
            LibraryView()
                .miniPlayer($showingPlayer, tab: $tab)
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(1)
            DiscoverView()
                .miniPlayer($showingPlayer, tab: $tab)
                .tabItem { Label("Discover", systemImage: "safari") }
                .tag(2)
            SearchView()
                .miniPlayer($showingPlayer, tab: $tab)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(3)
        }
        .onChange(of: quickActions.pending, initial: true) { _, action in
            guard let action else { return }
            quickActions.pending = nil
            handleQuickAction(action)
        }
        .tint(Theme.ink)
        // The player fills the whole screen (Paul: no page showing through
        // at the top); close with its ⌄ key or a swipe down on the top area.
        .fullScreenCover(isPresented: $showingPlayer) {
            NowPlayingView()
        }
        .sheet(item: Binding(get: { store.notesEpisode }, set: { store.notesEpisode = $0 })) { episode in
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
            showingPlayer = false
            tab = 1
            // Library pushes the show page; clear the request once it has.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                store.revealShow = nil
            }
        }
        // "In Up Next · 2nd" on an episode page: close what's open, go to Up Next.
        .onChange(of: store.revealInUpNext) { _, id in
            guard id != nil else { return }
            store.notesEpisode = nil
            showingPlayer = false
            tab = 0
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                WidgetSync.shared.flush()
                transcripts.scheduleBackgroundWork()
                BackgroundRefresh.schedule()
            }
            // Check feeds when the app opens, at most once an hour.
            guard phase == .active else { return }
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
