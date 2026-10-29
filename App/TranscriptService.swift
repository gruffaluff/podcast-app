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
            case .whileCharging: return "Automatically while charging"
            case .onRequest: return "Only when I ask"
            }
        }

        var explanation: String {
            switch self {
            case .whenDownloaded: return "Up Next episodes are transcribed as soon as they download."
            case .whileCharging: return "Transcribes while your iPhone is plugged in, including overnight."
            case .onRequest: return "Nothing is transcribed until you tap Transcribe now on an episode."
            }
        }
    }

    var schedule: Schedule = .onRequest {
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
        self.schedule = UserDefaults.standard.string(forKey: "transcriptSchedule").flatMap(Schedule.init(rawValue:)) ?? .onRequest
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
        let words = try await speech(in: audio)
        // Then who spoke when (one job at a time keeps the phone cool).
        let turns = await SpeakerSeparation.turns(in: audio)
        let segments = SpeakerLabels.assign(turns, to: words)
        return Transcript(source: .onDevice, segments: segments, music: await music)
    }

    /// A transcriber with word timings (so words can be matched to speakers),
    /// its speech model installed (iOS downloads it the first time).
    static func makeTranscriber() async throws -> SpeechTranscriber {
        var locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
        if locale == nil { locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")) }
        guard let locale else { throw Failure.languageNotSupported }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        return transcriber
    }

    /// Words in one slice of the audio (for finding ads while listening).
    /// Times are from the start of the episode.
    static func words(in audio: URL, slice: ClosedRange<TimeInterval>) async throws -> [TranscriptSegment] {
        let transcriber = try await makeTranscriber()
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { throw Failure.languageNotSupported }

        // Read the slice and convert it to the format the analyzer wants.
        let file = try AVAudioFile(forReading: audio)
        let source = file.processingFormat
        let startFrame = AVAudioFramePosition(slice.lowerBound * source.sampleRate)
        guard startFrame < file.length else { return [] }
        file.framePosition = startFrame
        let frames = AVAudioFrameCount(min(Double(file.length - startFrame), (slice.upperBound - slice.lowerBound) * source.sampleRate))
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames) else { return [] }
        try file.read(into: input, frameCount: frames)
        let converted = try convert(input, to: format)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let collector = Task { () -> [TranscriptSegment] in
            var words: [TranscriptSegment] = []
            for try await result in transcriber.results where result.isFinal {
                words += wordSegments(of: result)
            }
            return words
        }
        continuation.yield(AnalyzerInput(buffer: converted))
        continuation.finish()
        do {
            if let lastSample = try await analyzer.analyzeSequence(stream) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            collector.cancel()
            throw error
        }
        return try await collector.value.map { word in
            var shifted = word
            shifted.start += slice.lowerBound
            shifted.end += slice.lowerBound
            return shifted
        }
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == format { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { throw Failure.languageNotSupported }
        converter.primeMethod = .none  // keeps timings exact
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 4096
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { throw Failure.languageNotSupported }
        var supplied = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if supplied {
                status.pointee = .endOfStream
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if let conversionError { throw conversionError }
        return output
    }

    private static func speech(in audio: URL) async throws -> [TranscriptSegment] {
        let transcriber = try await makeTranscriber()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: audio)

        let collector = Task { () -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            for try await result in transcriber.results where result.isFinal {
                let words = wordSegments(of: result)
                if !words.isEmpty {
                    segments += words
                    continue
                }
                // No word timings: keep the phrase as one piece.
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

extension OnDeviceTranscriber {
    /// One segment per timed word; text without a time (e.g. punctuation)
    /// joins the word before it.
    static func wordSegments(of result: SpeechTranscriber.Result) -> [TranscriptSegment] {
        var words: [TranscriptSegment] = []
        for run in result.text.runs {
            let text = String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if let range = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self], range.start.seconds.isFinite {
                let end = range.end.seconds
                words.append(TranscriptSegment(start: range.start.seconds, end: end.isFinite ? end : range.start.seconds, text: text))
            } else if !words.isEmpty {
                words[words.count - 1].text += text
            }
        }
        return words
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
