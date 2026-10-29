import AVFoundation
import MediaPlayer
import Observation
import UIKit
import PodcastCore

/// Plays one episode at a time (downloaded copy if any), remembers where Paul
/// stopped, and moves on to the next episode in Up Next when one finishes.
/// Lock screen and headphone controls use the same skip lengths.
@MainActor
@Observable
final class PlayerModel {
    /// What's playing. A plain copy, so a show being unfollowed mid-play is safe.
    struct NowPlaying: Equatable {
        let episodeID: String
        let title: String
        let showTitle: String
        let artworkURL: URL?
        let audioURL: URL
    }

    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// Skip lengths in seconds (5, 10, 15, 30 or 60; 10 by default), set
    /// separately. Lock screen and headphone controls use the same lengths.
    private(set) var skipBackSeconds = PlayerOptions.defaultSkip
    private(set) var skipForwardSeconds = PlayerOptions.defaultSkip
    var skipBack: TimeInterval { TimeInterval(skipBackSeconds) }
    var skipForward: TimeInterval { TimeInterval(skipForwardSeconds) }

    /// Playback speed, 1.0× to 2.0×.
    private(set) var speed: Double = 1.0

    private(set) var sleepTimer: SleepTimerOption?
    /// When a timed sleep timer will pause playback.
    private(set) var sleepEndsAt: Date?

    /// Name of the AirPlay / Bluetooth device when not playing on the phone.
    private(set) var outputName: String?

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var lastSavedTime: TimeInterval = 0
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?

    init(store: LibraryStore) {
        self.store = store
        let defaults = UserDefaults.standard
        skipBackSeconds = PlayerOptions.validSkip(defaults.object(forKey: "skipBack") as? Int ?? PlayerOptions.defaultSkip)
        skipForwardSeconds = PlayerOptions.validSkip(defaults.object(forKey: "skipForward") as? Int ?? PlayerOptions.defaultSkip)
        speed = min(2, max(1, defaults.object(forKey: "speed") as? Double ?? 1))
        player.defaultRate = Float(speed)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
        observePlayer()
        setUpRemoteCommands()
        updateRoute()
    }

    // MARK: Controls

    /// Plays an episode from where Paul left off (or from the start if played).
    func play(_ episode: PodcastEpisode) {
        if nowPlaying?.episodeID == episode.episodeID {
            resume()
            return
        }
        saveProgress()
        nowPlaying = NowPlaying(
            episodeID: episode.episodeID,
            title: episode.title,
            showTitle: episode.podcast?.title ?? "",
            artworkURL: episode.artwork,
            audioURL: episode.audioURL
        )
        duration = episode.duration ?? 0
        let start = episode.played ? 0 : episode.position
        currentTime = start
        lastSavedTime = start
        artwork = nil

        // Play the downloaded copy when there is one, otherwise stream.
        let source = store.localAudioURL(for: episode) ?? episode.audioURL
        let item = AVPlayerItem(url: source)
        item.audioTimePitchAlgorithm = .timeDomain  // Clear speech when sped up.
        player.replaceCurrentItem(with: item)
        if start > 1 {
            player.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        }
        resume()
        loadArtwork(episode.artwork)
    }

    func resume() {
        guard nowPlaying != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        saveProgress()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func setSpeed(_ newSpeed: Double) {
        speed = min(2, max(1, newSpeed))
        UserDefaults.standard.set(speed, forKey: "speed")
        player.defaultRate = Float(speed)
        if player.timeControlStatus != .paused {
            player.rate = Float(speed)
        }
        updateNowPlayingInfo()
    }

    func setSkipBack(_ seconds: Int) {
        skipBackSeconds = PlayerOptions.validSkip(seconds)
        UserDefaults.standard.set(skipBackSeconds, forKey: "skipBack")
        MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBack)]
    }

    func setSkipForward(_ seconds: Int) {
        skipForwardSeconds = PlayerOptions.validSkip(seconds)
        UserDefaults.standard.set(skipForwardSeconds, forKey: "skipForward")
        MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [NSNumber(value: skipForward)]
    }

    /// Starts (or with nil, cancels) the sleep timer.
    func setSleepTimer(_ option: SleepTimerOption?) {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimer = option
        sleepEndsAt = nil
        guard case .minutes(let minutes)? = option else { return }
        let ends = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepEndsAt = ends
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ends.timeIntervalSinceNow))
            guard !Task.isCancelled, let self else { return }
            self.pause()
            self.sleepTimer = nil
            self.sleepEndsAt = nil
        }
    }

    func skipBackward() { seek(to: currentTime - skipBack) }
    func skipForwardBy() { seek(to: currentTime + skipForward) }

    func seek(to time: TimeInterval) {
        guard nowPlaying != nil else { return }
        let upper = duration > 0 ? duration : .greatestFiniteMagnitude
        let target = min(max(0, time), upper)
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlayingInfo() }
        }
        saveProgress()
    }

    func stop() {
        saveProgress()
        player.replaceCurrentItem(with: nil)
        nowPlaying = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Stops if the playing episode is one of these (e.g. its show was unfollowed).
    func stopIfPlaying(showFeedURL: String) {
        if let id = nowPlaying?.episodeID, id.hasPrefix(showFeedURL + "|") {
            stop()
        }
    }

    // MARK: Progress

    private func tick(_ time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }
        currentTime = seconds
        if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0,
           abs(itemDuration - duration) > 1 {
            duration = itemDuration
            if let id = nowPlaying?.episodeID { store.saveDuration(itemDuration, for: id) }
            updateNowPlayingInfo()
        }
        if abs(seconds - lastSavedTime) >= 15 {
            saveProgress()
        }
    }

    private func saveProgress() {
        guard let id = nowPlaying?.episodeID else { return }
        lastSavedTime = currentTime
        store.savePosition(currentTime, for: id)
    }

    /// Finished: mark played, remove from Up Next, play the next one.
    private func didFinish() {
        guard let id = nowPlaying?.episodeID else { return }
        store.markPlayed(id)
        if sleepTimer == .endOfEpisode {
            setSleepTimer(nil)
            stop()
            return
        }
        var next: PodcastEpisode?
        for item in store.queue {
            if let episode = store.episode(item.episode.id) {
                next = episode
                break
            }
        }
        if next == nil {
            next = store.nextNewEpisode(excluding: id)
        }
        if let next {
            nowPlaying = nil
            play(next)
        } else {
            stop()
        }
    }

    // MARK: System hooks

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self?.isPlaying = playing }
        }

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let finishedItem = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, let finishedItem, finishedItem === self.player.currentItem else { return }
                self.didFinish()
            }
        })
        notificationTokens.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRoute() }
        })
        // Resume after a phone call or Siri if iOS says it's appropriate.
        notificationTokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated {
                guard let self, typeValue == AVAudioSession.InterruptionType.ended.rawValue else { return }
                if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    self.resume()
                }
            }
        })
    }

    private func updateRoute() {
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        let onPhone: Set<AVAudioSession.Port> = [.builtInSpeaker, .builtInReceiver]
        if let output, !onPhone.contains(output.portType) {
            outputName = output.portName
        } else {
            outputName = nil
        }
    }

    private func setUpRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        commands.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBack)]
        commands.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipBackward() }
            return .success
        }
        commands.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForward)]
        commands.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipForwardBy() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        guard let nowPlaying else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying.title,
            MPMediaItemPropertyArtist: nowPlaying.showTitle,
            MPMediaItemPropertyAlbumTitle: nowPlaying.showTitle,
            MPMediaItemPropertyMediaType: MPMediaType.podcast.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .paused ? 0.0 : speed,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: speed
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(_ url: URL?) {
        guard let url else { return }
        let episodeID = nowPlaying?.episodeID
        Task {
            guard let response = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: response.0) else { return }
            guard nowPlaying?.episodeID == episodeID else { return }
            artwork = Self.makeArtwork(image)
            updateNowPlayingInfo()
        }
    }

    /// Built outside the main actor: iOS asks for the image on a background thread.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
