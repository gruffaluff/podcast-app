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
    static let stateType = "PoddeckAlertState"
    // ".v2": earlier builds marked these done even when iCloud refused
    // every record (a refusal comes back inside the result, not as a thrown
    // error), so they start again.
    private static let subscriptionsKey = "realtimeAlerts.subscriptions.v2"
    private static let lastFollowsKey = "realtimeAlerts.lastFollows.v2"

    /// Tells the alerts job which shows to check (only when that changed),
    /// and makes sure the phone is subscribed to the pushes. Every outcome
    /// is shown in the Shows screen's iCloud section.
    static func publishFollows(store: LibraryStore) async {
        guard (try? await container.accountStatus()) == .available else {
            let account = await CloudSync.accountDescription()
            CloudSync.note(CloudProblem(message: "iCloud account \(account)"), in: "Alerts")
            return
        }
        let shows = store.allShows
        let feeds = shows.map(\.feedURL).sorted()
        let alertFeeds = shows.filter(\.notify).map(\.feedURL).sorted()
        let signature = (feeds + ["|"] + alertFeeds).joined(separator: "\n")
        let summary = "\(feeds.count) shows, \(alertFeeds.count) with the bell"
        if UserDefaults.standard.string(forKey: lastFollowsKey) != signature {
            let record = CKRecord(recordType: followsType, recordID: CKRecord.ID(recordName: "follows"))
            record["feeds"] = feeds as CKRecordValue
            record["alertFeeds"] = alertFeeds as CKRecordValue
            record["updated"] = Date() as CKRecordValue
            do {
                let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                for (_, result) in results { _ = try result.get() }
                UserDefaults.standard.set(signature, forKey: lastFollowsKey)
            } catch {
                // Tried again on the next feed check.
                CloudSync.note(error, in: "Alerts")
                return
            }
        }
        if await subscribeIfNeeded() {
            CloudSync.note(nil, in: "Alerts", detail: "\(summary) sent · alerts on")
        }
    }

    /// One subscription per kind of record: visible alerts and silent
    /// updates. True when the phone is subscribed.
    private static func subscribeIfNeeded() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: subscriptionsKey) else { return true }

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
            let (results, _) = try await database.modifySubscriptions(saving: [alerts, quiet], deleting: [])
            for (_, result) in results { _ = try result.get() }
            UserDefaults.standard.set(true, forKey: subscriptionsKey)
            return true
        } catch {
            // Tried again on the next feed check.
            CloudSync.note(error, in: "Alerts")
            return false
        }
    }

    struct CloudProblem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    nonisolated static func isAlertsPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let note = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification else { return false }
        return note.subscriptionID == "new-episode-alerts" || note.subscriptionID == "new-episode-updates"
    }
}
