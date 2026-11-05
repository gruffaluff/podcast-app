import UIKit
import Observation

/// Touch and hold the app icon: Play Up Next, Up Next, Search (listed in
/// Info.plist). The scene delegate hands the chosen one over here and
/// RootView acts on it.
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()
    /// The chosen action's type, until RootView has handled it.
    var pending: String?

    static let playUpNext = "com.gruffaluff.podcasts.playUpNext"
    static let upNext = "com.gruffaluff.podcasts.upNext"
    static let search = "com.gruffaluff.podcasts.search"
}

/// The app's window scene delegate: only here to receive quick actions
/// while the app is already running (SwiftUI still runs the window).
@MainActor
final class QuickActionSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActions.shared.pending = shortcutItem.type
        completionHandler(true)
    }
}
