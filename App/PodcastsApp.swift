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
        SettingsSync.shared.start()
        let container = Self.makeContainer()
        let store = LibraryStore(context: container.mainContext)
        self.container = container
        _store = State(initialValue: store)
        _player = State(initialValue: PlayerModel(store: store))
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

    /// Tape Deck type for navigation titles and tab labels.
    private static func styleSystemBars() {
        let ink = UIColor(Theme.ink)
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold), .foregroundColor: ink
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold), .foregroundColor: ink
        ]
        UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold)], for: .normal)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Podcast.self, PodcastEpisode.self, UpNextEntry.self, Bookmark.self])
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
    @Environment(LibraryStore.self) private var store
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPlayer = false

    var body: some View {
        TabView {
            UpNextView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Up Next", systemImage: "list.bullet") }
            LibraryView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
            DiscoverView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Discover", systemImage: "safari") }
            SearchView()
                .miniPlayer($showingPlayer)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .tint(Theme.ink)
        .sheet(isPresented: $showingPlayer) {
            NowPlayingView()
                .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                transcripts.scheduleBackgroundWork()
                BackgroundRefresh.schedule()
            }
            // Check feeds when the app opens, at most once an hour.
            guard phase == .active else { return }
            store.tidyAfterSync()
            store.cleanUpPlayedDownloads()
            transcripts.prepareUpNext()
            Task {
                await store.followStarterShowIfNeeded()
                if store.lastChecked.map({ Date().timeIntervalSince($0) > 3600 }) ?? true {
                    await store.refreshAll()
                }
            }
        }
    }
}
