import SwiftUI

/// The Haar look (Paul, 13 Nov 2026): a misty grey page with slow drifting
/// fog, tinted by the colour of what's playing, frosted white cards, serif
/// titles. Named after the cold sea fog off the North Sea. Mock-ups:
/// https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7 (page "v4 · Poddeck,
/// Haar look"). Other colour schemes keep their flat page.

/// The page behind a screen: fog in Haar, the scheme's flat colour otherwise.
/// Only the app's root page lets its fog drift; every page and layer on
/// top of it (`haarFogBehind`) draws the same fog standing still, so only
/// one fog ever moves on screen (smoother scrolling, Paul 13 Nov 2026).
struct PageBackground: View {
    @Environment(\.haarFogBehind) private var fogBehind

    var body: some View {
        if Theme.isHaar { FogBackdrop(still: fogBehind) } else { Theme.background }
    }
}

private struct HaarFogBehindKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True under the app's root page: a drifting fog is already behind,
    /// so pages on top draw theirs standing still.
    var haarFogBehind: Bool {
        get { self[HaarFogBehindKey.self] }
        set { self[HaarFogBehindKey.self] = newValue }
    }
}

/// Mist, a soft light from the top, a faint glow of what's playing and
/// three wide bands of fog drifting slowly sideways. Everything is a soft
/// gradient (no live blur), and the drift only slides the bands (an
/// offset), so it costs next to nothing. Still with Reduce Motion, and on
/// pages drawn over the root's fog (`still`).
struct FogBackdrop: View {
    var still: Bool = false
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
            let w: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack {
                mist
                LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)], startPoint: .top, endPoint: .center)
                glow(w: w, h: h)
                band(width: w * 2.1, height: 150, y: h * 0.2, opacity: 0.55 * density, shift: 50, w: w)
                band(width: w * 2.1, height: 130, y: h * 0.56, opacity: 0.38 * density, shift: -70, w: w)
                band(width: w * 2.1, height: 170, y: h * 0.86, opacity: 0.55 * density, shift: 40, w: w)
            }
            .animation(.easeInOut(duration: 0.8), value: AccentColour.shared.colour)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !still, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    /// The faint glow of what's playing: a radial fade (was a blurred circle).
    private func glow(w: CGFloat, h: CGFloat) -> some View {
        let colour: Color = playing ?? Theme.idleAccent
        let radius: CGFloat = w * 0.55 + 90
        let stops: [Gradient.Stop] = [
            Gradient.Stop(color: colour.opacity(0.16), location: 0),
            Gradient.Stop(color: colour.opacity(0.11), location: 0.45),
            Gradient.Stop(color: colour.opacity(0.04), location: 0.75),
            Gradient.Stop(color: colour.opacity(0), location: 1)
        ]
        let fade = RadialGradient(gradient: Gradient(stops: stops), center: .center, startRadius: 0, endRadius: radius)
        return Rectangle()
            .fill(fade)
            .frame(width: radius * 2, height: radius * 2)
            .position(x: w * 0.45, y: h * 0.18)
    }

    /// One band of fog: white fading to clear towards its edges (was a
    /// capsule under a 36-point blur).
    private func band(width: CGFloat, height: CGFloat, y: CGFloat, opacity: Double, shift: CGFloat, w: CGFloat) -> some View {
        let stops: [Gradient.Stop] = [
            Gradient.Stop(color: .white, location: 0),
            Gradient.Stop(color: .white.opacity(0.9), location: 0.25),
            Gradient.Stop(color: .white.opacity(0.45), location: 0.38),
            Gradient.Stop(color: .white.opacity(0.12), location: 0.46),
            Gradient.Stop(color: .white.opacity(0), location: 0.5)
        ]
        let fade = EllipticalGradient(gradient: Gradient(stops: stops), center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
        let x: CGFloat = still ? 0 : (drift ? shift : -shift)
        return Rectangle()
            .fill(fade)
            .frame(width: width, height: height + 80)
            .opacity(opacity)
            .position(x: w / 2, y: y)
            .offset(x: x)
    }
}

extension View {
    /// The page behind a screen (fog in Haar), filling under the bars.
    func haarPage() -> some View {
        background { PageBackground().ignoresSafeArea() }
    }

    /// A Haar card: translucent white over the fog with a fine white edge
    /// and a soft shadow. A plain fill, not a material: a live blur under
    /// every card made lists scroll at a low frame rate.
    func frostedCard(radius: CGFloat = Theme.cardRadius) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            shape.fill(Color.white.opacity(0.62))
                .overlay(shape.strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                .shadow(color: Color(hex: 0x28323C).opacity(0.08), radius: 14, y: 6)
        }
    }
}

/// Plain settings / menu rows in Haar (Paul, 13 Nov 2026: "menus … were
/// just text in the mockup. No white card"): rows sit straight on the
/// page with a hairline between them, inset like the text.
struct HaarMenuHairline: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(red: 31 / 255, green: 35 / 255, blue: 40 / 255).opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}
