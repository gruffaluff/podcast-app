import Foundation
import PodcastCore

/// "Find ads while listening": while a downloaded episode plays, checks the
/// next few minutes for sponsor reads (a short on-device transcription of
/// just that slice), so a Skip ad button is ready when an ad starts. Far
/// lighter than transcribing whole episodes; only runs while listening.
@MainActor
final class AdScanner {
    /// The "Find ads while listening" setting (default on).
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "findAdsWhileListening") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "findAdsWhileListening") }
    }

    /// Called with the episode's ad breaks whenever more are found.
    var onUpdate: ((String, [AdBreak]) -> Void)?

    private let store: LibraryStore
    private var episodeID: String?
    private var audio: URL?
    private var duration: TimeInterval = 0
    private var scanned: [ClosedRange<TimeInterval>] = []
    private var task: Task<Void, Never>?

    init(store: LibraryStore) {
        self.store = store
    }

    /// A new episode started playing.
    func begin(_ episode: PodcastEpisode, audio: URL?) {
        task?.cancel()
        task = nil
        episodeID = episode.episodeID
        self.audio = audio
        duration = episode.duration ?? 0
        scanned = episode.adScanned
    }

    /// Called as playback moves; starts the next slice when one is due.
    func playhead(_ time: TimeInterval, duration knownDuration: TimeInterval) {
        guard Self.isEnabled, task == nil, let audio, let id = episodeID else { return }
        duration = max(duration, knownDuration)
        guard let slice = AdScanPlan.nextSlice(playhead: time, scanned: scanned, duration: duration) else { return }

        task = Task { [weak self] in
            let words = (try? await OnDeviceTranscriber.words(in: audio, slice: slice)) ?? []
            let breaks = AdDetection.breaks(in: TranscriptLayout.lines(from: words))
            guard let self else { return }
            self.task = nil
            guard !Task.isCancelled, self.episodeID == id else { return }
            self.syncTranscript(id, heard: words)
            // Marked as checked even if it failed, so it isn't retried endlessly.
            self.scanned = AdScanPlan.adding(slice, to: self.scanned)
            let all = self.store.addAdBreaks(breaks, scanned: slice, to: id)
            self.onUpdate?(id, all)
        }
    }

    /// The same words line the show's transcript up with this audio.
    private func syncTranscript(_ id: String, heard words: [TranscriptSegment]) {
        guard let episode = store.episode(id), let file = episode.transcriptFile,
              let transcript = TranscriptFiles.load(file), transcript.source == .publisher,
              let anchor = TranscriptAlign.anchor(heard: words, transcript: transcript.segments) else { return }
        episode.syncAnchors = TranscriptAlign.adding(anchor, to: episode.syncAnchors)
        store.save()
    }

    func stop() {
        task?.cancel()
        task = nil
        episodeID = nil
        audio = nil
    }
}
