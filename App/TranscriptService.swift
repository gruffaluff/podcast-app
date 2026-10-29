import AVFoundation
import BackgroundTasks
import Foundation
import Observation
import SoundAnalysis
import Speech
import PodcastCore

/// Where transcripts live: Application Support/Transcripts, one JSON file
/// per episode. They're small, kept after an episode is played (for search
/// and bookmarks), and deleted when a show is unfollowed.
enum TranscriptFiles {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Transcripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static func name(for episodeID: String) -> String {
        DownloadNaming.stableHash(episodeID) + ".json"
    }

    static func save(_ transcript: Transcript, as name: String) throws {
        try JSONEncoder().encode(transcript).write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static func load(_ name: String) -> Transcript? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(Transcript.self, from: data)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}

/// Gets every Up Next episode a transcript: the publisher's when the feed
/// has one, otherwise one made on the iPhone from the downloaded audio
/// (speech-to-text plus music detection). Works one episode at a time,
/// Up Next order first; continues overnight while charging.
@MainActor
@Observable
final class TranscriptService {
    static let backgroundTaskID = "com.gruffaluff.podcasts.transcribe"

    /// The episode being transcribed on the iPhone right now.
    private(set) var current: String?

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var pending: [String] = []
    @ObservationIgnored private var worker: Task<Void, Never>?

    init(store: LibraryStore) {
        self.store = store
        store.transcripts = self
    }

    // MARK: Requests

    /// Makes sure this episode gets a transcript. `urgent` puts it first in
    /// line (e.g. Paul opened its transcript).
    func prepare(_ episode: PodcastEpisode, urgent: Bool = false) {
        guard episode.transcriptState != .ready || episode.transcriptFile.flatMap(TranscriptFiles.load) == nil else { return }
        let id = episode.episodeID

        if let url = episode.transcriptURL, episode.transcriptState != .failed {
            Task { await fetchPublisherTranscript(id: id, url: url) }
            return
        }
        guard store.localAudioURL(for: episode) != nil else {
            episode.transcriptState = .waiting
            return
        }
        if urgent {
            pending.removeAll { $0 == id }
            pending.insert(id, at: 0)
        } else if !pending.contains(id), current != id {
            pending.append(id)
        }
        if episode.transcriptState != .transcribing { episode.transcriptState = .waiting }
        startWorker()
    }

    /// Everything in Up Next, in order.
    func prepareUpNext() {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        for item in store.queue {
            if let episode = episodes[item.episode.id] { prepare(episode) }
        }
    }

    func transcript(for episode: PodcastEpisode) -> Transcript? {
        guard episode.transcriptState == .ready, let name = episode.transcriptFile else { return nil }
        return TranscriptFiles.load(name)
    }

    // MARK: Publisher transcripts

    private func fetchPublisherTranscript(id: String, url: URL) async {
        let segments = await Task.detached { () -> [TranscriptSegment]? in
            guard let data = try? await URLSession.shared.data(from: url).0 else { return nil }
            return try? TranscriptParser.parse(data)
        }.value
        guard let episode = store.episode(id) else { return }
        if let segments, !segments.isEmpty {
            finish(episode, with: Transcript(source: .publisher, segments: segments))
        } else {
            // Couldn't use it: fall back to transcribing on the iPhone.
            episode.transcriptState = .failed
            episode.transcriptURL = nil
            store.save()
            prepare(episode)
        }
    }

    // MARK: On-device

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task {
            while !Task.isCancelled, !pending.isEmpty {
                let id = pending.removeFirst()
                guard let episode = store.episode(id), let audio = store.localAudioURL(for: episode) else { continue }
                current = id
                episode.transcriptState = .transcribing
                do {
                    let transcript = try await OnDeviceTranscriber.transcribe(audio)
                    if let episode = store.episode(id) { finish(episode, with: transcript) }
                } catch {
                    if let episode = store.episode(id) {
                        // Cancelled (e.g. background time ran out): try again later.
                        episode.transcriptState = Task.isCancelled ? .waiting : .failed
                        if Task.isCancelled { pending.insert(id, at: 0) }
                    }
                }
                current = nil
                store.save()
            }
            worker = nil
        }
    }

    private func finish(_ episode: PodcastEpisode, with transcript: Transcript) {
        let name = TranscriptFiles.name(for: episode.episodeID)
        do {
            try TranscriptFiles.save(transcript, as: name)
            episode.transcriptFile = name
            episode.transcriptState = .ready
        } catch {
            episode.transcriptState = .failed
        }
        store.save()
    }

    // MARK: Background (overnight while charging)

    /// Called at launch. Lets iOS run transcription while the phone charges.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskID, using: nil) { task in
            Task { @MainActor [weak self] in
                guard let self else { task.setTaskCompleted(success: false); return }
                task.expirationHandler = {
                    Task { @MainActor in self.worker?.cancel() }
                }
                self.prepareUpNext()
                await self.worker?.value
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// Called when the app goes to the background with work left.
    func scheduleBackgroundWork() {
        guard !pending.isEmpty || worker != nil else { return }
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskID)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// Speech-to-text and music detection on the iPhone, using Apple's
/// SpeechAnalyzer and the built-in sound classifier. Nothing leaves the phone.
enum OnDeviceTranscriber {
    enum Failure: LocalizedError {
        case languageNotSupported
        var errorDescription: String? { "On-device transcription doesn't support this language yet." }
    }

    static func transcribe(_ audio: URL) async throws -> Transcript {
        async let music = MusicDetector.spans(in: audio)
        let segments = try await speech(in: audio)
        return Transcript(source: .onDevice, segments: segments, music: await music)
    }

    private static func speech(in audio: URL) async throws -> [TranscriptSegment] {
        var locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
        if locale == nil { locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")) }
        guard let locale else { throw Failure.languageNotSupported }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        // The speech model is downloaded by iOS the first time.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: audio)

        let collector = Task { () -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            for try await result in transcriber.results where result.isFinal {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                let start = result.range.start.seconds
                let end = result.range.end.seconds
                guard !text.isEmpty, start.isFinite else { continue }
                segments.append(TranscriptSegment(start: start, end: end.isFinite ? end : start, text: text))
            }
            return segments
        }
        do {
            if let lastSample = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            throw error
        }
        return try await collector.value
    }
}

/// Finds music in the audio with Apple's built-in sound classifier.
enum MusicDetector {
    static func spans(in audio: URL) async -> [MusicSpan] {
        guard let analyzer = try? SNAudioFileAnalyzer(url: audio),
              let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else { return [] }
        let observer = MusicObserver()
        guard (try? analyzer.add(request, withObserver: observer)) != nil else { return [] }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            analyzer.analyze { _ in continuation.resume() }
        }
        return MusicDetection.spans(from: observer.windows)
    }
}

private final class MusicObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var found: [MusicDetection.Window] = []

    var windows: [MusicDetection.Window] {
        lock.lock()
        defer { lock.unlock() }
        return found
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let confidence = result.classification(forIdentifier: "music")?.confidence ?? 0
        let window = MusicDetection.Window(start: result.timeRange.start.seconds, duration: result.timeRange.duration.seconds, confidence: confidence)
        lock.lock()
        found.append(window)
        lock.unlock()
    }
}
