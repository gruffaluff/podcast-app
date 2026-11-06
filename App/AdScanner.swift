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
        get { UserDefaults.standard.object(forKey: "findAdsWhileListening") as? Bool ?? false }
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
    /// The show supplies its own transcript (which lacks the ads inserted
    /// into Paul's download, so it needs lining up with the audio).
    private var hasShowTranscript = false
    /// Stretches already sync-checked this session.
    private var synced: [ClosedRange<TimeInterval>] = []

    /// Sync check (works with Find ads off): one short sample every
    /// `syncEvery` seconds of audio, a little ahead of where Paul is.
    static let syncSample: TimeInterval = 25
    static let syncEvery: TimeInterval = 150

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
        synced = []
        hasShowTranscript = episode.transcriptFile.flatMap(TranscriptFiles.load)?.source == .publisher
    }

    /// Called as playback moves; starts the next slice when one is due.
    func playhead(_ time: TimeInterval, duration knownDuration: TimeInterval) {
        guard task == nil, let audio, let id = episodeID else { return }
        duration = max(duration, knownDuration)
        guard Self.isEnabled else {
            if hasShowTranscript { syncCheck(at: time, audio: audio, id: id) }
            return
        }
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

    /// Keeps the show's transcript in step without Find ads: a 25-second
    /// sample every 2½ minutes just ahead of the playhead (about a sixth of
    /// the work of Find ads), matched word for word against the transcript.
    private func syncCheck(at time: TimeInterval, audio: URL, id: String) {
        guard let cell = AdScanPlan.nextSlice(playhead: time, scanned: synced, duration: duration) else { return }
        let start = cell.lowerBound
        let sample = start...min(duration, start + Self.syncSample)
        let covered = start...min(duration, start + Self.syncEvery)
        task = Task { [weak self] in
            let words = (try? await OnDeviceTranscriber.words(in: audio, slice: sample)) ?? []
            guard let self else { return }
            self.task = nil
            guard !Task.isCancelled, self.episodeID == id else { return }
            self.synced = AdScanPlan.adding(covered, to: self.synced)
            self.syncTranscript(id, heard: words)
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
