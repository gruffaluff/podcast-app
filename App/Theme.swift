import SwiftUI
import UIKit
import Observation

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
    case haar, sand, slate, clay, night

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isDark: Bool { self == .night }

    /// The settings key (synced through iCloud with the other settings).
    /// Its default, "auto", follows the iPhone: Haar when it's light (the
    /// fog look, Paul 13 Nov 2026; was Sand), Night when it's in dark mode
    /// (Paul, 9 Nov 2026).
    static let key = "colourScheme"
    static let auto = "auto"

    /// The scheme a saved setting means, given the iPhone's light / dark.
    static func resolve(_ setting: String, systemDark: Bool) -> ColourScheme {
        ColourScheme(rawValue: setting) ?? (systemDark ? .night : .haar)
    }

    /// The scheme in use. RootView sets it from the saved setting before
    /// drawing, and redraws the whole app when it changes.
    static var current: ColourScheme =
        resolve(UserDefaults.standard.string(forKey: key) ?? auto,
                systemDark: UITraitCollection.current.userInterfaceStyle == .dark)

    static func use(_ scheme: ColourScheme) { current = scheme }

    struct Palette {
        let background, surface, hairline, controlBorder, ink, muted: UInt32
        let accentFill, accentText, onAccent, highlight, adText: UInt32
        let display, displayText, displayDim: UInt32
        /// Deck 0: the plate the bottom deck sits on, and the card of the
        /// episode playing (dark in every scheme, so it always stands out).
        let plate, playing: UInt32
    }

    var palette: Palette {
        switch self {
        case .haar:
            // Haar (Paul, 13 Nov 2026): a calm misty grey page with drifting
            // fog (`FogBackdrop`), frosted white cards, soft charcoal ink and
            // one deep blue for when nothing is playing. Mock-ups:
            // https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7 (page v4).
            Palette(background: 0xD3D8DB, surface: 0xFFFFFF, hairline: 0xC3CACF, controlBorder: 0xB4BDC4,
                    ink: 0x1F2328, muted: 0x4B5259, accentFill: 0x2B4766, accentText: 0x2B4766,
                    onAccent: 0xFFFFFF, highlight: 0xE4E9EC, adText: 0x6E4A12,
                    display: 0x2B4766, displayText: 0xF4F2EE, displayDim: 0xC9CDD1,
                    plate: 0xC9D0D5, playing: 0x1F2328)
        case .sand:
            // Native warm (Paul, 11 Nov 2026): a warm off-white page, white
            // rows, near-black text; colour comes from the artwork.
            Palette(background: 0xF5F2EC, surface: 0xFFFFFF, hairline: 0xE6E1D7, controlBorder: 0xD6D0C4,
                    ink: 0x1C1B19, muted: 0x6B665D, accentFill: 0x2B2925, accentText: 0x2B2925,
                    onAccent: 0xFFFFFF, highlight: 0xF2E6CC, adText: 0x6E4A12,
                    display: 0x2C2A26, displayText: 0xF6F2E9, displayDim: 0xD4D7C6,
                    plate: 0xEDE8DE, playing: 0x2C2A26)
        case .slate:
            Palette(background: 0xDCE2E7, surface: 0xF7F9FB, hairline: 0xC7D0D7, controlBorder: 0xB7C1C9,
                    ink: 0x1A232A, muted: 0x4F5D68, accentFill: 0x1F5C63, accentText: 0x1F5C63,
                    onAccent: 0xF2F7F8, highlight: 0xCFE5E3, adText: 0x6E4A12,
                    display: 0x1F3A40, displayText: 0xF2F7F8, displayDim: 0xC9D8DA,
                    plate: 0xC9D1D8, playing: 0x1F2A31)
        case .clay:
            Palette(background: 0xEAD8CC, surface: 0xFBF4ED, hairline: 0xDCC6B7, controlBorder: 0xD0B8A8,
                    ink: 0x2A1E18, muted: 0x6B5446, accentFill: 0x9A4426, accentText: 0x8A3C21,
                    onAccent: 0xFBF4ED, highlight: 0xF3D3BD, adText: 0x6E4A12,
                    display: 0x4A2416, displayText: 0xFBF4ED, displayDim: 0xE6CFC2,
                    plate: 0xDCC5B5, playing: 0x3A2720)
        case .night:
            Palette(background: 0x1B1C19, surface: 0x2A2B27, hairline: 0x3A3B36, controlBorder: 0x4A4B45,
                    ink: 0xEEE9DE, muted: 0xA39D90, accentFill: 0x9DB07F, accentText: 0xA9BC8A,
                    onAccent: 0x1B1C19, highlight: 0x47432F, adText: 0xE0B861,
                    display: 0x2F3A27, displayText: 0xF6F2E9, displayDim: 0xD4D7C6,
                    plate: 0x24251F, playing: 0x4A4C42)
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

    /// Corner radius of every list card.
    static var cardRadius: CGFloat { isHaar ? 18 : 12 }
    /// Deck 0: the plate under the bottom deck.
    static var plate: Color { Color(hex: p.plate) }
    /// Deck 0: the card of the episode playing, wherever it shows (Up Next,
    /// Carry on, New, a show's page). Text on it is `Poster.paper`.
    static var playingCard: Color { Color(hex: p.playing) }
    /// Outline buttons and quiet borders.
    static var controlBorder: Color { Color(hex: p.controlBorder) }
    static var ink: Color { Color(hex: p.ink) }
    /// Secondary text.
    static var muted: Color { Color(hex: p.muted) }
    /// The accent: keys that are on, switches; text on it is `onAccent`.
    /// It follows the colour of the episode that's playing (Paul, 11 Nov
    /// 2026: the scheme's olive clashed with the artwork colours), with a
    /// soft black when nothing is playing (Night keeps its own light
    /// accent then, as black wouldn't show on the dark page). Reading it
    /// inside a view tracks `AccentColour`, so only views that use the
    /// accent redraw, once, when the episode changes.
    @MainActor static var accentFill: Color {
        if let playing = AccentColour.shared.colour { return playing }
        return ColourScheme.current.isDark ? Color(hex: p.accentFill) : idleAccent
    }
    /// Accent text on cards and the page.
    /// Night keeps light accent text: artwork colours are dark, made for
    /// light text on them, so as text on the dark page they'd be lost.
    @MainActor static var accentText: Color {
        if ColourScheme.current.isDark { return Color(hex: p.accentText) }
        return AccentColour.shared.colour ?? idleAccent
    }
    /// On a screen about one show (show page, episode page, show settings),
    /// that show's colour wins over what's playing (Paul, 11 Nov 2026).
    @MainActor static func showAccentFill(_ show: Color?) -> Color { show ?? accentFill }
    /// Night keeps its light accent text (dark show colours vanish on it).
    @MainActor static func showAccentText(_ show: Color?) -> Color {
        ColourScheme.current.isDark ? accentText : (show ?? accentText)
    }
    @MainActor static func showOnAccent(_ show: Color?) -> Color { show == nil ? onAccent : Color(hex: 0xF6F2E9) }
    /// Artwork colours are darkened for light text on them, as is the soft
    /// black; only Night's own light accent takes dark text.
    @MainActor static var onAccent: Color {
        if AccentColour.shared.colour == nil, ColourScheme.current.isDark { return Color(hex: p.onAccent) }
        return Color(hex: 0xF6F2E9)
    }
    /// The accent when nothing is playing.
    static let softBlack = Color(hex: 0x2B2925)
    /// Haar's deep blue when nothing plays; soft black in the other light schemes.
    static var idleAccent: Color { ColourScheme.current == .haar ? Color(hex: 0x2B4766) : softBlack }
    /// Is the Haar look on (fog page, frosted cards, serif titles)?
    static var isHaar: Bool { ColourScheme.current == .haar }
    /// Behind list rows: clear in Haar so the fog shows through, the page
    /// colour otherwise.
    static var rowBackground: Color { isHaar ? .clear : background }
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

    /// Headings and screen titles: Apple's own font, SF Pro, bold (Native
    /// warm, Paul 11 Nov 2026: "just use a standard Apple font").
    static func big(_ size: CGFloat) -> Font {
        // Haar: Instrument Serif (OFL, bundled), drawn a little larger as
        // it's lighter than SF bold.
        if isHaar { return .custom(serifName, size: scaled(size * 1.08, max: 1.2)) }
        return .system(size: scaled(size * 0.9, max: 1.2), weight: .bold)
    }

    /// The Haar look's serif (App/Fonts/InstrumentSerif-Regular.ttf).
    static let serifName = "InstrumentSerif-Regular"

    /// Big serif text that doesn't follow the text size (player titles,
    /// the transcript's line now): Haar only, else SF bold.
    static func serif(_ size: CGFloat) -> Font {
        isHaar ? .custom(serifName, size: scaled(size, max: 1.2)) : .system(size: scaled(size * 0.9, max: 1.2), weight: .bold)
    }

    /// Row titles (episodes, shows, chapters) and the transcript's lines:
    /// SF Pro semibold.
    static func title(_ size: CGFloat) -> Font {
        .system(size: scaled(size * 0.9, max: 1.25), weight: .semibold)
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

    /// Labels, times and counters: SF Pro, small and a little heavier,
    /// with figures that don't jump about as they change.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let heavier: Font.Weight = (weight == .regular || weight == .light || weight == .thin || weight == .ultraLight) ? .medium : .semibold
        return .system(size: scaled(size + 0.5), weight: heavier).monospacedDigit()
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

/// The colour of the episode playing, for the app's accent (`Theme.accentFill`).
/// RootView sets `artwork` as episodes change; the colour itself comes from
/// `ArtworkColors` (already measured for the player), so this costs no
/// extra work.
@MainActor
@Observable
final class AccentColour {
    static let shared = AccentColour()
    /// Set by RootView with a short fade, only when what's playing changes
    /// (and once its colour is measured), so the app never jumps colour.
    var colour: Color?
}
