import SwiftUI

/// A chunky physical key: a raised panel that presses down when tapped.
struct KeyButtonStyle: ButtonStyle {
    enum Kind { case plain, dark, accent }
    var kind: Kind = .plain
    var radius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let (fill, shadow, text): (Color, Color, Color) = {
            switch kind {
            case .plain: return (Theme.surface, Theme.controlBorder, Theme.ink)
            case .dark: return (Theme.ink, .black, Theme.background)
            case .accent: return (Theme.accentFill, Theme.accentShadow, Theme.ink)
            }
        }()
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(text)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .shadow(color: shadow, radius: 0, x: 0, y: pressed ? 1 : 3)
            )
            .offset(y: pressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == KeyButtonStyle {
    static var key: KeyButtonStyle { KeyButtonStyle() }
    static var darkKey: KeyButtonStyle { KeyButtonStyle(kind: .dark) }
    static var accentKey: KeyButtonStyle { KeyButtonStyle(kind: .accent) }
}

/// The dark display panel (like a deck's readout).
struct DeckDisplay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .font(Theme.mono(13))
            .foregroundStyle(Theme.displayText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.display, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Progress as a row of segments, played ones lit, ad breaks in amber.
struct SegmentBar: View {
    /// 0...1
    let progress: Double
    /// Ad breaks as fractions of the episode.
    var ads: [ClosedRange<Double>] = []
    var count = 28
    var height: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                let start = Double(index) / Double(count)
                let end = Double(index + 1) / Double(count)
                let isAd = ads.contains { $0.lowerBound < end && $0.upperBound > start }
                let played = (start + end) / 2 <= progress
                RoundedRectangle(cornerRadius: 1)
                    .fill(isAd ? Theme.adMarker : (played ? Theme.displayText : Theme.displayTrack))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// A small status light.
struct LED: View {
    let on: Bool
    var color: Color = Theme.ink

    var body: some View {
        Circle()
            .fill(on ? color : Theme.controlBorder)
            .frame(width: 7, height: 7)
    }
}

/// A boxed monospaced tag, e.g. "TOP1", "BTM", "YOU".
struct DeckTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(10, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.ink, lineWidth: 1))
    }
}
