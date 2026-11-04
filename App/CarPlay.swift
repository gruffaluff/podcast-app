import CarPlay
import UIKit
import Observation
import PodcastCore

/// Poddeck on a car's screen: an Up Next tab and a Shows tab, and the
/// standard Now Playing screen (which uses the same lock-screen controls,
/// skip lengths included). Only appears once Apple has granted the CarPlay
/// audio entitlement and it's added to Config/Podcasts.entitlements.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPNowPlayingTemplateObserver {
    private var interface: CPInterfaceController?
    private let upNext = CPListTemplate(title: "Up Next", sections: [])
    private let shows = CPListTemplate(title: "Shows", sections: [])
    private var artwork: [URL: UIImage] = [:]

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        interface = interfaceController
        upNext.tabImage = UIImage(systemName: "list.bullet")
        shows.tabImage = UIImage(systemName: "square.grid.2x2")
        upNext.emptyViewTitleVariants = ["Up Next is empty"]
        shows.emptyViewTitleVariants = ["No shows yet"]
        let tabs = CPTabBarTemplate(templates: [upNext, shows])
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)

        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Up Next"
        nowPlaying.add(self)
        nowPlaying.updateNowPlayingButtons([
            CPNowPlayingPlaybackRateButton { _ in
                guard let player = AppServices.player else { return }
                let next = player.speed >= 2 ? 1 : (player.speed * 10 + 2).rounded() / 10
                player.setSpeed(next)
            }
        ])
        refresh()
        watchForChanges()
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        CPNowPlayingTemplate.shared.remove(self)
        interface = nil
    }

    // MARK: Now Playing

    nonisolated func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        MainActor.assumeIsolated {
            guard let interface else { return }
            let list = CPListTemplate(title: "Up Next", sections: [CPListSection(items: queueItems())])
            interface.pushTemplate(list, animated: true, completion: nil)
        }
    }

    nonisolated func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {}

    // MARK: Lists

    /// Rebuilds the lists whenever Up Next or the library changes.
    private func watchForChanges() {
        guard interface != nil, let store = AppServices.store else { return }
        withObservationTracking {
            _ = store.queue
            _ = AppServices.player?.nowPlaying
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.watchForChanges()
            }
        }
    }

    private func refresh() {
        upNext.updateSections([CPListSection(items: queueItems())])
        shows.updateSections([CPListSection(items: showItems())])
    }

    private func queueItems() -> [CPListItem] {
        guard let store = AppServices.store else { return [] }
        let episodes = store.episodes(store.queue.map(\.episode.id))
        return store.queue.prefix(40).compactMap { item in
            episodes[item.episode.id].map { episodeItem($0) }
        }
    }

    private func showItems() -> [CPListItem] {
        guard let store = AppServices.store else { return [] }
        return store.allShows.map { show in
            let unplayed = show.episodes.filter { !$0.played }.count
            let item = CPListItem(text: show.title, detailText: "\(unplayed) unplayed", image: image(for: show.artworkURL))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                MainActor.assumeIsolated { self?.open(show) }
                completion()
            }
            return item
        }
    }

    /// A show's newest episodes.
    private func open(_ show: Podcast) {
        let episodes = show.episodes.sorted { $0.published > $1.published }.prefix(30)
        let list = CPListTemplate(title: show.title, sections: [CPListSection(items: episodes.map { episodeItem($0) })])
        interface?.pushTemplate(list, animated: true, completion: nil)
    }

    private func episodeItem(_ episode: PodcastEpisode) -> CPListItem {
        var detail = episode.podcast?.title ?? ""
        if let left = episode.timeLeft, left > 0 { detail += " · \(TimeFormat.length(left)) left" }
        let item = CPListItem(text: episode.title, detailText: detail, image: image(for: episode.artwork))
        item.isPlaying = AppServices.player?.nowPlaying?.episodeID == episode.episodeID
        item.playbackProgress = episode.duration.map { $0 > 0 ? min(1, episode.position / $0) : 0 } ?? 0
        let id = episode.episodeID
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                if let episode = AppServices.store?.episode(id) { AppServices.player?.play(episode) }
                self?.interface?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return item
    }

    // MARK: Artwork

    private func image(for url: URL?) -> UIImage? {
        guard let url else { return UIImage(systemName: "waveform") }
        if let cached = artwork[url] { return cached }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 120, height: 120)) else { return }
            self?.artwork[url] = image
            self?.refresh()
        }
        return UIImage(systemName: "waveform")
    }
}
