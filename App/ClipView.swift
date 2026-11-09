import AVFoundation
import SwiftUI
import UIKit
import PodcastCore

/// "Share a clip": a quote card for a transcript line, 5–30 seconds long,
/// optionally with the audio or a link to the moment.
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
                    // Sand keys like the rest of the app (style rules).
                    HStack {
                        Button { length = Clips.clamp(length - Clips.step) } label: { stepLabel("− 5 SEC") }
                            .disabled(length <= Clips.lengths.lowerBound)
                        Spacer()
                        Button { length = Clips.clamp(length + Clips.step) } label: { stepLabel("+ 5 SEC") }
                            .disabled(length >= Clips.lengths.upperBound)
                    }
                    .buttonStyle(KeyButtonStyle(kind: .sand, radius: 10))
                }
                Section {
                    Toggle("Include audio", isOn: $includeAudio).disabled(audioFile == nil)
                    Toggle("Link to the moment", isOn: $includeLink).disabled(linkTarget == nil)
                } footer: {
                    Text(audioFile == nil ? "Download the episode to include its audio." : "The clip is cut on your iPhone from the downloaded episode.")
                }
                .tint(Theme.accentFill)
                if let failure {
                    Text(failure).foregroundStyle(Theme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("SHARE A CLIP")
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

    private func stepLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(11, .bold))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
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
            if let audioFile, includeAudio {
                let audio = try await ClipExporter.audio(from: audioFile, range: range)
                items.append(image)
                items.append(audio)
            } else {
                items.append(image)
            }
        } catch {
            failure = "Couldn't cut the audio clip. (\(error.localizedDescription))"
            return
        }
        items.append(text)

        // Keep it in Saved (Search).
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
                .font(.system(size: 25, weight: .semibold))
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

/// Cuts audio clips on the iPhone.
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
