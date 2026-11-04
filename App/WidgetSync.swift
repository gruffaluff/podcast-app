import CryptoKit
import Foundation
import UIKit
import WidgetKit

/// Keeps the widgets' copy of what's playing and Up Next current
/// (`WidgetSnapshot`, in the App Group's shared folder), and connects the
/// widget / Control Centre keys to the player.
@MainActor
final class WidgetSync {
    static let shared = WidgetSync()

    private var player: PlayerModel?
    private var store: LibraryStore?
    private var pending: Task<Void, Never>?
    private var last: WidgetSnapshot?

    func start(player: PlayerModel, store: LibraryStore) {
        guard self.player == nil else { return }
        self.player = player
        self.store = store
        WidgetActions.playPause = {
            if player.nowPlaying != nil { player.togglePlayPause() } else { PlayUpNextIntent.playUpNext() }
        }
        WidgetActions.skipBack = { player.skipBackward() }
        WidgetActions.skipForward = { player.skipForwardBy() }
        watch()
    }

    /// Writes now (e.g. when the app goes to the background, so the
    /// progress shown is current).
    func flush() {
        pending?.cancel()
        Task { await write() }
    }

    private func watch() {
        guard let player, let store else { return }
        withObservationTracking {
            _ = store.queue
            _ = player.nowPlaying
            _ = player.isPlaying
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.schedule()
                self?.watch()
            }
        }
        schedule()
    }

    /// Waits for a burst of changes to settle, then writes once.
    private func schedule() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.write()
        }
    }

    private func write() async {
        guard let player, let store, WidgetSnapshot.folder != nil else { return }
        var snapshot = WidgetSnapshot()
        snapshot.isPlaying = player.isPlaying
        if let now = player.nowPlaying {
            let duration = player.duration > 0 ? player.duration : nil
            snapshot.nowPlaying = .init(
                id: now.episodeID, title: now.title, show: now.showTitle,
                artworkFile: await artworkFile(for: now.artworkURL),
                remaining: duration.map { max(0, $0 - player.currentTime) },
                progress: duration.map { min(1, player.currentTime / $0) } ?? 0)
        }
        for item in store.queue.prefix(6) where item.episode.id != snapshot.nowPlaying?.id {
            guard let episode = store.episode(item.episode.id) else { continue }
            let duration = episode.duration ?? 0
            snapshot.upNext.append(.init(
                id: episode.episodeID, title: episode.title, show: episode.podcast?.title ?? "",
                artworkFile: await artworkFile(for: episode.artwork),
                remaining: duration > 0 ? max(0, duration - episode.position) : nil,
                progress: duration > 0 ? min(1, episode.position / duration) : 0))
            if snapshot.upNext.count == 4 { break }
        }
        var compare = snapshot
        compare.updated = last?.updated ?? compare.updated
        guard compare != last else { return }
        snapshot.save()
        last = snapshot
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        ControlCenter.shared.reloadAllControls()
    }

    /// A small copy of the artwork in the shared folder (widgets can't load
    /// images from the internet themselves). Made once per artwork.
    private func artworkFile(for url: URL?) async -> String? {
        guard let url, let folder = WidgetSnapshot.folder else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        let name = "art-\(digest).jpg"
        let target = folder.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: target.path) { return name }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let small = await image.byPreparingThumbnail(ofSize: CGSize(width: 180, height: 180)),
              let jpeg = small.jpegData(compressionQuality: 0.8) else { return nil }
        try? jpeg.write(to: target, options: .atomic)
        return name
    }
}
