import Foundation
import FluidAudio
import PodcastCore

/// "Who spoke when", on the iPhone, using the open-source FluidAudio
/// library (pyannote-style speaker separation in Core ML). Its models
/// (about 30 MB) download once, free, the first time it runs.
enum SpeakerSeparation {
    /// The "Label speakers" setting (default on).
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "labelSpeakers") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "labelSpeakers") }
    }

    /// Speaker turns in a downloaded episode; empty if switched off or it fails
    /// (the transcript is still saved, just without labels).
    static func turns(in audio: URL) async -> [PodcastCore.SpeakerLabels.Turn] {
        guard isEnabled else { return [] }
        do {
            var config = OfflineDiarizerConfig.default
            // Fewer windows per pass keeps memory around 100 MB on the phone.
            config.segmentation.batchSize = 8
            let manager = OfflineDiarizerManager(config: config)
            try await manager.prepareModels()
            let result = try await manager.process(audio)
            return result.segments.map {
                PodcastCore.SpeakerLabels.Turn(speaker: $0.speakerId, start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds))
            }
        } catch {
            return []
        }
    }
}
