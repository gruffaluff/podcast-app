import AVFoundation
import SwiftUI
import UIKit
import PodcastCore

/// "Share a clip": a quote card for a transcript line, 5–30 seconds long,
/// optionally with the audio, a link to the moment, or as a video card.
struct ClipView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let episode: PodcastEpisode
    let line: TranscriptLayout.Line
    let quote: String

    @State private var length: TimeInterval = 15
    @State private var includeAudio = true
    @State private var includeLink = true
    @State private var videoCard = false
    @State private var bars: [Double] = Array(repeating: 0.3, count: 40)
    @State private var artwork: UIImage?
    @State private var working = false
    @State private var failure: String?
    @State private var shareItems: ShareItems?

    private var audioFile: URL? { store.localAudioURL(for: episode) }
    private var range: ClosedRange<TimeInterval> { Clips.range(start: line.start, length: length, duration: episode.duration) }
    private var cardColor: Color { ArtworkColors.shared.background(for: episode.artwork) ?? Theme.ink }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    card
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Theme.background)
                }
                Section {
                    HStack {
                        Text("Length").foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Int(length)) sec").monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    waveform
                    HStack {
                        Button("− 5 sec") { length = Clips.clamp(length - Clips.step) }
                            .disabled(length <= Clips.lengths.lowerBound)
                        Spacer()
                        Button("+ 5 sec") { length = Clips.clamp(length + Clips.step) }
                            .disabled(length >= Clips.lengths.upperBound)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accentText)
                }
                Section {
                    Toggle("Include audio", isOn: $includeAudio).disabled(audioFile == nil)
                    Toggle("Link to the moment", isOn: $includeLink).disabled(linkTarget == nil)
                    Toggle("Video card (for messages and social)", isOn: $videoCard).disabled(audioFile == nil)
                } footer: {
                    Text(audioFile == nil ? "Download the episode to include its audio." : "The clip is cut on your iPhone from the downloaded episode.")
                }
                .tint(Theme.accentFill)
                if let failure {
                    Text(failure).foregroundStyle(Theme.accentText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Share a clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Share") { Task { await share() } }.fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $shareItems) { ActivityView(items: $0.items) }
            .task { await prepare() }
        }
    }

    private var linkTarget: URL? { episode.webLink ?? episode.podcast?.website }

    // MARK: Card

    private var card: some View {
        QuoteCard(quote: quote, show: episode.podcast?.title ?? "", episode: episode.title, time: range.lowerBound, artwork: artwork, background: cardColor)
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var waveform: some View {
        let selected = Int((Double(bars.count) * length / Clips.lengths.upperBound).rounded())
        return HStack(alignment: .center, spacing: 2) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule()
                    .fill(index < selected ? Theme.accentFill : Theme.controlBorder)
                    .frame(height: max(3, 36 * bars[index]))
            }
        }
        .frame(height: 40)
        .accessibilityHidden(true)
    }

    // MARK: Work

    private func prepare() async {
        length = Clips.defaultLength(lineStart: line.start, lineEnd: line.end)
        includeAudio = audioFile != nil
        includeLink = linkTarget != nil
        await ArtworkColors.shared.load(episode.artwork)
        if let url = episode.artwork, let data = try? await URLSession.shared.data(from: url).0 {
            artwork = UIImage(data: data)
        }
        if let audioFile {
            let start = line.start
            let samples = await Task.detached { ClipExporter.samples(from: audioFile, start: start, seconds: Clips.lengths.upperBound) }.value
            bars = Clips.waveform(samples, count: 40)
        }
    }

    private func share() async {
        working = true
        failure = nil
        defer { working = false }
        let range = self.range
        var items: [Any] = []

        let text = Clips.shareText(quote: quote, show: episode.podcast?.title ?? "", episode: episode.title, at: range.lowerBound, link: includeLink ? linkTarget : nil)
        guard let image = renderCard() else { failure = "Couldn't make the card."; return }

        do {
            if let audioFile, includeAudio || videoCard {
                let audio = try await ClipExporter.audio(from: audioFile, range: range)
                if videoCard {
                    items.append(try await ClipExporter.video(image: image, audio: audio, duration: range.upperBound - range.lowerBound))
                } else {
                    items.append(image)
                    items.append(audio)
                }
            } else {
                items.append(image)
            }
        } catch {
            failure = "Couldn't cut the audio clip. (\(error.localizedDescription))"
            return
        }
        items.append(text)

        // Keep it in My clips.
        let clip = Bookmark(episodeID: episode.episodeID, time: range.lowerBound, text: quote)
        clip.length = range.upperBound - range.lowerBound
        context.insert(clip)
        try? context.save()

        shareItems = ShareItems(items: items)
    }

    @MainActor
    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content:
            QuoteCard(quote: quote, show: episode.podcast?.title ?? "", episode: episode.title, time: range.lowerBound, artwork: artwork, background: cardColor)
                .frame(width: 360, height: 360)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// The square card: the quote in serif on the artwork's colour, with the
/// show, episode and time.
struct QuoteCard: View {
    let quote: String
    let show: String
    let episode: String
    let time: TimeInterval
    let artwork: UIImage?
    let background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)
            Text("“\(quote)”")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(9)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(show).font(.system(size: 14, weight: .semibold))
                    Text("\(episode) · \(TimeFormat.clock(time))").font(.system(size: 12)).lineLimit(1)
                }
                .foregroundStyle(.white.opacity(ColorContrast.secondaryAlpha))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background)
    }
}

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// The system share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Cuts audio clips and makes video cards on the iPhone.
enum ClipExporter {
    enum Failure: LocalizedError {
        case cannotExport
        var errorDescription: String? { "The clip couldn't be made." }
    }

    private static func temporaryURL(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        return url
    }

    private static func timeRange(_ range: ClosedRange<TimeInterval>) -> CMTimeRange {
        CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                    end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
    }

    static func audio(from source: URL, range: ClosedRange<TimeInterval>) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { throw Failure.cannotExport }
        session.timeRange = timeRange(range)
        let output = temporaryURL("Podcast clip.m4a")
        try await session.export(to: output, as: .m4a)
        return output
    }

    /// The card as a still video with the clip's audio.
    static func video(image: UIImage, audio: URL, duration: TimeInterval) async throws -> URL {
        let still = temporaryURL("card.mov")
        try await writeStill(image, to: still, duration: duration)

        let composition = AVMutableComposition()
        guard let videoTrack = try await AVURLAsset(url: still).loadTracks(withMediaType: .video).first,
              let audioTrack = try await AVURLAsset(url: audio).loadTracks(withMediaType: .audio).first,
              let videoOut = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioOut = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.cannotExport
        }
        let videoRange = try await videoTrack.load(.timeRange)
        let audioRange = try await audioTrack.load(.timeRange)
        try videoOut.insertTimeRange(videoRange, of: videoTrack, at: .zero)
        try audioOut.insertTimeRange(audioRange, of: audioTrack, at: .zero)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw Failure.cannotExport }
        let output = temporaryURL("Podcast clip.mp4")
        try await session.export(to: output, as: .mp4)
        return output
    }

    private static func writeStill(_ image: UIImage, to url: URL, duration: TimeInterval) async throws {
        let side = 1080
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: side,
            AVVideoHeightKey: side
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: side,
            kCVPixelBufferHeightKey as String: side
        ])
        writer.add(input)
        guard writer.startWriting(), let buffer = pixelBuffer(from: image, side: side) else { throw Failure.cannotExport }
        writer.startSession(atSourceTime: .zero)
        var second: TimeInterval = 0
        while second < duration {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)) }
            adaptor.append(buffer, withPresentationTime: CMTime(seconds: second, preferredTimescale: 600))
            second += 1
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Failure.cannotExport }
    }

    private static func pixelBuffer(from image: UIImage, side: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, side, side, kCVPixelFormatType_32ARGB, attributes, &buffer) == kCVReturnSuccess,
              let buffer, let cgImage = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        return buffer
    }

    /// Mono samples for the waveform, starting at `start`.
    static func samples(from url: URL, start: TimeInterval, seconds: TimeInterval) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let format = file.processingFormat
        let startFrame = AVAudioFramePosition(start * format.sampleRate)
        guard startFrame < file.length else { return [] }
        file.framePosition = startFrame
        let count = AVAudioFrameCount(min(Double(file.length - startFrame), seconds * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              (try? file.read(into: buffer, frameCount: count)) != nil,
              let channel = buffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
