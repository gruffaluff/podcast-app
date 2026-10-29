import CoreImage
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

    private var colors: [URL: RGB] = [:]
    @ObservationIgnored private var loading: Set<URL> = []

    func background(for url: URL?) -> Color? {
        url.flatMap { colors[$0] }.map(Color.init(rgb:))
    }

    func load(_ url: URL?) async {
        guard let url, colors[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        defer { loading.remove(url) }
        guard let data = try? await URLSession.shared.data(from: url).0 else { return }
        let average = await Task.detached(priority: .utility) { ArtworkColors.averageColor(of: data) }.value
        if let average {
            colors[url] = ColorContrast.themedBackground(from: average)
        }
    }

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
        CIContext().render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
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
