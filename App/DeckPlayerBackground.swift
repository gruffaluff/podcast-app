import SwiftUI
import CoreImage

// The player's backdrop (an open tab's page, DeckTabEpisodePage.swift):
// the show's colour fading to near black, with the artwork blurred
// behind it all.

/// The player's backdrop: the show's colour at the top, its dark shade by
/// the middle, near black at the foot (the prototype's gradient).
struct DeckPlayerBackground: View {
    let colour: Color
    /// G3 (Paul, 22 Nov 2026: "the background to be a merged in kinda blur
    /// effect thing"): the artwork, blurred and darkened, behind it all.
    var artwork: URL? = nil

    /// Near black at the foot of the player.
    static let bottomColour = Color(hex: 0x17161A)
    /// Read along's move between the big artwork and the corner.
    static let morph: Animation = .smooth(duration: 0.4)

    static func shade(_ colour: Color) -> Color {
        colour.mix(with: .black, by: 0.5)
    }

    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: colour, location: 0),
                                   .init(color: Self.shade(colour), location: 0.46),
                                   .init(color: Self.bottomColour, location: 1)],
                           startPoint: .top, endPoint: .bottom)
            if let artwork {
                DeckBlurredArtwork(url: artwork)
                    .id(artwork)
                LinearGradient(stops: [.init(color: Color.black.opacity(0.22), location: 0),
                                       .init(color: Color.black.opacity(0.45), location: 0.5),
                                       .init(color: Self.bottomColour.opacity(0.88), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The artwork blurred once into a small picture (made off the main thread
/// and kept per artwork), then stretched over the screen, so nothing is
/// blurred live while the player moves.
struct DeckBlurredArtwork: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            if let ready = DeckBlurredArtwork.memory.object(forKey: url as NSURL) {
                image = ready
                return
            }
            guard let source = await ArtworkImageCache.shared.image(for: url) else { return }
            let blurred: UIImage? = await Task.detached(priority: .utility) { DeckBlurredArtwork.blur(source) }.value
            guard let blurred else { return }
            DeckBlurredArtwork.memory.setObject(blurred, forKey: url as NSURL)
            withAnimation(.easeOut(duration: 0.4)) { image = blurred }
        }
    }

    nonisolated(unsafe) private static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 12
        return cache
    }()

    /// Shrunk to 96 points across, blurred hard, a little more colourful.
    nonisolated static func blur(_ source: UIImage) -> UIImage? {
        guard let cg = source.cgImage else { return nil }
        let input = CIImage(cgImage: cg)
        let scale: CGFloat = 96 / max(input.extent.width, 1)
        let small: CIImage = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blurred: CIImage = small.clampedToExtent()
            .applyingGaussianBlur(sigma: 9)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.35])
            .cropped(to: small.extent)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let out = context.createCGImage(blurred, from: small.extent) else { return nil }
        return UIImage(cgImage: out)
    }
}
