import AVFoundation
import BackgroundTasks
import Foundation
import Observation
import SoundAnalysis
import Speech
import UIKit
import PodcastCore

extension Notification.Name {
    /// An episode's ad breaks or auto chapters changed (object: episode ID).
    static let episodeAnalysisUpdated = Notification.Name("episodeAnalysisUpdated")
}

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
/// Up Next order first, following Paul's schedule; "Transcribe now" skips
/// the schedule for one episode.
@MainActor
@Observable
final class TranscriptService {
    static let backgroundTaskID = "com.gruffaluff.podcasts.transcribe"

    /// When on-device transcription runs by itself.
    enum Schedule: String, CaseIterable, Identifiable {
        case whenDownloaded
        case whileCharging
        case onRequest

        var id: String { rawValue }

        var label: String {
            switch self {
            case .whenDownloaded: return "As soon as downloaded"
            case .whileCharging: return "While charging"
            case .onRequest: return "Only when I ask"
            }
        }

        var explanation: String {
            switch self {
            case .whenDownloaded: return "Up Next episodes are transcribed as soon as they download."
            case .whileCharging: return "Transcribes while your iPhone is plugged in, including overnight."
            case .onRequest: return "Nothing is transcribed until you tap Transcribe now."
            }
        }
    }

    var schedule: Schedule = .whenDownloaded {
        didSet {
            UserDefaults.standard.set(schedule.rawValue, forKey: "transcriptSchedule")
            startWorker()
        }
    }

    /// The episode being transcribed on the iPhone right now.
    private(set) var current: String?

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var pending: [String] = []
    @ObservationIgnored private var worker: Task<Void, Never>?
    /// Episodes Paul asked for with "Transcribe now"; these ignore the schedule.
    private var requested: Set<String> = []
    @ObservationIgnored private var batteryObserver: NSObjectProtocol?

    init(store: LibraryStore) {
        self.store = store
        self.schedule = UserDefaults.standard.string(forKey: "transcriptSchedule").flatMap(Schedule.init(rawValue:)) ?? .whenDownloaded
        store.transcripts = self

        // Start (or resume) when the phone is plugged in.
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryObserver = NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.startWorker() }
        }
    }

    private var isCharging: Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    /// Whether episodes nobody asked for may be transcribed right now.
    private var scheduleAllowsWork: Bool {
        switch schedule {
        case .whenDownloaded: return true
        case .whileCharging: return isCharging
        case .onRequest: return false
        }
    }

    /// Whether this episode is waiting for a transcript that isn't being made yet.
    func canTranscribeNow(_ episode: PodcastEpisode) -> Bool {
        episode.transcriptState != .ready && episode.transcriptState != .transcribing && !requested.contains(episode.episodeID)
    }

    /// "Transcribe now": straight away, whatever the schedule. Downloads the
    /// episode first if needed (transcripts are made from the audio file).
    func transcribeNow(_ episode: PodcastEpisode) {
        let id = episode.episodeID
        requested.insert(id)
        if episode.transcriptState == .failed { episode.transcriptState = .none }
        if store.localAudioURL(for: episode) == nil && episode.transcriptURL == nil {
            store.downloads?.download(episode)
            episode.transcriptState = .waiting
            return
        }
        prepare(episode, urgent: true)
    }

    /// "Transcribe Up Next now".
    func transcribeUpNextNow() {
        let episodes = store.episodes(store.queue.map(\.episode.id))
        for item in store.queue.reversed() {
            if let episode = episodes[item.episode.id], episode.transcriptState != .ready {
                transcribeNow(episode)
            }
        }
    }

    // MARK: Requests

    /// Makes sure this episode gets a transcript. `urgent` puts it first in
    /// line (e.g. Paul opened its transcript).
    func prepare(_ episode: PodcastEpisode, urgent: Bool = false) {
        let id = episode.episodeID
        let hasTranscript = episode.transcriptState == .ready && episode.transcriptFile.flatMap(TranscriptFiles.load) != nil
        let downloaded = store.localAudioURL(for: episode) != nil
        // Done, unless the show's own transcript is in hand but ads haven't
        // been looked for in Paul's download yet (ads differ per download).
        if hasTranscript && (episode.adsChecked || !downloaded) { return }

        if !hasTranscript, let url = episode.transcriptURL, episode.transcriptState != .failed {
            Task { await fetchPublisherTranscript(id: id, url: url) }
            return
        }
        guard downloaded else {
            episode.transcriptState = .waiting
            return
        }
        if urgent || requested.contains(id) {
            pending.removeAll { $0 == id }
            pending.insert(id, at: 0)
        } else if !pending.contains(id), current != id {
            pending.append(id)
        }
        if !hasTranscript, episode.transcriptState != .transcribing { episode.transcriptState = .waiting }
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
            while !Task.isCancelled, let index = nextIndex() {
                let id = pending.remove(at: index)
                guard let episode = store.episode(id), let audio = store.localAudioURL(for: episode) else { continue }
                current = id
                let hadTranscript = episode.transcriptState == .ready
                if !hadTranscript { episode.transcriptState = .transcribing }
                do {
                    let transcript = try await OnDeviceTranscriber.transcribe(audio)
                    if let episode = store.episode(id) { finish(episode, with: transcript) }
                } catch {
                    if let episode = store.episode(id) {
                        // Cancelled (e.g. background time ran out): try again later.
                        if !hadTranscript { episode.transcriptState = Task.isCancelled ? .waiting : .failed }
                        if !Task.isCancelled { episode.adsChecked = true }
                        if Task.isCancelled { pending.insert(id, at: 0) }
                    }
                }
                current = nil
                requested.remove(id)
                store.save()
            }
            worker = nil
        }
    }

    /// Next job: anything Paul asked for first, then (if the schedule
    /// allows) the rest in Up Next order.
    private func nextIndex() -> Int? {
        if let index = pending.firstIndex(where: requested.contains) { return index }
        return scheduleAllowsWork && !pending.isEmpty ? 0 : nil
    }

    private func finish(_ episode: PodcastEpisode, with transcript: Transcript) {
        var saved = transcript
        if transcript.source == .onDevice, let existing = self.transcript(for: episode), existing.source == .publisher {
            // Keep the show's transcript for reading; ours supplies the music
            // and the timings of Paul's own download.
            saved = existing
            saved.music = transcript.music
        }
        let name = TranscriptFiles.name(for: episode.episodeID)
        do {
            try TranscriptFiles.save(saved, as: name)
            episode.transcriptFile = name
            episode.transcriptState = .ready
        } catch {
            episode.transcriptState = .failed
        }
        analyse(episode, timing: transcript)
        store.save()
    }

    /// Finds ad breaks (only from an on-device transcript of the download)
    /// and makes chapters when the show supplies none.
    private func analyse(_ episode: PodcastEpisode, timing transcript: Transcript) {
        let id = episode.episodeID
        let lines = TranscriptLayout.lines(from: transcript.segments)
        if transcript.source == .onDevice {
            let dismissed = episode.dismissedAds
            episode.adBreaks = AdDetection.breaks(in: lines, music: transcript.music)
                .filter { ad in !dismissed.contains { abs($0 - ad.start) < 5 } }
            episode.adsChecked = true
        }
        if episode.chaptersURL == nil {
            let duration = episode.duration ?? lines.last?.end ?? 0
            let chapters = ChapterMaker.chapters(lines: lines, music: transcript.music, ads: episode.adBreaks, duration: duration)
            episode.autoChapters = chapters
            // Nicer titles from Apple's on-device language model, when the phone has it.
            Task {
                let titled = await ChapterTitler.retitle(chapters, lines: lines)
                guard titled != chapters, let episode = store.episode(id) else { return }
                episode.autoChapters = titled
                store.save()
                NotificationCenter.default.post(name: .episodeAnalysisUpdated, object: id)
            }
        }
        NotificationCenter.default.post(name: .episodeAnalysisUpdated, object: id)
    }

    /// "Not an ad": forget this break, and don't find it again.
    func notAnAd(_ adBreak: AdBreak, in episodeID: String) {
        guard let episode = store.episode(episodeID) else { return }
        episode.adBreaks.removeAll { $0 == adBreak }
        episode.dismissedAds.append(adBreak.start)
        episode.autoChapters = episode.autoChapters.filter { !($0.isAd && abs($0.start - adBreak.start) < 1) }
        store.save()
        NotificationCenter.default.post(name: .episodeAnalysisUpdated, object: episodeID)
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
        guard schedule != .onRequest, !pending.isEmpty || worker != nil else { return }
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
