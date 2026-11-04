import CloudKit
import Foundation

/// Real-time new-episode alerts (free): a GitHub Actions job checks Paul's
/// feeds every ~15 minutes (scripts/new_episode_alerts.py). It reads which
/// shows he follows from a record the app keeps in Poddeck's iCloud public
/// database, and when it finds a new episode it saves a record there; iCloud
/// then pushes to the phone. Shows with the bell on get a visible alert
/// ("New from …"); the others a silent push that just updates Up Next.
@MainActor
enum RealtimeAlerts {
    static let container = CKContainer(identifier: CloudSync.containerID)
    static var database: CKDatabase { container.publicCloudDatabase }

    static let followsType = "PoddeckFollows"
    static let alertType = "PoddeckAlertEpisode"
    static let quietType = "PoddeckQuietEpisode"
    private static let subscriptionsKey = "realtimeAlerts.subscriptions.v1"
    private static let lastFollowsKey = "realtimeAlerts.lastFollows"

    /// Tells the alerts job which shows to check (only when that changed),
    /// and makes sure the phone is subscribed to the pushes.
    static func publishFollows(store: LibraryStore) async {
        guard CloudSync.isSignedIn else { return }
        let shows = store.allShows
        let feeds = shows.map(\.feedURL).sorted()
        let alertFeeds = shows.filter(\.notify).map(\.feedURL).sorted()
        let signature = (feeds + ["|"] + alertFeeds).joined(separator: "\n")
        if UserDefaults.standard.string(forKey: lastFollowsKey) != signature {
            let record = CKRecord(recordType: followsType, recordID: CKRecord.ID(recordName: "follows"))
            record["feeds"] = feeds as CKRecordValue
            record["alertFeeds"] = alertFeeds as CKRecordValue
            record["updated"] = Date() as CKRecordValue
            do {
                _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                UserDefaults.standard.set(signature, forKey: lastFollowsKey)
            } catch {
                // Tried again on the next feed check.
            }
        }
        await subscribeIfNeeded()
    }

    /// One subscription per kind of record: visible alerts and silent updates.
    private static func subscribeIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: subscriptionsKey) else { return }

        let alertInfo = CKSubscription.NotificationInfo()
        alertInfo.titleLocalizationKey = "New from %1$@"
        alertInfo.titleLocalizationArgs = ["showTitle"]
        alertInfo.alertLocalizationKey = "%1$@"
        alertInfo.alertLocalizationArgs = ["episodeTitle"]
        alertInfo.soundName = "default"
        alertInfo.shouldSendContentAvailable = true
        let alerts = CKQuerySubscription(recordType: alertType, predicate: NSPredicate(value: true),
                                         subscriptionID: "new-episode-alerts", options: [.firesOnRecordCreation])
        alerts.notificationInfo = alertInfo

        let quietInfo = CKSubscription.NotificationInfo()
        quietInfo.shouldSendContentAvailable = true
        let quiet = CKQuerySubscription(recordType: quietType, predicate: NSPredicate(value: true),
                                        subscriptionID: "new-episode-updates", options: [.firesOnRecordCreation])
        quiet.notificationInfo = quietInfo

        do {
            _ = try await database.modifySubscriptions(saving: [alerts, quiet], deleting: [])
            UserDefaults.standard.set(true, forKey: subscriptionsKey)
        } catch {
            // Usually: the record types don't exist yet (the job creates them
            // on its first run). Tried again on the next feed check.
        }
    }

    nonisolated static func isAlertsPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let note = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification else { return false }
        return note.subscriptionID == "new-episode-alerts" || note.subscriptionID == "new-episode-updates"
    }
}
