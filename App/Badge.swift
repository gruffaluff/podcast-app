import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// What the red number on Poddeck's home-screen icon counts (Paul, 12 Nov
/// 2026; mock-ups https://claude.ai/artifact/RnVevs4sFdvbMpeXBfnbM6 and
/// https://claude.ai/artifact/7zcUA9zfezfFkToa3HkVhJ, he picked layout A).
/// Off by default. Kept on this iPhone only (not synced).
enum BadgeMode: String, CaseIterable, Identifiable {
    case off
    case sinceOpen
    case newEpisodes
    case upNext
    case downloaded
    case topShows
    case hoursLeft
    case problems

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .sinceOpen: "New since last open"
        case .newEpisodes: "New episodes"
        case .upNext: "In Up Next"
        case .downloaded: "Downloaded, not played"
        case .topShows: "Top shows only"
        case .hoursLeft: "Hours left in Up Next"
        case .problems: "Only when something's wrong"
        }
    }

    var detail: String {
        switch self {
        case .off: "No number on the icon."
        case .sinceOpen: "New episodes since you last opened Poddeck. Clears when you open it."
        case .newEpisodes: "The same as Library's New: unplayed, out in the last week."
        case .upNext: "Episodes waiting in Up Next."
        case .downloaded: "Episodes on the phone, ready to play with no signal."
        case .topShows: "New since you last opened Poddeck, from your Top shows only."
        case .hoursLeft: "Hours of listening left in Up Next at your speed, rounded up."
        case .problems: "Shows whose feed couldn't be checked last time. Usually no badge."
        }
    }
}

@MainActor
enum AppBadge {
    static let modeKey = "badgeMode"
    static let lastOpenKey = "badgeLastOpen"
    /// Feeds that couldn't be fetched in the last check (set by refreshAll).
    static let failedFeedsKey = "badgeFailedFeeds"

    static var mode: BadgeMode {
        BadgeMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .off
    }

    private static var lastOpen: Date {
        UserDefaults.standard.object(forKey: lastOpenKey) as? Date ?? Date()
    }

    /// The app came to the front: "since last open" starts again from now.
    static func appOpened(store: LibraryStore) {
        UserDefaults.standard.set(Date(), forKey: lastOpenKey)
        update(store: store)
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.badge])
    }

    /// Sets the icon's number for the chosen mode (0 clears it).
    static func update(store: LibraryStore) {
        let number = count(mode, store: store) ?? 0
        UNUserNotificationCenter.current().setBadgeCount(number, withCompletionHandler: nil)
    }

    /// What the badge would show for a mode right now (nil for Off).
    static func count(_ mode: BadgeMode, store: LibraryStore) -> Int? {
        switch mode {
        case .off:
            return nil
        case .sinceOpen:
            return newSinceOpen(store: store).count
        case .topShows:
            return newSinceOpen(store: store).filter { $0.podcast?.autoAdd == .top }.count
        case .newEpisodes:
            let unplayed = (try? store.context.fetch(LibraryView.newEpisodesQueryForList)) ?? []
            return LibraryView.pickNew(from: unplayed, limit: 999).count
        case .upNext:
            return store.queue.count
        case .downloaded:
            let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == false && $0.downloadFile != nil })
            return (try? store.context.fetchCount(descriptor)) ?? 0
        case .hoursLeft:
            return hoursLeft(store: store)
        case .problems:
            return (UserDefaults.standard.stringArray(forKey: failedFeedsKey) ?? []).count
        }
    }

    private static func newSinceOpen(store: LibraryStore) -> [PodcastEpisode] {
        let since = lastOpen
        let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.played == false && $0.published > since })
        return ((try? store.context.fetch(descriptor)) ?? []).filter { $0.podcast != nil }
    }

    private static func hoursLeft(store: LibraryStore) -> Int {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        var seconds: TimeInterval = 0
        for item in store.queue {
            let episode = episodes[item.episode.id]
            seconds += episode?.timeLeft ?? episode?.duration ?? 0
        }
        let speed = max(1, UserDefaults.standard.object(forKey: "speed") as? Double ?? 1)
        return Int((seconds / speed / 3600).rounded(.up))
    }
}

/// The Shows screen's "Badge on the app icon" row (layout A): a tiny icon
/// preview with today's number, then the sand ▾ list key.
struct BadgeSettingRow: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage(AppBadge.modeKey) private var modeRaw = BadgeMode.off.rawValue

    private var mode: BadgeMode { BadgeMode(rawValue: modeRaw) ?? .off }

    var body: some View {
        HStack(spacing: 10) {
            preview
            DeckPicker(title: "Badge",
                       options: BadgeMode.allCases.map { (label: $0.label, value: $0.rawValue) },
                       selection: $modeRaw)
        }
        .onChange(of: modeRaw) { _, _ in
            Task {
                if mode != .off { await AppBadge.requestPermission() }
                AppBadge.update(store: store)
            }
        }
    }

    private var preview: some View {
        let number = AppBadge.count(mode, store: store)
        return Image("IconPreview")
            .resizable()
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if let number, number > 0 {
                    Text("\(number)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.red, in: Capsule())
                        .offset(x: 8, y: -6)
                }
            }
            .padding(.top, 4)
            .accessibilityHidden(true)
    }
}
