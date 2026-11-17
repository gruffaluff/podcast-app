import AVKit
import MediaPlayer
import SwiftUI

/// The iPhone's own volume slider (moves with the side buttons), drawn in
/// the player's light colour.
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> CentredVolumeView {
        let view = CentredVolumeView(frame: .zero)
        let paper = UIColor(Poster.paper)
        view.tintColor = paper
        // The same round dot as the progress line: 12 pt at rest, 20 pt
        // while it's held (Paul, build 146: the iOS thumb was too big).
        view.setVolumeThumbImage(Self.dot(12, colour: paper), for: .normal)
        view.setVolumeThumbImage(Self.dot(20, colour: paper), for: .highlighted)
        view.setMinimumVolumeSliderImage(Self.track(paper), for: .normal)
        view.setMaximumVolumeSliderImage(Self.track(paper.withAlphaComponent(0.25)), for: .normal)
        return view
    }

    func updateUIView(_ view: CentredVolumeView, context: Context) {}

    private static func dot(_ size: CGFloat, colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            colour.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
        }
    }

    /// A 4 pt rounded track that stretches.
    private static func track(_ colour: UIColor) -> UIImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 9, height: 4)).image { _ in
            colour.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 9, height: 4), cornerRadius: 2).fill()
        }
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
    }
}

/// iOS draws the volume slider at the top of its box; this keeps it
/// centred, so it lines up with the speaker icons either side.
final class CentredVolumeView: MPVolumeView {
    override func volumeSliderRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.volumeSliderRect(forBounds: bounds)
        return CGRect(x: rect.minX, y: (bounds.height - rect.height) / 2, width: rect.width, height: rect.height)
    }
}

/// The system AirPlay / Bluetooth device picker.
struct RoutePicker: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = tint
        view.activeTintColor = tint
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
