import SwiftUI
import UIKit
import CoreImage

// The poster look (Paul, 11 Nov 2026: "let's rebuild it all"; mock-ups
// https://claude.ai/artifact/KbVas33x1ccwvAFM9YoccR, his pick A + B with
// square stamps). The page stays sand; every row gets a strip of its show's
// colour, a Fraunces Soft title and the artwork as a small square
// "stamp" (A); the big colour areas (playing block, player, show and
// episode pages, mini player) are the artwork "printed" in one ink of the
// show's colour with a halftone dot screen (B).

enum Poster {
    /// Text on a printed colour area.
    static let paper = Color(hex: 0xF6F2E9)
    /// Full-row swipe colours: add (green) and played (red).
    static let swipeAdd = Color(hex: 0x45543A)
    static let swipePlayed = Color(hex: 0xB4472E)
    /// The strip down the left of every row.
    static let stripWidth: CGFloat = 8

    /// A show's colour: measured from its artwork (dark enough for paper
    /// text), or a steady placeholder colour until that's done.
    @MainActor
    static func colour(_ url: URL?, title: String) -> Color {
        ArtworkColors.shared.background(for: url) ?? Theme.placeholderColor(for: title)
    }
}

/// The halftone dot screen printed over colour areas: one small tile with
/// a dot, repeated by the GPU. (Drawing every dot in a Canvas, tens of
/// thousands on the player, on each redraw made scrolling stutter.)
struct Halftone: View {
    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let tile: UIImage = {
        let spacing: CGFloat = 4, radius: CGFloat = 0.95
        return UIGraphicsImageRenderer(size: CGSize(width: spacing, height: spacing)).image { context in
            UIColor.black.withAlphaComponent(0.22).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: spacing / 2 - radius, y: spacing / 2 - radius, width: radius * 2, height: radius * 2))
        }
    }()
}

/// Artwork "screen-printed" in one ink of the show's colour (idea B): the
/// picture in greys multiplied onto the colour, with the dot screen on top.
/// Fills whatever space it's given. The print is made once per artwork,
/// colour and strength (`PrintedImages`) and then shown as a plain
/// picture, so nothing is blended live while scrolling.
struct PrintedArtwork: View, Equatable {
    let url: URL?
    let colour: Color
    /// How strongly the picture shows through (0 = flat colour).
    var strength: Double = 0.6
    var dots = true

    var body: some View {
        colour
            .overlay { PrintedImage(url: url, colour: colour, strength: strength) }
            .overlay { if dots { Halftone() } }
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct PrintedImage: View {
    let url: URL?
    let colour: Color
    let strength: Double
    @State private var image: UIImage?

    init(url: URL?, colour: Color, strength: Double) {
        self.url = url
        self.colour = colour
        self.strength = strength
        _image = State(initialValue: PrintedImages.shared.cached(url: url, colour: colour, strength: strength))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: PrintedImages.key(url: url, colour: colour, strength: strength)) {
            image = await PrintedImages.shared.image(url: url, colour: colour, strength: strength)
        }
    }
}

/// Printed artwork, made off the main thread and kept in memory.
@MainActor
final class PrintedImages {
    static let shared = PrintedImages()
    private let memory = NSCache<NSString, UIImage>()

    init() { memory.totalCostLimit = 40 * 1024 * 1024 }

    nonisolated static func key(url: URL?, colour: Color, strength: Double) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(colour).getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(url?.absoluteString ?? "-")|\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255))|\(Int(strength * 100))"
    }

    func cached(url: URL?, colour: Color, strength: Double) -> UIImage? {
        memory.object(forKey: Self.key(url: url, colour: colour, strength: strength) as NSString)
    }

    func image(url: URL?, colour: Color, strength: Double) async -> UIImage? {
        guard let url else { return nil }
        let key = Self.key(url: url, colour: colour, strength: strength) as NSString
        if let done = memory.object(forKey: key) { return done }
        guard let source = await ArtworkImageCache.shared.image(for: url) else { return nil }
        let tint = UIColor(colour)
        let printed = await Task.detached(priority: .userInitiated) {
            Self.makePrint(source, tint: tint, strength: strength)
        }.value
        if let printed {
            memory.setObject(printed, forKey: key, cost: Int(printed.size.width * printed.size.height * printed.scale * printed.scale * 4))
        }
        return printed
    }

    /// The picture in greys (a little more contrast), multiplied onto the
    /// colour at the given strength: one ink, like a screen print.
    nonisolated private static func makePrint(_ source: UIImage, tint: UIColor, strength: Double) -> UIImage? {
        guard let input = CIImage(image: source) else { return nil }
        let grey = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.15])
        guard let cgGrey = context.createCGImage(grey, from: input.extent) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: cgGrey.width, height: cgGrey.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            tint.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: cgGrey).draw(in: CGRect(origin: .zero, size: size), blendMode: .multiply, alpha: CGFloat(strength))
        }
    }

    nonisolated(unsafe) private static let context = CIContext()
}

/// The artwork as a small square "stamp" (idea A): square, a thin paper
/// edge and a soft shadow, like a label stuck on.
struct Stamp: View {
    let url: URL?
    let title: String
    var size: CGFloat = 40

    var body: some View {
        ArtworkView(url: url, title: title, size: size, radius: size * 0.16)
            // A thin edge instead of a shadow: a shadow on every stamp in a
            // list cost frames while scrolling.
            .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
}

/// The text of a poster row: a small DM Mono label line, then the title in
/// Fraunces Soft Medium, in proper case.
struct PosterRowText: View {
    let label: String
    let title: String
    var titleSize: CGFloat = 19
    var lines = 2
    var dim = false
    var onColour = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(Theme.mono(9.5))
                    .tracking(0.8)
                    .foregroundStyle(onColour ? Poster.paper.opacity(0.8) : Theme.muted)
                    .lineLimit(1)
            }
            Text(title)
                .font(Theme.title(titleSize))
                .foregroundStyle(onColour ? Poster.paper : (dim ? Theme.muted : Theme.ink))
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A poster row card: paper with a strip of the show's colour down the
    /// left, rounded, on a soft shadow (the app's card look).
    func posterCard(_ strip: Color, fill: Color = Theme.surface) -> some View {
        self
            .padding(.leading, Poster.stripWidth + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(fill)
                    .overlay(alignment: .leading) {
                        strip.frame(width: Poster.stripWidth)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .shadow(color: Theme.shadowSoft, radius: 0.5, y: 1)
                    .shadow(color: Theme.shadowWide, radius: 3, y: 1.5)
            }
    }

    /// A poster row in a list: the card plus the list settings around it.
    func posterRow(_ strip: Color, fill: Color = Theme.surface) -> some View {
        posterCard(strip, fill: fill).deckCardRow()
    }

    /// Full-row swipes (Paul, poster look): the action fills the whole row,
    /// its own height and corners. Swipe right for `leading`, left for
    /// `trailing`; let go past the line to do it.
    func posterSwipe(leading: PosterSwipeAction? = nil, trailing: PosterSwipeAction? = nil, enabled: Bool = true) -> some View {
        modifier(PosterSwipe(leading: leading, trailing: trailing, enabled: enabled))
    }
}

struct PosterSwipeAction {
    let title: String
    let icon: String
    let colour: Color
    let action: () -> Void
}

private struct PosterSwipe: ViewModifier {
    let leading: PosterSwipeAction?
    let trailing: PosterSwipeAction?
    let enabled: Bool
    @State private var offset: CGFloat = 0
    @State private var armed = false

    /// How far to pull before letting go does it (a quick flick needs less).
    private static let trigger: CGFloat = 80

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { actionBlock }
            // An iOS pan that only starts when the finger moves sideways, so
            // up / down drags go straight to the list's own scrolling (a
            // SwiftUI drag on every row fought the scrolling and the
            // long-press reorder: swipes and scrolls were hit and miss).
            .gesture(SidewaysPan(isEnabled: enabled && (leading != nil || trailing != nil),
                                 changed: moved, ended: released))
            .accessibilityActions {
                if let leading { Button(leading.title, action: leading.action) }
                if let trailing { Button(trailing.title, action: trailing.action) }
            }
    }

    private func moved(_ translation: CGFloat) {
        var x = translation
        if x > 0, leading == nil { x = 0 }
        if x < 0, trailing == nil { x = 0 }
        // Resists a little past the line.
        if abs(x) > Self.trigger { x = (x > 0 ? 1 : -1) * (Self.trigger + (abs(x) - Self.trigger) * 0.35) }
        offset = x
        let nowArmed = abs(x) >= Self.trigger
        if nowArmed != armed {
            armed = nowArmed
            if nowArmed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        }
    }

    private func released(_ velocity: CGFloat) {
        // Past the line, or a quick flick the same way once it has moved.
        let flick = abs(offset) > 36 && abs(velocity) > 700 && (velocity > 0) == (offset > 0)
        let fire = (armed || flick) ? (offset > 0 ? leading : trailing) : nil
        armed = false
        withAnimation(.spring(duration: 0.3)) { offset = 0 }
        fire?.action()
    }

    @ViewBuilder private var actionBlock: some View {
        let action = offset > 0 ? leading : (offset < 0 ? trailing : nil)
        if let action {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(action.colour)
                .overlay(alignment: offset > 0 ? .leading : .trailing) {
                    HStack(spacing: 6) {
                        if offset < 0 { label(action) }
                        Image(systemName: action.icon).font(.system(size: 14, weight: .bold))
                        if offset > 0 { label(action) }
                    }
                    .foregroundStyle(Poster.paper)
                    .padding(.horizontal, 18)
                    .scaleEffect(armed ? 1.08 : 1)
                }
                .accessibilityHidden(true)
        }
    }

    private func label(_ action: PosterSwipeAction) -> some View {
        Text(action.title.uppercased()).font(Theme.mono(11, .bold)).tracking(1)
    }
}

/// A pan that begins only when the finger starts moving sideways; anything
/// more up-and-down than that never begins, so it can't hold up scrolling.
private struct SidewaysPan: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    /// How far it has moved sideways.
    let changed: (CGFloat) -> Void
    /// Sideways speed when the finger lifts (points per second).
    let ended: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .changed:
            changed(recognizer.translation(in: recognizer.view).x)
        case .ended:
            ended(recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            ended(0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}

private struct ShowPosterCard: ViewModifier {
    let url: URL?
    let title: String
    let fill: Color
    let inList: Bool

    func body(content: Content) -> some View {
        let colour = Poster.colour(url, title: title)
        Group {
            if inList {
                content.posterRow(colour, fill: fill)
            } else {
                content.posterCard(colour, fill: fill)
            }
        }
        .task(id: url) { await ArtworkColors.shared.load(url) }
    }
}

extension View {
    /// A poster card in the colour of the show whose artwork is `url`
    /// (measured once, then remembered).
    func showCard(_ url: URL?, title: String, fill: Color = Theme.surface) -> some View {
        modifier(ShowPosterCard(url: url, title: title, fill: fill, inList: false))
    }

    /// The same as a list row.
    func showRow(_ url: URL?, title: String, fill: Color = Theme.surface) -> some View {
        modifier(ShowPosterCard(url: url, title: title, fill: fill, inList: true))
    }
}

extension PodcastEpisode {
    /// The show's own artwork (its colour is the episode's strip colour).
    var showArtwork: URL? { podcast?.artworkURL ?? artwork }
    var showTitle: String { podcast?.title ?? "" }
}
