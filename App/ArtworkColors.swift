import CoreImage
import UIKit
import CoreImage.CIFilterBuiltins
import Observation
import SwiftUI
import PodcastCore

/// Background colours taken from artwork (its average colour), darkened just
/// enough to keep white text at 4.5:1 contrast. Used by the full player and
/// the New Episodes cards. Views call `load` in `.task` and read `background`.
@MainActor
@Observable
final class ArtworkColors {
    static let shared = ArtworkColors()

    private var colors: [URL: RGB] = ArtworkColors.saved()
    @ObservationIgnored private var loading: Set<URL> = []

    /// Measured colours are kept between launches, so artwork isn't
    /// measured again every time the app opens (review, 9 Nov 2026).
    private static let savedKey = "artworkColors"

    private static func saved() -> [URL: RGB] {
        guard let stored = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: [Double]] else { return [:] }
        var result: [URL: RGB] = [:]
        for (key, value) in stored where value.count == 3 {
            if let url = URL(string: key) { result[url] = RGB(r: value[0], g: value[1], b: value[2]) }
        }
        return result
    }

    private func persist() {
        var stored: [String: [Double]] = [:]
        for (url, rgb) in colors { stored[url.absoluteString] = [rgb.r, rgb.g, rgb.b] }
        UserDefaults.standard.set(stored, forKey: Self.savedKey)
    }

    func clear() {
        colors.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.savedKey)
    }

    func background(for url: URL?) -> Color? {
        url.flatMap { colors[$0] }.map(Color.init(rgb:))
    }

    func load(_ url: URL?) async {
        guard let url, colors[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        defer { loading.remove(url) }
        // From the artwork cache, so the picture isn't downloaded twice.
        guard let image = await ArtworkImageCache.shared.image(for: url), let data = image.jpegData(compressionQuality: 0.8) else { return }
        let average = await Task.detached(priority: .utility) { ArtworkColors.averageColor(of: data) }.value
        if let average {
            colors[url] = ColorContrast.themedBackground(from: average)
            persist()
        }
    }

    /// One drawing context for every measurement (making one is costly).
    nonisolated(unsafe) private static let context = CIContext()

    /// The image's average colour, measured on a small copy for speed.
    nonisolated static func averageColor(of data: Data) -> RGB? {
        guard let image = CIImage(data: data) else { return nil }
        let scale = min(1, 200 / max(image.extent.width, image.extent.height, 1))
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let filter = CIFilter.areaAverage()
        filter.inputImage = small
        filter.extent = small.extent
        guard let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return RGB(r: Double(pixel[0]) / 255, g: Double(pixel[1]) / 255, b: Double(pixel[2]) / 255)
    }
}

extension Color {
    init(rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

/// Back / forward skip button: tap to skip, touch and hold to change the length.
struct SkipButton: View {
    enum Direction { case back, forward }

    @Environment(PlayerModel.self) private var player
    let direction: Direction
    var iconSize: CGFloat = 17
    var frame: CGFloat = 44

    var body: some View {
        let seconds = direction == .back ? player.skipBackSeconds : player.skipForwardSeconds
        let name = direction == .back ? "Back" : "Forward"
        Menu {
            Picker("\(name) button skips", selection: Binding(
                get: { seconds },
                set: { direction == .back ? player.setSkipBack($0) : player.setSkipForward($0) }
            )) {
                ForEach(PlayerOptions.skipLengths, id: \.self) { length in
                    Text("\(length) seconds").tag(length)
                }
            }
        } label: {
            Image(systemName: "\(direction == .back ? "gobackward" : "goforward").\(seconds)")
                .font(.system(size: iconSize))
                .frame(width: frame, height: frame)
                .contentShape(Rectangle())
        } primaryAction: {
            direction == .back ? player.skipBackward() : player.skipForwardBy()
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("\(name) \(seconds) seconds")
        .accessibilityHint("Touch and hold to change how far it skips")
    }
}
