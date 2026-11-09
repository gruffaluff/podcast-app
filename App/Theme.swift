import SwiftUI
import UIKit

/// Colours and type: the "middle ground" look (Paul's pick, 5 Nov 2026;
/// replaced Tape Deck). Warm sand page, paper cards, ink text, one olive
/// accent; what's playing is shown in its artwork's colour (see
/// `ArtworkColors`, `ThemedHero`). Big titles are heavy condensed
/// capitals. Mock-ups: https://claude.ai/artifact/F5YT74YVLaxwJfGb56E42d
/// ("Middle ground, developed"). The token names are kept from Tape Deck so
/// every screen picks the new look up.
/// The app's colour schemes (Paul, 9 Nov 2026: all four, from
/// https://claude.ai/artifact/HkYMMBunqi9jCSsmn8hrae). Same layout, cards
/// and fonts in each; only these colours change. The player and mini
/// player keep taking their colour from the artwork.
enum ColourScheme: String, CaseIterable, Identifiable {
    case sand, slate, clay, night

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isDark: Bool { self == .night }

    /// The settings key (synced through iCloud with the other settings).
    static let key = "colourScheme"

    /// The scheme in use. RootView sets it from the saved setting before
    /// drawing, and redraws the whole app when it changes.
    static var current: ColourScheme =
        ColourScheme(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .sand

    static func use(_ scheme: ColourScheme) { current = scheme }

    struct Palette {
        let background, surface, hairline, controlBorder, ink, muted: UInt32
        let accentFill, accentText, onAccent, highlight, adText: UInt32
        let display, displayText, displayDim: UInt32
    }

    var palette: Palette {
        switch self {
        case .sand:
            Palette(background: 0xE9E3D5, surface: 0xF6F2E9, hairline: 0xD6CEBD, controlBorder: 0xC9C2B4,
                    ink: 0x1F1D19, muted: 0x5C5547, accentFill: 0x45543A, accentText: 0x45543A,
                    onAccent: 0xF6F2E9, highlight: 0xF2DFB8, adText: 0x6E4A12,
                    display: 0x2F3A27, displayText: 0xF6F2E9, displayDim: 0xD4D7C6)
        case .slate:
            Palette(background: 0xDCE2E7, surface: 0xF7F9FB, hairline: 0xC7D0D7, controlBorder: 0xB7C1C9,
                    ink: 0x1A232A, muted: 0x4F5D68, accentFill: 0x1F5C63, accentText: 0x1F5C63,
                    onAccent: 0xF2F7F8, highlight: 0xCFE5E3, adText: 0x6E4A12,
                    display: 0x1F3A40, displayText: 0xF2F7F8, displayDim: 0xC9D8DA)
        case .clay:
            Palette(background: 0xEAD8CC, surface: 0xFBF4ED, hairline: 0xDCC6B7, controlBorder: 0xD0B8A8,
                    ink: 0x2A1E18, muted: 0x6B5446, accentFill: 0x9A4426, accentText: 0x8A3C21,
                    onAccent: 0xFBF4ED, highlight: 0xF3D3BD, adText: 0x6E4A12,
                    display: 0x4A2416, displayText: 0xFBF4ED, displayDim: 0xE6CFC2)
        case .night:
            Palette(background: 0x1B1C19, surface: 0x2A2B27, hairline: 0x3A3B36, controlBorder: 0x4A4B45,
                    ink: 0xEEE9DE, muted: 0xA39D90, accentFill: 0x9DB07F, accentText: 0xA9BC8A,
                    onAccent: 0x1B1C19, highlight: 0x47432F, adText: 0xE0B861,
                    display: 0x2F3A27, displayText: 0xF6F2E9, displayDim: 0xD4D7C6)
        }
    }
}

/// Colours and type: the "middle ground" look (Paul's pick, 5 Nov 2026;
/// replaced Tape Deck). Page, cards, ink text and one accent come from the
/// chosen `ColourScheme` (Sand by default); what's playing is shown in its
/// artwork's colour (see `ArtworkColors`, `ThemedHero`). Big titles are
/// heavy condensed capitals. The token names are kept from Tape Deck so
/// every screen picks the look up.
enum Theme {
    private static var p: ColourScheme.Palette { ColourScheme.current.palette }

    /// The page behind everything.
    static var background: Color { Color(hex: p.background) }
    /// Cards and keys.
    static var surface: Color { Color(hex: p.surface) }
    static var hairline: Color { Color(hex: p.hairline) }

    /// An Up Next card's colour: the playing one highlighted, the rest paper.
    static func upNextCard(_ index: Int, playing: Int?) -> Color {
        index == playing ? highlight : surface
    }

    /// Corner radius of every list card.
    static let cardRadius: CGFloat = 14
    /// Outline buttons and quiet borders.
    static var controlBorder: Color { Color(hex: p.controlBorder) }
    static var ink: Color { Color(hex: p.ink) }
    /// Secondary text.
    static var muted: Color { Color(hex: p.muted) }
    /// The accent: keys that are on, switches; text on it is `onAccent`.
    static var accentFill: Color { Color(hex: p.accentFill) }
    /// Accent text on cards and the page.
    static var accentText: Color { Color(hex: p.accentText) }
    static var onAccent: Color { Color(hex: p.onAccent) }
    /// Search matches, highlighted lines and the playing card.
    static var highlight: Color { Color(hex: p.highlight) }
    /// Ad breaks (amber).
    static let adMarker = Color(hex: 0xD9A441)
    static var adText: Color { Color(hex: p.adText) }

    // The coloured "now playing" area when the artwork has no colour yet.
    static var display: Color { Color(hex: p.display) }
    static var displayText: Color { Color(hex: p.displayText) }
    static var displayDim: Color { Color(hex: p.displayDim) }
    static let displayTrack = Color.white.opacity(0.25)

    /// Card shadows: black whatever the scheme (ink is light in Night).
    static var shadowSoft: Color { Color.black.opacity(ColourScheme.current.isDark ? 0.35 : 0.06) }
    static var shadowWide: Color { Color.black.opacity(ColourScheme.current.isDark ? 0.45 : 0.08) }

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

    /// Body text at a set size (SF) that still follows the iPhone's text
    /// size setting, within the same limits as the labels. Used instead of
    /// fixed `.system(size:)` so every list grows with the setting (style
    /// rules, Paul 9 Nov 2026). Text in fixed-size places (New Episodes
    /// cards, the mini player, share cards) and icons in round keys stay
    /// fixed on purpose.
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight)
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
