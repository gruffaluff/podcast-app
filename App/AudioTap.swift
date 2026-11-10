import AVFoundation
import MediaToolbox
import PodcastCore

/// Sits in the audio path of the playing episode. Applies "Boost voices",
/// measures loudness for "Trim silences" and pitch bands for the level
/// bars. Settings are read on the audio thread, so they're plain flags
/// rather than observed properties.
final class AudioTapState: @unchecked Sendable {
    var boostVoices = false
    var trimSilences = false
    /// Set on the audio thread; read by the player to speed through pauses.
    var inPause = false
    /// Power per pitch band, low to high (`BandMeter`): drives the player's
    /// level bars. Written on the audio thread, read for display only.
    private let bands: UnsafeMutablePointer<Float> = {
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: BandMeter.bandCount)
        pointer.initialize(repeating: 0, count: BandMeter.bandCount)
        return pointer
    }()
    fileprivate var meter: BandMeter?

    deinit { bands.deallocate() }

    /// A copy of the latest band powers (all zero before any sound).
    func bandLevels() -> [Float] {
        Array(UnsafeBufferPointer(start: bands, count: BandMeter.bandCount))
    }

    fileprivate var sampleRate: Double = 44_100
    fileprivate var boosters: [VoiceBoost] = []
    fileprivate var detector = SilenceDetector()

    /// Adds the tap to an item's audio. Returns false if it couldn't be added
    /// (the episode then just plays without these effects).
    func attach(to item: AVPlayerItem) async -> Bool {
        guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first else { return false }

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: nil,
            process: tapProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        guard status == noErr, let tap else {
            Unmanaged<AudioTapState>.fromOpaque(callbacks.clientInfo!).release()
            return false
        }

        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        await MainActor.run { item.audioMix = mix }
        return true
    }

    fileprivate func prepare(sampleRate: Double, channels: Int) {
        self.sampleRate = sampleRate
        // No boosters (so no processing at all) for formats we don't handle.
        boosters = Array(repeating: VoiceBoost(), count: channels)
        detector = SilenceDetector()
        inPause = false
        if meter == nil || sampleRate != meterRate {
            // An old tap may still be using the old meter, so keep it alive.
            if let old = meter { retiredMeters.append(old) }
            meter = BandMeter(sampleRate: sampleRate)
            meterRate = sampleRate
        }
    }
    fileprivate var meterRate: Double = 0
    private var retiredMeters: [BandMeter] = []

    fileprivate func process(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
        if let first = buffers.first, let data = first.mData {
            let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(first.mDataByteSize) / MemoryLayout<Float>.size)
            let rms = SilenceDetector.rms(samples)
            meter?.analyse(samples, into: bands)
            inPause = trimSilences ? detector.feed(rms: rms, duration: Double(frames) / sampleRate) : false
        } else {
            inPause = false
        }

        guard boostVoices else { return }
        for (index, buffer) in buffers.enumerated() where index < boosters.count {
            guard let data = buffer.mData else { continue }
            let samples = UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
            boosters[index].process(samples, sampleRate: sampleRate)
        }
    }
}

// MARK: C callbacks

private func tapInit(_ tap: MTAudioProcessingTap, _ clientInfo: UnsafeMutableRawPointer?, _ storageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) {
    storageOut.pointee = clientInfo
}

private func tapFinalize(_ tap: MTAudioProcessingTap) {
    Unmanaged<AudioTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

private func tapPrepare(_ tap: MTAudioProcessingTap, _ maxFrames: CMItemCount, _ format: UnsafePointer<AudioStreamBasicDescription>) {
    let state = Unmanaged<AudioTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    let description = format.pointee
    // Effects expect non-interleaved 32-bit float, which is what taps get.
    let isFloat = description.mFormatFlags & kAudioFormatFlagIsFloat != 0
    let channels = isFloat ? Int(description.mChannelsPerFrame) : 0
    state.prepare(sampleRate: description.mSampleRate, channels: channels)
}

private func tapProcess(
    _ tap: MTAudioProcessingTap,
    _ frameCount: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferList: UnsafeMutablePointer<AudioBufferList>,
    _ framesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    guard MTAudioProcessingTapGetSourceAudio(tap, frameCount, bufferList, flagsOut, nil, framesOut) == noErr else { return }
    let state = Unmanaged<AudioTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    guard !state.boosters.isEmpty else { return }
    state.process(UnsafeMutableAudioBufferListPointer(bufferList), frames: Int(framesOut.pointee))
}
