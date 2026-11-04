import Foundation
import CloudKit
import CoreData
import SwiftData

/// iCloud sync. Shows, episodes (played, progress, ad breaks, chapters), Up
/// Next and bookmarks live in SwiftData, which mirrors them to Paul's private
/// iCloud database when the app has the iCloud entitlement (see
/// `PodcastsApp.makeContainer`). Settings are mirrored separately through
/// iCloud key-value storage (`SettingsSync`). Downloads and transcript files
/// stay on the iPhone; downloads come back by themselves after a restore.
enum CloudSync {
    /// The CloudKit container named in `Config/Podcasts.entitlements`.
    static let containerID = "iCloud.com.gruffaluff.podcasts"

    /// True when the iPhone is signed in to iCloud.
    static var isSignedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

    private static let statusKey = "cloud.status"

    /// What last happened in each area ("Sync", "Alerts"): "OK 21:40 …" or
    /// "PROBLEM …", shown on the Shows screen so iCloud never fails silently.
    static var status: [String: String] {
        UserDefaults.standard.dictionary(forKey: statusKey) as? [String: String] ?? [:]
    }

    /// Records an error (nil = it worked, with an optional detail).
    static func note(_ error: Error?, in area: String, detail: String = "") {
        var all = status
        let time = Date().formatted(date: .omitted, time: .shortened)
        if let error {
            let code = (error as? CKError).map { " [\($0.code.rawValue)]" } ?? ""
            all[area] = "PROBLEM \(time): \(error.localizedDescription)\(code)"
        } else {
            all[area] = "OK \(time)" + (detail.isEmpty ? "" : " · \(detail)")
        }
        UserDefaults.standard.set(all, forKey: statusKey)
    }

    /// The iCloud account as CloudKit sees it, in words.
    static func accountDescription() async -> String {
        do {
            switch try await CKContainer(identifier: containerID).accountStatus() {
            case .available: return "available"
            case .noAccount: return "no iCloud account (or Poddeck's iCloud switch is off)"
            case .restricted: return "restricted (Screen Time or a profile)"
            case .temporarilyUnavailable: return "temporarily unavailable (check Settings → your name)"
            case .couldNotDetermine: return "could not be checked"
            @unknown default: return "unknown"
            }
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

/// Mirrors settings between UserDefaults and iCloud key-value storage, so a
/// reinstall or a new iPhone gets them back. Local changes are pushed as
/// they happen; changes from iCloud are written into UserDefaults (most
/// screens read them at launch, so they apply from the next launch).
@MainActor
final class SettingsSync {
    static let shared = SettingsSync()

    /// Settings worth keeping. Device-only things (when feeds were last
    /// checked) are left out.
    static let keys = [
        "findAdsWhileListening", "checkIntervalHours", "downloadWifiOnly",
        "keepShowOrder", "keepPlayingNew", "keepPlayedDownloads",
        "speed", "trimSilences", "boostVoices", "skipBack", "skipForward",
        "skipAds", "transcriptSchedule",
        // So a reinstall doesn't follow the test show again.
        "starterShowFollowed",
    ]

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var observers: [NSObjectProtocol] = []

    /// Call once at launch, before anything reads settings.
    func start() {
        guard observers.isEmpty else { return }
        cloud.synchronize()
        pull()
        observers.append(NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { _ in
            MainActor.assumeIsolated { SettingsSync.shared.pull() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { SettingsSync.shared.push() }
        })
    }

    /// iCloud → this iPhone, for settings iCloud has a value for.
    private func pull() {
        for key in Self.keys {
            guard let value = cloud.object(forKey: key), !same(value, local.object(forKey: key)) else { continue }
            local.set(value, forKey: key)
        }
    }

    /// This iPhone → iCloud.
    private func push() {
        var changed = false
        for key in Self.keys {
            guard let value = local.object(forKey: key), !same(value, cloud.object(forKey: key)) else { continue }
            cloud.set(value, forKey: key)
            changed = true
        }
        if changed { cloud.synchronize() }
    }

    private func same(_ a: Any?, _ b: Any?) -> Bool {
        guard let a = a as? NSObject, let b = b as? NSObject else { return a == nil && b == nil }
        return a.isEqual(b)
    }

    /// Whether this Apple account already had the test show followed.
    static var starterShowFollowedInCloud: Bool {
        NSUbiquitousKeyValueStore.default.bool(forKey: "starterShowFollowed")
    }
}

// MARK: - Tidying up after a sync

extension LibraryStore {
    /// Watches for changes arriving from iCloud and tidies up after them.
    func observeCloudChanges() {
        let names: [Notification.Name] = [.NSPersistentStoreRemoteChange, NSPersistentCloudKitContainer.eventChangedNotification]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event
                MainActor.assumeIsolated {
                    if let event, event.endDate != nil { CloudSync.note(event.succeeded ? nil : event.error, in: "Sync", detail: LibraryStore.eventName(event.type)) }
                    self?.scheduleCloudTidy()
                }
            }
        }
    }

    nonisolated static func eventName(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: return "set up"
        case .import: return "received changes"
        case .export: return "sent changes"
        @unknown default: return "synced"
        }
    }

    /// Waits for a burst of changes to settle, then tidies once.
    private func scheduleCloudTidy() {
        cloudTidyTask?.cancel()
        cloudTidyTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.tidyAfterSync()
        }
    }

    /// Merges duplicates, fixes download/transcript records for this iPhone
    /// and reloads Up Next. Does nothing (and saves nothing) when all is tidy,
    /// so it never loops on its own saves.
    func tidyAfterSync() {
        var changed = mergeDuplicates()
        changed = reconcileLocalFiles() || changed
        if changed { save() }
        reloadQueueFromSaved()
    }

    /// iCloud can't keep shows and episodes unique, so the same show can end
    /// up saved twice (e.g. followed on a fresh install before iCloud caught
    /// up). Keeps one of each, combining what Paul did with both.
    @discardableResult
    func mergeDuplicates() -> Bool {
        var changed = false
        let shows = (try? context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.followedAt)]))) ?? []
        for group in Dictionary(grouping: shows, by: \.feedURL).values where group.count > 1 {
            let keeper = group[0]  // Followed first; the same choice on every device.
            for extra in group.dropFirst() {
                for episode in extra.episodes { episode.podcast = keeper }
                keeper.notify = keeper.notify || extra.notify
                keeper.speakerNames = extra.speakerNames.merging(keeper.speakerNames) { _, mine in mine }
                if keeper.genre == nil { keeper.genre = extra.genre }
                context.delete(extra)
            }
            changed = true
        }
        if changed { save() }

        let episodes = (try? context.fetch(FetchDescriptor<PodcastEpisode>(sortBy: [SortDescriptor(\.episodeID)]))) ?? []
        for group in Dictionary(grouping: episodes, by: \.episodeID).values where group.count > 1 {
            let keeper = group.first { $0.podcast != nil } ?? group[0]
            for extra in group where extra !== keeper {
                keeper.combine(with: extra)
                context.delete(extra)
            }
            changed = true
        }

        // Up Next rows: one per episode; drop rows for shows no longer followed.
        let followed = Set(((try? context.fetch(FetchDescriptor<Podcast>())) ?? []).map(\.feedURL))
        let entries = (try? context.fetch(FetchDescriptor<UpNextEntry>(sortBy: [SortDescriptor(\.order)]))) ?? []
        var seen = Set<String>()
        for entry in entries {
            let feed = entry.episodeID.components(separatedBy: "|").first ?? ""
            if !seen.insert(entry.episodeID).inserted || (!followed.isEmpty && !followed.contains(feed)) {
                context.delete(entry)
                changed = true
            }
        }
        return changed
    }

    /// Download and transcript records come from iCloud, but the files only
    /// exist on the iPhone that made them. Clears records whose file isn't
    /// here, and downloads those episodes again (after a restore, Up Next
    /// comes back ready to play).
    @discardableResult
    func reconcileLocalFiles() -> Bool {
        var changed = false
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.downloadFile != nil || $0.transcriptFile != nil })
        for episode in (try? context.fetch(descriptor)) ?? [] {
            if let name = episode.downloadFile, !FileManager.default.fileExists(atPath: DownloadFiles.url(for: name).path) {
                episode.downloadFile = nil
                if !episode.played { downloads?.download(episode, automatic: true) }
                changed = true
            }
            if let name = episode.transcriptFile, !TranscriptFiles.exists(name) {
                episode.transcriptFile = nil
                if episode.transcriptState == .ready { episode.transcriptState = TranscriptState.none }
                changed = true
            }
        }
        return changed
    }
}

extension PodcastEpisode {
    /// Folds another copy of this episode into this one, keeping the most
    /// listened-to state.
    func combine(with other: PodcastEpisode) {
        if other.played && !played {
            played = true
            playedAt = other.playedAt
        }
        position = max(position, other.position)
        duration = duration ?? other.duration
        downloadFile = downloadFile ?? other.downloadFile
        if transcriptFile == nil, let file = other.transcriptFile {
            transcriptFile = file
            transcriptState = other.transcriptState
        }
        if adBreaks.isEmpty { adBreaks = other.adBreaks }
        dismissedAds = Array(Set(dismissedAds + other.dismissedAds)).sorted()
        adsChecked = adsChecked || other.adsChecked
        if autoChapters.isEmpty { autoChapters = other.autoChapters }
        if syncAnchors.isEmpty { syncAnchors = other.syncAnchors }
    }
}
