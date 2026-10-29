import BackgroundTasks
import Foundation
import UserNotifications
import PodcastCore

/// Local notifications for new episodes from shows with the bell on.
/// They say where the episode went, e.g. "Added to the top of Up Next".
enum NewEpisodeAlerts {
    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    @MainActor
    static func post(for episodes: [PodcastEpisode], queue: [QueueItem]) {
        for episode in episodes {
            guard let show = episode.podcast, show.notify else { continue }
            let content = UNMutableNotificationContent()
            content.title = "New from \(show.title)"
            content.subtitle = placement(of: episode, show: show, queue: queue)
            content.body = episode.title
            content.sound = .default
            content.threadIdentifier = show.feedURL
            content.userInfo = ["episodeID": episode.episodeID]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: episode.episodeID, content: content, trigger: nil))
        }
    }

    static func placement(of episode: PodcastEpisode, show: Podcast, queue: [QueueItem]) -> String {
        guard let index = queue.firstIndex(where: { $0.episode.id == episode.episodeID }) else {
            return "In your library"
        }
        if index == 0 { return "Added to the top of Up Next" }
        if index == queue.count - 1 { return "Added to the end of Up Next" }
        return "Added to Up Next at number \(index + 1)"
    }
}

/// Checks feeds in the background every 1, 3 or 6 hours (Paul's setting;
/// iOS picks the exact moment, and a delay is fine).
enum BackgroundRefresh {
    static let taskID = "com.gruffaluff.podcasts.refresh"
    static let intervals = [1, 3, 6]

    static var intervalHours: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "checkIntervalHours")
            return intervals.contains(stored) ? stored : 3
        }
        set { UserDefaults.standard.set(newValue, forKey: "checkIntervalHours") }
    }

    @MainActor
    static func register(store: LibraryStore) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            schedule()
            let work = Task { @MainActor in
                await store.refreshAll()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date().addingTimeInterval(TimeInterval(intervalHours * 3600))
        try? BGTaskScheduler.shared.submit(request)
    }
}
