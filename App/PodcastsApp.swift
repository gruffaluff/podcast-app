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
            RootView()
                .environment(store)
                .environment(player)
                .environment(downloads)
                .environment(transcripts)
        }
        .modelContainer(container)
    }

    /// Big heavy condensed titles and plain tab labels.
    private static func styleSystemBars() {
        let ink = UIColor(Theme.ink)
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
    @State private var showingPlayer = false
    @State private var tab = 0
    @State private var quickActions = QuickActions.shared
    @State private var showingWelcome = false

    var body: some View {
        TabView(selection: $tab) {
            UpNextView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Up Next", systemImage: "list.bullet") }
                .tag(0)
            LibraryView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(1)
            DiscoverView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Discover", systemImage: "safari") }
                .tag(2)
            SearchView()
                .miniPlayer($showingPlayer)
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
        .onChange(of: player.openPlayerRequests) { showingPlayer = true }
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
