import AppIntents
import Foundation

/// What the Home / Lock Screen widgets show. The app writes it to the App
/// Group's shared folder whenever what's playing or Up Next changes; the
/// widgets only read it. Compiled into both the app and the widgets.
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var show: String
        /// File name of a small artwork copy in the shared folder.
        var artworkFile: String?
        /// Seconds left, when known.
        var remaining: Double?
        /// 0…1 listened.
        var progress: Double
    }

    var nowPlaying: Item?
    var isPlaying = false
    var upNext: [Item] = []
    var updated = Date()

    static let appGroup = "group.com.gruffaluff.podcasts"
    static let widgetKind = "PoddeckUpNext"

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    private static var file: URL? { folder?.appendingPathComponent("widget.json") }

    static func load() -> WidgetSnapshot? {
        guard let file, let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let file = Self.file, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func artworkURL(_ name: String?) -> URL? {
        guard let name else { return nil }
        return folder?.appendingPathComponent(name)
    }
}

/// Lets the widget and Control Centre keys reach the player. The intents
/// run inside the app (audio intents always do), where the app has filled
/// these in at launch; in the widget they are never called.
@MainActor
enum WidgetActions {
    static var playPause: (@MainActor () -> Void)?
    static var skipBack: (@MainActor () -> Void)?
    static var skipForward: (@MainActor () -> Void)?
}

struct WidgetPlayPauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Poddeck"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetActions.playPause?()
        return .result()
    }
}

struct WidgetSkipBackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Skip Back in Poddeck"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetActions.skipBack?()
        return .result()
    }
}

struct WidgetSkipForwardIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Skip Forward in Poddeck"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetActions.skipForward?()
        return .result()
    }
}
