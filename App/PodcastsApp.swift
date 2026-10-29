import SwiftUI

@main
struct PodcastsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            UpNextView()
                .tabItem { Label("Up Next", systemImage: "list.bullet") }
            PlaceholderView(title: "Library", note: "Your shows will live here.")
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
            PlaceholderView(title: "Discover", note: "Search and charts for new shows are coming.")
                .tabItem { Label("Discover", systemImage: "safari") }
            PlaceholderView(title: "Search", note: "Search across transcripts is coming.")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .tint(Theme.ink)
    }
}
