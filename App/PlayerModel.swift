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

    /// Rewind a little when you carry on after a pause, so you catch the
    /// end of the sentence (Paul, 10 Nov 2026: "like other apps do"). On by
    /// default; Shows screen → Skip buttons.
    static let rewindKey = "rewindOnResume"
    /// When it paused, and where, so a resume can rewind (only if nothing
    /// moved the playhead since).
    private var pausedAt: Date?
    private var pausedPosition: TimeInterval = 0

    /// How far to go back after a pause of this long: none after a quick
    /// tap, more the longer you've been away.
    static func rewind(afterPause seconds: TimeInterval) -> TimeInterval {
        switch seconds {
        case ..<5: return 0
        case ..<60: return 3
        case ..<3600: return 10
        default: return 20
        }
    }

    /// Playback speed, 1.0× to 2.0×: the show's own speed when it has one,
    /// otherwise the global speed.
    private(set) var speed: Double = 1.0
    /// True when the playing show has its own speed (SPEED then changes that).
    private(set) var speedIsForShow = false

    private(set) var sleepTimer: SleepTimerOption?
    /// When a timed sleep timer will pause playback.
    private(set) var sleepEndsAt: Date?

    /// "Trim silences" (speed through pauses) and "Boost voices" (even out
    /// and lift speech). Both remembered; off by default.
    private(set) var trimSilences = false
    private(set) var boostVoices = false

    /// Chapters from the show (feed JSON or embedded in the audio), if any.
    private(set) var showChapters: [Chapter] = []
    /// Made from the transcript when the show supplies none.
    private(set) var autoChapters: [Chapter] = []

    enum ChapterSource { case show, auto }
    /// "From the show" or "Auto-generated" (Chapters screen).
    var chapterSource: ChapterSource = .show

    var chapters: [Chapter] {
        chapterSource == .show && !showChapters.isEmpty ? showChapters : autoChapters
    }

    // MARK: Ads

    /// Ad breaks found in this download.
    private(set) var adBreaks: [AdBreak] = []
    /// The break just skipped, for the "Ad skipped" note with Play ad / Not an ad.
    private(set) var lastSkippedAd: AdBreak?
    /// Skip ad breaks automatically (default off: a Skip ad button shows instead).
    private(set) var skipAds = false
    /// The ad break playing right now, for the Skip ad button.
    private(set) var currentAd: AdBreak?

    var currentChapterIndex: Int? { Chapters.index(at: currentTime, in: chapters) }

    /// Next chapter (mini player, lock screen, headphones' next-track).
    func nextChapter() {
        guard !chapters.isEmpty else { skipForwardBy(); return }
        let next = (currentChapterIndex ?? -1) + 1
        if next < chapters.count { seek(to: chapters[next].start) }
    }

    /// "Stop at chapter end" (Haar chapters sheet): pauses, with a short
    /// fade, when the chapter playing now ends. Cleared once it stops, when
    /// the episode changes, or when switched off.
    private(set) var stopsAtChapterEnd = false
    /// Where to stop: the end of the chapter it was set in (re-anchored to
    /// the chapter you land in after a jump, so a skip doesn't stop at once).
    @ObservationIgnored private var chapterStopTime: TimeInterval?
    /// The volume is being faded for the chapter stop.
    @ObservationIgnored private var chapterFading = false

    func setStopAtChapterEnd(_ on: Bool) {
        guard on, let end = chapterEnd(at: currentTime), end > currentTime + 0.5 else {
            clearChapterStop()
            return
        }
        chapterStopTime = end
        stopsAtChapterEnd = true
    }

    /// The end of the chapter playing at `time` (the next chapter's start,
    /// or the episode's end for the last one).
    private func chapterEnd(at time: TimeInterval) -> TimeInterval? {
        guard let index = Chapters.index(at: time, in: chapters) else { return nil }
        if let end = chapters[index].end, end > chapters[index].start { return end }
        if index + 1 < chapters.count { return chapters[index + 1].start }
        return duration > 0 ? duration : nil
    }

    private func clearChapterStop() {
        if chapterFading {
            player.volume = 1
            chapterFading = false
        }
        chapterStopTime = nil
        if stopsAtChapterEnd { stopsAtChapterEnd = false }
    }

    /// Called from `tick`: fades out over the last 3 seconds, then pauses.
    private func checkChapterStop(at seconds: TimeInterval) {
        guard let stop = chapterStopTime else { return }
        let fade: TimeInterval = 3
        let left = stop - seconds
        if left <= 0.25 {
            pause()
            clearChapterStop()
        } else if left < fade, player.timeControlStatus == .playing {
            chapterFading = true
            player.volume = Float(max(0, left / fade))
        } else if chapterFading {
            player.volume = 1
            chapterFading = false
        }
    }

    /// Back to the start of this chapter, or the one before if it only just
    /// began.
    func previousChapter() {
        guard !chapters.isEmpty else { skipBackward(); return }
        guard let index = currentChapterIndex else { seek(to: 0); return }
        let start = chapters[index].start
        let target = currentTime - start > 3 || index == 0 ? start : chapters[index - 1].start
        seek(to: target)
    }

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
    @ObservationIgnored private let tapState = AudioTapState()
    @ObservationIgnored private var trimTimer: Timer?
    @ObservationIgnored private var hurrying = false
    /// Breaks Paul chose to hear (Play ad) this time.
    @ObservationIgnored private var allowedAds: Set<TimeInterval> = []
    @ObservationIgnored private var skippedNoteTask: Task<Void, Never>?
    @ObservationIgnored private let adScanner: AdScanner
    /// The playing episode's show, for per-show speed, outro skipping and stats.
    @ObservationIgnored private var currentShowFeed: String?
    @ObservationIgnored private var currentShowTitle = ""
    @ObservationIgnored private var outroSeconds: TimeInterval = 0
    @ObservationIgnored private var finishingEarly = false
    /// Listening time not yet added to the stats.
    @ObservationIgnored private var unloggedSeconds: TimeInterval = 0
    @ObservationIgnored private var lastListenTick: Date?
    /// Episode time covered while playing (for "saved by speed & trims").
    @ObservationIgnored private var unloggedAdvanced: TimeInterval = 0
    @ObservationIgnored private var lastContentTime: TimeInterval?

    init(store: LibraryStore) {
        self.store = store
        self.adScanner = AdScanner(store: store)
        let defaults = UserDefaults.standard
        skipBackSeconds = PlayerOptions.validSkip(defaults.object(forKey: "skipBack") as? Int ?? PlayerOptions.defaultSkip)
        skipForwardSeconds = PlayerOptions.validSkip(defaults.object(forKey: "skipForward") as? Int ?? PlayerOptions.defaultSkip)
        speed = min(2, max(1, defaults.object(forKey: "speed") as? Double ?? 1))
        player.defaultRate = Float(speed)
        skipAds = defaults.bool(forKey: "skipAds")
        trimSilences = defaults.bool(forKey: "trimSilences")
        boostVoices = defaults.bool(forKey: "boostVoices")
        tapState.trimSilences = trimSilences
        tapState.boostVoices = boostVoices
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio, options: [])
        observePlayer()
        setUpRemoteCommands()
        updateRoute()
        adScanner.onUpdate = { [weak self] id, breaks in
            guard let self, id == self.nowPlaying?.episodeID else { return }
            self.adBreaks = breaks
        }
    }

    // MARK: Controls

    /// Plays an episode from where Paul left off (or from the start if played).
    func play(_ episode: PodcastEpisode) {
        if nowPlaying?.episodeID == episode.episodeID {
            resume()
            return
        }
        saveProgress()
        clearChapterStop()
        nowPlaying = NowPlaying(
            episodeID: episode.episodeID,
            title: episode.title,
            showTitle: episode.podcast?.title ?? "",
            artworkURL: episode.artwork,
            audioURL: episode.audioURL
        )
        duration = episode.duration ?? 0
        flushListening()
        store.playingEpisodeID = episode.episodeID
        episode.lastPlayedAt = Date()
        let show = episode.podcast
        currentShowFeed = show?.feedURL
        currentShowTitle = show?.title ?? ""
        applySpeed(for: show)
        // Skip the show's intro (only when starting from the beginning).
        var start = episode.played ? 0 : episode.position
        if let intro = show?.skipIntro, intro > 0, start < intro { start = intro }
        outroSeconds = show?.skipOutro ?? 0
        finishingEarly = false
        currentTime = start
        lastSavedTime = start
        pausedAt = nil
        artwork = nil

        // Play the downloaded copy when there is one, otherwise stream.
        let source = store.localAudioURL(for: episode) ?? episode.audioURL
        let item = AVPlayerItem(url: source)
        item.audioTimePitchAlgorithm = .timeDomain  // Clear speech when sped up.
        player.replaceCurrentItem(with: item)
        hurrying = false
        let tapState = self.tapState
        Task { _ = await tapState.attach(to: item) }
        if start > 1 {
            player.seek(to: CMTime(seconds: start, preferredTimescale: 600))
        }
        resume()
        startBedtimeTimerIfNeeded()
        loadArtwork(episode.artwork)
        showChapters = []
        chapterSource = .show
        loadAnalysis(for: episode)
        adScanner.begin(episode, audio: store.localAudioURL(for: episode))
        loadChapters(episodeID: episode.episodeID, chaptersURL: episode.chaptersURL, audio: source)
    }

    /// Jumps to the start of a chapter.
    func play(chapter: Chapter) {
        seek(to: chapter.start)
        if !isPlaying { resume() }
    }

    func resume() {
        guard nowPlaying != nil else { return }
        if let pausedAt, !isPlaying, abs(currentTime - pausedPosition) < 1,
           UserDefaults.standard.object(forKey: Self.rewindKey) as? Bool ?? true {
            let back = Self.rewind(afterPause: Date().timeIntervalSince(pausedAt))
            if back > 0 { seek(to: max(0, currentTime - back)) }
        }
        pausedAt = nil
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
        if speedIsForShow, let feed = currentShowFeed, let show = store.podcast(feedURL: feed) {
            show.speedOverride = speed
            store.save()
        } else {
            UserDefaults.standard.set(speed, forKey: "speed")
        }
        applyRate()
    }

    /// The show's own speed if it has one, otherwise the global speed.
    private func applySpeed(for show: Podcast?) {
        if let override = show?.speedOverride, override > 0 {
            speed = min(2, max(1, override))
            speedIsForShow = true
        } else {
            speed = min(2, max(1, UserDefaults.standard.object(forKey: "speed") as? Double ?? 1))
            speedIsForShow = false
        }
        applyRate()
    }

    /// Called when a show's settings change, so the playing episode follows them.
    func showSettingsChanged(_ show: Podcast) {
        guard show.feedURL == currentShowFeed else { return }
        applySpeed(for: show)
        outroSeconds = show.skipOutro
    }

    private func applyRate() {
        player.defaultRate = Float(speed)
        if player.timeControlStatus != .paused {
            player.rate = Float(hurrying ? SilenceDetector.trimRate(forSpeed: speed) : speed)
        }
        updateNowPlayingInfo()
    }

    func setTrimSilences(_ on: Bool) {
        trimSilences = on
        tapState.trimSilences = on
        UserDefaults.standard.set(on, forKey: "trimSilences")
        updateTrimTimer()
    }

    func setBoostVoices(_ on: Bool) {
        boostVoices = on
        tapState.boostVoices = on
        UserDefaults.standard.set(on, forKey: "boostVoices")
    }

    /// While trimming, checks a few times a second whether playback is in a
    /// pause and, if so, speeds through it.
    private func updateTrimTimer() {
        let shouldRun = trimSilences && isPlaying
        if shouldRun, trimTimer == nil {
            trimTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.trimTick() }
            }
        } else if !shouldRun {
            trimTimer?.invalidate()
            trimTimer = nil
            if hurrying {
                hurrying = false
                if player.timeControlStatus != .paused { player.rate = Float(speed) }
            }
        }
    }

    private func trimTick() {
        guard player.timeControlStatus == .playing else { return }
        let pause = tapState.inPause
        if pause != hurrying {
            hurrying = pause
            player.rate = Float(pause ? SilenceDetector.trimRate(forSpeed: speed) : speed)
        }
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

    static let lastSleepKey = "lastSleepChoice"

    /// Paul picked a sleep time in the menu: remembered for bedtime.
    func chooseSleepTimer(_ option: SleepTimerOption) {
        switch option {
        case .minutes(let minutes): UserDefaults.standard.set(minutes, forKey: Self.lastSleepKey)
        case .endOfEpisode: UserDefaults.standard.set(0, forKey: Self.lastSleepKey)
        }
        setSleepTimer(option)
    }
    static let bedtimeKey = "bedtimeSleepTimer"

    /// Bedtime sleep timer (off by default): starting an episode between
    /// 10pm and 5am sets the sleep timer to the last one used (end of
    /// episode the first time), unless one is already running.
    private func startBedtimeTimerIfNeeded() {
        let defaults = UserDefaults.standard
        let on = defaults.object(forKey: Self.bedtimeKey) as? Bool ?? false
        let hour = Calendar.current.component(.hour, from: Date())
        guard on, sleepTimer == nil, hour >= 22 || hour < 5 else { return }
        let minutes = defaults.object(forKey: Self.lastSleepKey) as? Int ?? 0
        setSleepTimer(minutes > 0 ? .minutes(minutes) : .endOfEpisode)
    }

    /// Starts (or with nil, cancels) the sleep timer.
    func setSleepTimer(_ option: SleepTimerOption?) {
        sleepTask?.cancel()
        sleepTask = nil
        player.volume = 1
        sleepTimer = option
        sleepEndsAt = nil
        guard case .minutes(let minutes)? = option else { return }
        startSleepCountdown(until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
    }

    /// Five more minutes (shake the phone, or the +5 in the sleep menu).
    func extendSleepTimer(minutes: Int = 5) {
        guard sleepTimer != nil else { return }
        if sleepTimer == .endOfEpisode {
            setSleepTimer(.minutes(minutes))
            return
        }
        let base = max(sleepEndsAt ?? Date(), Date())
        sleepTask?.cancel()
        player.volume = 1
        startSleepCountdown(until: base.addingTimeInterval(TimeInterval(minutes * 60)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Counts down, fades the sound out over the last 10 seconds, then pauses.
    private func startSleepCountdown(until ends: Date) {
        sleepEndsAt = ends
        sleepTask = Task { [weak self] in
            let fade: TimeInterval = 10
            try? await Task.sleep(for: .seconds(max(0, ends.timeIntervalSinceNow - fade)))
            guard !Task.isCancelled, let self else { return }
            for step in 1...20 {
                try? await Task.sleep(for: .seconds(fade / 20))
                guard !Task.isCancelled else {
                    self.player.volume = 1
                    return
                }
                self.player.volume = Float(1 - Double(step) / 20)
            }
            self.pause()
            self.player.volume = 1
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
        if chapterStopTime != nil {
            // Stop at the end of the chapter it lands in.
            if let end = chapterEnd(at: target), end > target + 0.5 {
                chapterStopTime = end
                if chapterFading { player.volume = 1; chapterFading = false }
            } else {
                clearChapterStop()
            }
        }
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlayingInfo() }
        }
        saveProgress()
    }

    func stop() {
        saveProgress()
        flushListening()
        store.playingEpisodeID = nil
        player.replaceCurrentItem(with: nil)
        adScanner.stop()
        clearChapterStop()
        currentAd = nil
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
        skipAdIfNeeded(at: seconds)
        checkChapterStop(at: seconds)
        if player.timeControlStatus == .playing {
            adScanner.playhead(seconds, duration: duration)
        }
        if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0,
           abs(itemDuration - duration) > 1 {
            duration = itemDuration
            if let id = nowPlaying?.episodeID { store.saveDuration(itemDuration, for: id) }
            updateNowPlayingInfo()
        }
        if abs(seconds - lastSavedTime) >= 15 {
            saveProgress()
        }
        countListening()
        // Skip the show's outro: finish early.
        if outroSeconds > 0, duration > outroSeconds + 60, seconds >= duration - outroSeconds, !finishingEarly {
            finishingEarly = true
            didFinish()
        }
    }

    static let afterEpisodeKey = "afterEpisode"

    /// "Mark as played" from the player: finish now, as if it had ended
    /// (marks played, deletes the download, moves on to Up Next).
    func finishEarly() {
        guard nowPlaying != nil, !finishingEarly else { return }
        finishingEarly = true
        didFinish()
    }

    /// Adds real listening time (not paused, not scrubbing) to the stats.
    private func countListening() {
        let now = Date()
        if player.timeControlStatus == .playing, let last = lastListenTick {
            unloggedSeconds += min(now.timeIntervalSince(last), 2)
            // Episode time covered since the last tick (ignoring jumps).
            if let previous = lastContentTime {
                let moved = currentTime - previous
                if moved > 0, moved < 10 { unloggedAdvanced += moved }
            }
        }
        lastListenTick = player.timeControlStatus == .playing ? now : nil
        lastContentTime = player.timeControlStatus == .playing ? currentTime : nil
        if unloggedSeconds >= 30 { flushListening() }
    }

    private func flushListening() {
        if unloggedSeconds > 0 {
            WeekStats.addListening(real: unloggedSeconds, episodeTime: max(unloggedAdvanced, unloggedSeconds))
        }
        unloggedAdvanced = 0
        guard unloggedSeconds > 0, let feed = currentShowFeed else {
            unloggedSeconds = 0
            return
        }
        store.logListening(unloggedSeconds, feedURL: feed, showTitle: currentShowTitle)
        unloggedSeconds = 0
    }

    private func saveProgress() {
        guard let id = nowPlaying?.episodeID else { return }
        lastSavedTime = currentTime
        store.savePosition(currentTime, for: id)
    }

    /// Finished: mark played, remove from Up Next, play the next one.
    private func didFinish() {
        guard let id = nowPlaying?.episodeID else { return }
        // Where it sat in Up Next, for "Next in the list".
        let position = store.queue.firstIndex { $0.episode.id == id }
        store.markPlayed(id)
        if sleepTimer == .endOfEpisode {
            setSleepTimer(nil)
            stop()
            return
        }
        var next: PodcastEpisode?
        // Setting "After an episode": the one that was after it in Up Next,
        // or (default) the top of Up Next.
        let afterInList = UserDefaults.standard.string(forKey: Self.afterEpisodeKey) == "next"
        let start = afterInList ? min(position ?? 0, store.queue.count) : 0
        for item in store.queue[start...] + store.queue[..<start] {
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
            Task { @MainActor in
                guard let self else { return }
                if self.isPlaying, !playing {
                    self.pausedAt = Date()
                    self.pausedPosition = self.currentTime
                }
                self.isPlaying = playing
                self.updateTrimTimer()
            }
        }

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let finishedItem = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, let finishedItem, finishedItem === self.player.currentItem else { return }
                self.didFinish()
            }
        })
        notificationTokens.append(center.addObserver(forName: .episodeAnalysisUpdated, object: nil, queue: .main) { [weak self] note in
            let id = note.object as? String
            MainActor.assumeIsolated {
                guard let self, let id, id == self.nowPlaying?.episodeID, let episode = self.store.episode(id) else { return }
                self.adBreaks = episode.adBreaks
                self.autoChapters = episode.autoChapters
            }
        })
        // Shake to add 5 minutes while the sleep timer is on.
        notificationTokens.append(center.addObserver(forName: .deviceShaken, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.extendSleepTimer() }
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
        // Next / previous track move between chapters (when the episode has
        // them); headphones' double / triple press and the car use these.
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextChapter() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousChapter() }
            return .success
        }
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        guard let nowPlaying else { return }
        let hasChapters = !chapters.isEmpty
        let commands = MPRemoteCommandCenter.shared()
        if commands.nextTrackCommand.isEnabled != hasChapters {
            commands.nextTrackCommand.isEnabled = hasChapters
            commands.previousTrackCommand.isEnabled = hasChapters
        }
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

    /// Ad breaks and auto chapters, which arrive once the transcript is analysed.
    private func loadAnalysis(for episode: PodcastEpisode) {
        // Shows with their own transcript: look for sponsor reads in its text
        // (episodes fetched before this was added have none yet).
        store.transcripts?.findAdsInText(episode)
        adBreaks = episode.adBreaks
        autoChapters = episode.autoChapters
        allowedAds = []
        lastSkippedAd = nil
    }

    private func skipAdIfNeeded(at time: TimeInterval) {
        let adBreak = adBreaks.first { $0.contains(time) && !allowedAds.contains($0.start) }
        if currentAd != adBreak { currentAd = adBreak }
        guard skipAds, player.timeControlStatus != .paused, let adBreak else { return }
        skip(adBreak)
    }

    /// The Skip ad button: jumps to where the show resumes.
    func skipCurrentAd() {
        if let currentAd { skip(currentAd) }
    }

    private func skip(_ adBreak: AdBreak) {
        WeekStats.addSkippedAd(seconds: max(0, adBreak.end - max(currentTime, adBreak.start)))
        seek(to: adBreak.end)
        currentAd = nil
        lastSkippedAd = adBreak
        skippedNoteTask?.cancel()
        skippedNoteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            self?.lastSkippedAd = nil
        }
    }

    func setSkipAds(_ on: Bool) {
        skipAds = on
        UserDefaults.standard.set(on, forKey: "skipAds")
    }

    /// "Play ad": goes back and plays this break once.
    func playAd(_ adBreak: AdBreak) {
        allowedAds.insert(adBreak.start)
        lastSkippedAd = nil
        seek(to: adBreak.start)
    }

    /// "Not an ad": it's never skipped again, and playback goes back to it.
    func notAnAd(_ adBreak: AdBreak, transcripts: TranscriptService) {
        guard let id = nowPlaying?.episodeID else { return }
        transcripts.notAnAd(adBreak, in: id)
        adBreaks.removeAll { $0 == adBreak }
        if lastSkippedAd == adBreak {
            lastSkippedAd = nil
            seek(to: adBreak.start)
        }
    }

    private func loadChapters(episodeID: String, chaptersURL: URL?, audio: URL) {
        Task {
            var found: [Chapter] = []
            if let chaptersURL, let data = try? await URLSession.shared.data(from: chaptersURL).0 {
                found = (try? Chapters.parseJSON(data)) ?? []
            }
            if found.isEmpty {
                found = await Self.embeddedChapters(in: audio)
            }
            guard nowPlaying?.episodeID == episodeID else { return }
            showChapters = Chapters.tidy(found, duration: duration > 0 ? duration : nil)
        }
    }

    /// Chapters stored inside the audio file (common in AAC/M4A podcasts).
    nonisolated private static func embeddedChapters(in url: URL) async -> [Chapter] {
        let asset = AVURLAsset(url: url)
        guard let groups = try? await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: Locale.preferredLanguages) else {
            return []
        }
        var chapters: [Chapter] = []
        for group in groups {
            let start = group.timeRange.start.seconds
            let end = group.timeRange.end.seconds
            guard start.isFinite else { continue }
            let titleItem = AVMetadataItem.metadataItems(from: group.items, filteredByIdentifier: .commonIdentifierTitle).first
            let title = (try? await titleItem?.load(.stringValue)) ?? nil
            chapters.append(Chapter(start: start, end: end.isFinite ? end : nil, title: title ?? ""))
        }
        return chapters
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
