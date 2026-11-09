import SwiftData
import SwiftUI
import UIKit
import PodcastCore

/// "Copy diagnostics" (Paul, 9 Nov 2026): a plain-text summary of the app's
/// state to paste into a bug report. It never includes feed links (private
/// feeds carry their key in the link) or anything from iCloud beyond status.
@MainActor
enum Diagnostics {
    static func report(store: LibraryStore, player: PlayerModel, transcripts: TranscriptService, downloads: DownloadManager) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let shows = (try? store.context.fetch(FetchDescriptor<Podcast>())) ?? []
        let episodeCount = (try? store.context.fetchCount(FetchDescriptor<PodcastEpisode>())) ?? 0
        let storage = store.storageByShow()
        let downloadBytes = storage.reduce(Int64(0)) { $0 + $1.bytes }
        let downloadCount = storage.reduce(0) { $0 + $1.count }
        let defaults = UserDefaults.standard

        var lines: [String] = []
        lines.append("Poddeck diagnostics · \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("App \(version) (build \(build)) · iOS \(UIDevice.current.systemVersion) · \(deviceModel())")
        lines.append("")
        lines.append("Shows: \(shows.count) (Top \(shows.filter { $0.autoAdd == .top }.count), Bottom \(shows.filter { $0.autoAdd == .bottom }.count), Off \(shows.filter { $0.autoAdd == .off }.count)); bell on \(shows.filter(\.notify).count)")
        lines.append("Episodes saved: \(episodeCount) · Up Next: \(store.queue.count)")
        lines.append("Downloads: \(downloadCount), \(ByteCountFormatter.string(fromByteCount: downloadBytes, countStyle: .file)) · in progress \(downloads.progress.count)")
        lines.append("Transcripts: \(ByteCountFormatter.string(fromByteCount: store.transcriptBytes(), countStyle: .file)) · busy \(transcripts.isBusy ? "yes" : "no")")
        lines.append("Last feed check: \(store.lastChecked.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "never")")
        lines.append("Internet: \(NetworkStatus.shared.online ? "online" : "offline")")
        lines.append("")
        if let now = player.nowPlaying {
            lines.append("Playing: \(now.showTitle) · \(now.title) at \(TimeFormat.clock(player.currentTime)) of \(TimeFormat.clock(player.duration)) (\(player.isPlaying ? "playing" : "paused"))")
            lines.append("Output: \(player.outputName ?? "iPhone") · chapters \(player.chapters.count) · ad breaks \(player.adBreaks.count)")
        } else {
            lines.append("Playing: nothing")
        }
        lines.append("")
        lines.append("Settings: speed \(PlayerOptions.speedLabel(player.speed))\(player.speedIsForShow ? " (show)" : "") · trim \(onOff(player.trimSilences)) · boost \(onOff(player.boostVoices)) · skip \(player.skipBackSeconds)/\(player.skipForwardSeconds)s")
        lines.append("Transcribe: \(transcripts.schedule.label) · find ads \(onOff(AdScanner.isEnabled)) · skip ads \(onOff(player.skipAds))")
        lines.append("Check every \(BackgroundRefresh.intervalHours)h · Wi-Fi only \(onOff(downloads.wifiOnly)) · keep played 24h \(onOff(store.keepPlayedDownloads)) · cap \(defaults.integer(forKey: "downloadCapGB")) GB")
        lines.append("After an episode: \(defaults.string(forKey: "afterEpisode") ?? "top") · keep shows in order \(onOff(store.keepShowOrder)) · keep playing new \(onOff(store.keepPlayingNew))")
        lines.append("")
        lines.append("iCloud: \(CloudSync.isSignedIn ? "signed in" : "signed out")")
        for (area, status) in CloudSync.status.sorted(by: { $0.key < $1.key }) {
            lines.append("\(area): \(status)")
        }
        return lines.joined(separator: "\n")
    }

    private static func onOff(_ value: Bool) -> String { value ? "on" : "off" }

    /// The hardware name, e.g. "iPhone18,1".
    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

/// The Shows screen's diagnostics row: copies the report for a bug report.
struct DiagnosticsSection: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @State private var copied = false

    var body: some View {
        Section {
            DeckActionRow(title: copied ? "Copied" : "Diagnostics", key: "Copy") {
                UIPasteboard.general.string = Diagnostics.report(store: store, player: player, transcripts: transcripts, downloads: downloads)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            }
        } header: {
            DeckHeader(title: "Problems")
        } footer: {
            Text("Copies a summary of how Poddeck is set up and what it's doing (no feed links), to paste into a message about a problem.")
        }
        .listRowBackground(Theme.surface)
    }
}
