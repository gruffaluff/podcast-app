import SwiftUI

/// The Haar look (Paul, 13 Nov 2026): a misty grey page with slow drifting
/// fog, tinted by the colour of what's playing, frosted white cards, serif
/// titles. Named after the cold sea fog off the North Sea. Mock-ups:
/// https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7 (page "v4 · Poddeck,
/// Haar look"). Other colour schemes keep their flat page.

/// The page behind a screen: fog in Haar, the scheme's flat colour otherwise.
struct PageBackground: View {
    var body: some View {
        if Theme.isHaar { FogBackdrop() } else { Theme.background }
    }
}

/// Mist, a soft light from the top, a faint glow of what's playing and
/// three wide bands of fog drifting slowly sideways. The drift is a
/// repeating Core Animation move (no redraws), still with Reduce Motion.
struct FogBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false
    /// How thick the fog is (Settings → Colours, Haar only).
    @AppStorage(FogBackdrop.densityKey) private var density = 1.0
    /// Tint the mist with the colour of what's playing.
    @AppStorage(FogBackdrop.tintKey) private var tint = true

    static let densityKey = "haarFog"
    static let tintKey = "haarTint"

    private var playing: Color? { tint ? AccentColour.shared.colour : nil }

    // The page takes on a mist of the show's colour (prototype: the whole
    // page is the show's "mist", with a 16% glow of its deep colour).
    private var mist: Color {
        guard let playing else { return Theme.background }
        return Theme.background.mix(with: playing, by: 0.24)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                mist
                LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)], startPoint: .top, endPoint: .center)
                Circle()
                    .fill(playing ?? Theme.idleAccent)
                    .opacity(0.16)
                    .frame(width: w * 1.1, height: w * 1.1)
                    .blur(radius: 80)
                    .position(x: w * 0.45, y: h * 0.18)
                band(width: w * 2.1, height: 150, y: h * 0.2, opacity: 0.55 * density, shift: 50, w: w)
                band(width: w * 2.1, height: 130, y: h * 0.56, opacity: 0.38 * density, shift: -70, w: w)
                band(width: w * 2.1, height: 170, y: h * 0.86, opacity: 0.55 * density, shift: 40, w: w)
            }
            .animation(.easeInOut(duration: 0.8), value: AccentColour.shared.colour)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private func band(width: CGFloat, height: CGFloat, y: CGFloat, opacity: Double, shift: CGFloat, w: CGFloat) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: width, height: height)
            .blur(radius: 36)
            .opacity(opacity)
            .position(x: w / 2 + (drift ? shift : -shift), y: y)
    }
}

extension View {
    /// The page behind a screen (fog in Haar), filling under the bars.
    func haarPage() -> some View {
        background { PageBackground().ignoresSafeArea() }
    }

    /// A Haar card: frosted white over the fog with a fine white edge.
    func frostedCard(radius: CGFloat = Theme.cardRadius) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.white.opacity(0.55)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                .shadow(color: Color(hex: 0x28323C).opacity(0.08), radius: 14, y: 6)
        }
    }
}
