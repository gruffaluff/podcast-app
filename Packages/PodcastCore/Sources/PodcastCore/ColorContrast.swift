import Foundation

/// A colour as red, green and blue from 0 to 1.
public struct RGB: Equatable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let white = RGB(r: 1, g: 1, b: 1)

    /// `self` drawn at `alpha` opacity over `background`.
    public func blended(alpha: Double, over background: RGB) -> RGB {
        RGB(r: r * alpha + background.r * (1 - alpha),
            g: g * alpha + background.g * (1 - alpha),
            b: b * alpha + background.b * (1 - alpha))
    }
}

/// WCAG contrast maths, used to theme the player from artwork while keeping
/// text readable (at least 4.5:1).
public enum ColorContrast {
    /// Opacity of secondary text (show name, times) on themed backgrounds.
    public static let secondaryAlpha = 0.78

    public static func luminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double {
            v <= 0.040_45 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    public static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The artwork colour, darkened just enough that white text and
    /// slightly transparent white secondary text both reach `minimum` contrast.
    public static func themedBackground(from color: RGB, minimum: Double = 4.5) -> RGB {
        var c = RGB(r: clamp(color.r), g: clamp(color.g), b: clamp(color.b))
        for _ in 0..<80 where !passes(c, minimum: minimum) {
            c = RGB(r: c.r * 0.93, g: c.g * 0.93, b: c.b * 0.93)
        }
        return c
    }

    public static func passes(_ background: RGB, minimum: Double = 4.5) -> Bool {
        ratio(.white, background) >= minimum
            && ratio(RGB.white.blended(alpha: secondaryAlpha, over: background), background) >= minimum
    }

    private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}
