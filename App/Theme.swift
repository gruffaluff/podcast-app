import SwiftUI
import UIKit

/// Colours and type: the "middle ground" look (Paul's pick, 5 Nov 2026;
/// replaced Tape Deck). Warm sand page, paper cards, ink text, one olive
/// accent; what's playing is shown in its artwork's colour (see
/// `ArtworkColors`, `ThemedHero`). Big titles are heavy condensed
/// capitals. Mock-ups: https://claude.ai/artifact/F5YT74YVLaxwJfGb56E42d
/// ("Middle ground, developed"). The token names are kept from Tape Deck so
/// every screen picks the new look up.
enum Theme {
    /// The sand page behind everything.
    static let background = Color(hex: 0xE9E3D5)
    /// Paper cards and keys.
    static let surface = Color(hex: 0xF6F2E9)
    /// Every other row in Up Next (banded rows instead of lines; Paul, 9 Nov 2026).
    static let surfaceBand = Color(hex: 0xEEE8DB)
    static let hairline = Color(hex: 0xD6CEBD)
    /// Outline buttons and quiet borders.
    static let controlBorder = Color(hex: 0xC9C2B4)
    static let ink = Color(hex: 0x1F1D19)
    /// Secondary text (6:1 on the page).
    static let muted = Color(hex: 0x5C5547)
    /// Olive: keys that are on, switches; text on it is paper.
    static let accentFill = Color(hex: 0x45543A)
    static let accentShadow = Color(hex: 0x2F3A27)
    /// Olive text on light panels (7:1).
    static let accentText = Color(hex: 0x45543A)
    static let onAccent = Color(hex: 0xF6F2E9)
    /// Search matches and highlighted lines.
    static let highlight = Color(hex: 0xF2DFB8)
    /// Ad breaks (amber).
    static let adMarker = Color(hex: 0xD9A441)
    static let adText = Color(hex: 0x6E4A12)

    // The coloured "now playing" area when the artwork has no colour yet.
    static let display = Color(hex: 0x2F3A27)
    static let displayText = Color(hex: 0xF6F2E9)
    static let displayDim = Color(hex: 0xD4D7C6)
    static let displayTrack = Color.white.opacity(0.25)

    /// Muted tones for artwork placeholders.
    static let placeholders: [Color] = ([0x3D5A80, 0x2F6B5E, 0x7A3F66, 0x8A6A2F, 0x5B5750, 0x6A5E86] as [UInt32]).map { Color(hex: $0) }

    /// The same title always gets the same colour.
    static func placeholderColor(for title: String) -> Color {
        let sum = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return placeholders[sum % placeholders.count]
    }

    /// "Tidewater Weekly" → "TW"; a leading "The" is skipped.
    static func initials(for title: String) -> String {
        let words = title.split(separator: " ").filter { $0.lowercased() != "the" }
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }

    /// Whether the bundled fonts loaded (checked once).
    private static let hasTapeDeckFonts: Bool =
        UIFont(name: "BigShouldersDisplay-Black", size: 12) != nil && UIFont(name: "DMMono-Medium", size: 12) != nil

    /// Big titles: tall, narrow industrial capitals, like the lettering on
    /// hi-fi gear (Big Shoulders Display Black; Paul picked "tape deck",
    /// 8 Nov 2026). Pass uppercased text. Falls back to the system font if
    /// the font file is ever missing.
    static func big(_ size: CGFloat) -> Font {
        let scaledSize = scaled(size * 1.08, max: 1.2)
        guard hasTapeDeckFonts else {
            return .system(size: scaled(size, max: 1.2), weight: .black).width(.condensed)
        }
        return .custom("BigShouldersDisplay-Black", fixedSize: scaledSize)
    }

    /// Follows the iPhone's text size setting (Dynamic Type), within limits
    /// so the layouts still fit: up to 35% bigger for small text, 20% for
    /// the big titles; never smaller than designed.
    static func scaled(_ size: CGFloat, max factor: CGFloat = 1.35) -> CGFloat {
        let wanted = UIFontMetrics.default.scaledValue(for: size)
        return min(Swift.max(wanted, size), size * factor)
    }

    /// Screen and section titles.
    static func screenTitle(_ size: CGFloat = 34) -> Font {
        big(size)
    }

    /// Labels, times and counters: DM Mono, like the printing beside the
    /// buttons on a cassette deck (Paul picked "tape deck", 8 Nov 2026).
    /// DM Mono has two weights: regular, and medium for anything heavier.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = weight == .regular || weight == .light || weight == .thin || weight == .ultraLight
            ? "DMMono-Regular" : "DMMono-Medium"
        let scaledSize = scaled(size)
        guard hasTapeDeckFonts else {
            return .system(size: scaledSize, weight: weight)
        }
        return .custom(name, fixedSize: scaledSize)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
