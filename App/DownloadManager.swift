import Foundation
import Observation
import UIKit
import UserNotifications
import PodcastCore

/// Where downloaded episodes live: Application Support/Downloads, left out of
/// iCloud backups (they can always be downloaded again).
enum DownloadFiles {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directory = base.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }()

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}

/// Downloads episodes with a background session, so they carry on while the
/// app is closed. Auto-downloads wait for Wi-Fi when "Wi-Fi only" is on;
/// downloads Paul starts himself go straight away.
@MainActor
@Observable
final class DownloadManager {
    static let sessionID = "com.gruffaluff.podcasts.downloads"
    /// Given to us by iOS when it wakes the app to finish background downloads.
    static var backgroundCompletion: (() -> Void)?

    /// Episodes downloading now, with progress from 0 to 1.
    private(set) var progress: [String: Double] = [:]

    var wifiOnly: Bool = true {
        didSet { UserDefaults.standard.set(wifiOnly, forKey: "downloadWifiOnly") }
    }

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private let delegate = DownloadDelegate()
    @ObservationIgnored private let session: URLSession

    init(store: LibraryStore) {
        self.store = store
        self.wifiOnly = UserDefaults.standard.object(forKey: "downloadWifiOnly") as? Bool ?? true
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        delegate.manager = self
        store.downloads = self

        // Pick up downloads still running from last time.
        Task {
            for task in await session.allTasks {
                if let id = task.taskDescription, progress[id] == nil { progress[id] = 0 }
            }
        }
    }

    // MARK: Actions

    /// Downloads an episode. `automatic` downloads respect "Wi-Fi only".
    func download(_ episode: PodcastEpisode, automatic: Bool = false) {
        let id = episode.episodeID
        guard progress[id] == nil, store.localAudioURL(for: episode) == nil else { return }
        var request = URLRequest(url: episode.audioURL)
        request.setValue("Podcasts/0.1 (personal iOS app)", forHTTPHeaderField: "User-Agent")
        if automatic && wifiOnly {
            request.allowsCellularAccess = false
            request.allowsExpensiveNetworkAccess = false
        }
        let task = session.downloadTask(with: request)
        task.taskDescription = id
        progress[id] = 0
        task.resume()
    }

    /// Starts downloads for new episodes whose show has auto-download on.
    func autoDownload(_ episodes: [PodcastEpisode]) {
        for episode in episodes {
            guard let show = episode.podcast, show.autoDownload, show.autoAdd != .off, !episode.played else { continue }
            download(episode, automatic: true)
        }
    }

    func cancel(_ episodeID: String) {
        guard progress[episodeID] != nil else { return }
        progress[episodeID] = nil
        Task {
            for task in await session.allTasks where task.taskDescription == episodeID {
                task.cancel()
            }
        }
    }

    /// "Downloading 45%", "Downloaded", or nil.
    func status(for episode: PodcastEpisode) -> String? {
        if let fraction = progress[episode.episodeID] {
            return fraction > 0 ? "Downloading \(Int(fraction * 100))%" : "Waiting to download"
        }
        return episode.downloadFile != nil ? "Downloaded" : nil
    }

    // MARK: From the session

    fileprivate func updateProgress(_ episodeID: String, _ fraction: Double) {
        guard let current = progress[episodeID] else { return }
        if fraction - current >= 0.01 || fraction >= 1 {
            progress[episodeID] = fraction
        }
    }

    fileprivate func finished(_ episodeID: String, fileName: String?) {
        progress[episodeID] = nil
        if let fileName {
            store.setDownloaded(episodeID, fileName: fileName)
        }
    }

    fileprivate func finishBackgroundEvents() {
        Self.backgroundCompletion?()
        Self.backgroundCompletion = nil
    }
}

/// Receives events from the download session (on a background thread).
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    weak var manager: DownloadManager?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        // The file must be moved before this method returns.
        var fileName: String?
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        if (200..<300).contains(status), let source = downloadTask.originalRequest?.url {
            let name = DownloadNaming.fileName(episodeID: id, audioURL: source)
            let destination = DownloadFiles.url(for: name)
            try? FileManager.default.removeItem(at: destination)
            if (try? FileManager.default.moveItem(at: location, to: destination)) != nil {
                fileName = name
            }
        }
        let manager = self.manager
        Task { @MainActor in manager?.finished(id, fileName: fileName) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let manager = self.manager
        Task { @MainActor in manager?.updateProgress(id, fraction) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let id = task.taskDescription else { return }
        let manager = self.manager
        Task { @MainActor in manager?.finished(id, fileName: nil) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let manager = self.manager
        Task { @MainActor in manager?.finishBackgroundEvents() }
    }
}

/// Lets iOS hand over finished background downloads when it wakes the app,
/// and shows new-episode alerts even while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Pushes from iCloud when the alerts job finds a new episode.
        application.registerForRemoteNotifications()
        return true
    }

    /// The window uses QuickActionSceneDelegate (for touch-and-hold icon
    /// actions); CarPlay keeps its own configuration from Info.plist.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        guard connectingSceneSession.role == .windowApplication else {
            return UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
        }
        // Opened from a quick action while the app wasn't running.
        if let item = options.shortcutItem { QuickActions.shared.pending = item.type }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }

    /// A push from the new-episode alerts job: check feeds now so Up Next and
    /// downloads are ready (the push itself already showed any alert).
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard RealtimeAlerts.isAlertsPush(userInfo) else { return .noData }
        await AppServices.store?.refreshAll(postAlerts: false)
        return .newData
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == DownloadManager.sessionID {
            DownloadManager.backgroundCompletion = completionHandler
        }
    }
}
