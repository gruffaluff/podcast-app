import SwiftUI
import UIKit
import Observation

/// The app's colour schemes: Deck (Paul, 14 Nov 2026, "I love it";
/// prototype https://claude.ai/artifact/CC3pxxR1XwBGtnp13xAdbB) and its
/// dark version, Deck night. The older looks (Haar, Sand, Slate, Clay,
/// Night) were cleared out on 17 Nov 2026 (Paul: "Clear out the old looks").
enum ColourScheme: String, CaseIterable, Identifiable {
    case deck, deckNight

    var id: String { rawValue }
    var label: String { self == .deckNight ? "Deck night" : "Deck" }
    var isDark: Bool { self == .deckNight }

    /// The settings key (synced through iCloud with the other settings).
    /// Its default, "auto", follows the iPhone: Deck when it's light, Deck
    /// night when it's in dark mode. A saved older scheme ("haar", "sand"
    /// …) no longer exists, so it reads as auto.
    static let key = "colourScheme"
    static let auto = "auto"

    /// Does this saved setting follow the iPhone (auto, or an old scheme
    /// that's gone)?
    static func isAuto(_ setting: String) -> Bool { ColourScheme(rawValue: setting) == nil }

    /// The scheme a saved setting means, given the iPhone's light / dark.
    static func resolve(_ setting: String, systemDark: Bool) -> ColourScheme {
        ColourScheme(rawValue: setting) ?? (systemDark ? .deckNight : .deck)
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
        /// The plate behind quiet controls, and the card of the episode
        /// playing (dark in both schemes, so it always stands out).
        let plate, playing: UInt32
    }

    var palette: Palette {
        switch self {
        case .deck:
            // A warm off-white page, white cards with a fine warm edge, ink
            // text; no accent of its own (the show's artwork colour is used).
            Palette(background: 0xEEEBE5, surface: 0xFFFFFF, hairline: 0xF0ECE5, controlBorder: 0xE5E1D9,
                    ink: 0x1C1B1A, muted: 0x6B6862, accentFill: 0x1C1B1A, accentText: 0x1C1B1A,
                    onAccent: 0xFFFFFF, highlight: 0xF4EFE4, adText: 0x6E4A12,
                    display: 0x1C1B1A, displayText: 0xFFFFFF, displayDim: 0xC9C5BD,
                    plate: 0xE5E1D9, playing: 0x1C1B1A)
        case .deckNight:
            // Deck in the dark: the same layout, dark warm page and cards.
            Palette(background: 0x141312, surface: 0x211F1D, hairline: 0x2C2A27, controlBorder: 0x37342F,
                    ink: 0xF2EFEA, muted: 0xA29E96, accentFill: 0xF2EFEA, accentText: 0xF2EFEA,
                    onAccent: 0x141312, highlight: 0x2E2B26, adText: 0xFFD66B,
                    display: 0x2C2A27, displayText: 0xF2EFEA, displayDim: 0x8B877F,
                    plate: 0x2C2A27, playing: 0x3A3733)
        }
    }
}

/// Colours and type for the Deck look. Page, cards, ink text and the
/// accent come from the chosen `ColourScheme`; what's playing is shown in
/// its artwork's colour (see `ArtworkColors`). Type is Outfit (bundled).
/// Some token names are kept from earlier looks.
enum Theme {
    private static var p: ColourScheme.Palette { ColourScheme.current.palette }

    /// The page behind everything.
    static var background: Color { Color(hex: p.background) }
    /// Cards and keys.
    static var surface: Color { Color(hex: p.surface) }
    static var hairline: Color { Color(hex: p.hairline) }

    /// Corner radius of every list card.
    static var cardRadius: CGFloat { 22 }
    /// The plate behind quiet controls.
    static var plate: Color { Color(hex: p.plate) }
    /// The card of the episode playing. Text on it is light.
    static var playingCard: Color { Color(hex: p.playing) }
    /// Outline buttons and quiet borders.
    static var controlBorder: Color { Color(hex: p.controlBorder) }
    static var ink: Color { Color(hex: p.ink) }
    /// Switches that are on: ink on the light page; in Deck night the
    /// app's coral, because a light ink switch with iOS's white knob read
    /// as all white (Paul, 19 Nov 2026).
    static var switchOn: Color { ColourScheme.current.isDark ? Color(hex: 0xEC6550) : Color(hex: p.ink) }
    /// Secondary text.
    static var muted: Color { Color(hex: p.muted) }
    /// The accent: keys that are on, switches; text on it is `onAccent`.
    /// It follows the colour of the episode that's playing (Paul, 11 Nov
    /// 2026), with the scheme's ink when nothing is playing (Deck night
    /// keeps its own light accent then, as black wouldn't show on the dark
    /// page). Reading it inside a view tracks `AccentColour`, so only views
    /// that use the accent redraw, once, when the episode changes.
    @MainActor static var accentFill: Color {
        if let playing = AccentColour.shared.colour { return playing }
        return ColourScheme.current.isDark ? Color(hex: p.accentFill) : idleAccent
    }
    /// Accent text on cards and the page.
    /// Deck night keeps light accent text: artwork colours are dark, made
    /// for light text on them, so as text on the dark page they'd be lost.
    @MainActor static var accentText: Color {
        if ColourScheme.current.isDark { return Color(hex: p.accentText) }
        return AccentColour.shared.colour ?? idleAccent
    }
    /// On a screen about one show (show page, episode page, show settings),
    /// that show's colour wins over what's playing (Paul, 11 Nov 2026).
    @MainActor static func showAccentFill(_ show: Color?) -> Color { show ?? accentFill }
    /// Deck night keeps its light accent text (dark show colours vanish on it).
    @MainActor static func showAccentText(_ show: Color?) -> Color {
        ColourScheme.current.isDark ? accentText : (show ?? accentText)
    }
    @MainActor static func showOnAccent(_ show: Color?) -> Color { show == nil ? onAccent : Color(hex: 0xF6F2E9) }
    /// Artwork colours are darkened for light text on them, as is the soft
    /// black; only Deck night's own light accent takes dark text.
    @MainActor static var onAccent: Color {
        if AccentColour.shared.colour == nil, ColourScheme.current.isDark { return Color(hex: p.onAccent) }
        return Color(hex: 0xF6F2E9)
    }
    /// The accent when nothing is playing.
    static let softBlack = Color(hex: 0x2B2925)
    /// Deck's ink when nothing plays (soft black in Deck night, where the
    /// scheme's own light accent is normally used instead).
    static var idleAccent: Color {
        ColourScheme.current == .deck ? Color(hex: 0x1C1B1A) : softBlack
    }

    // MARK: Deck tokens (prototype: https://claude.ai/artifact/CC3pxxR1XwBGtnp13xAdbB)

    /// Faint text (#8B877F).
    static var faint: Color { Color(hex: ColourScheme.current.isDark ? 0x7C7870 : 0x8B877F) }
    /// The fine card edge (#E5E1D9).
    static var cardEdge: Color { Color(hex: p.controlBorder) }
    /// Lines inside cards (#F0ECE5).
    static var cardLine: Color { Color(hex: p.hairline) }
    /// Ad sections and the Skip ad chip.
    static let deckAd = Color(hex: 0xFFD66B)
    /// Outfit (OFL, bundled in App/Fonts), the Deck type: titles 800,
    /// body 500-600, small labels 700 in capitals. Falls back to SF.
    static func outfit(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Outfit-ExtraBold"
        case .bold: name = "Outfit-Bold"
        case .medium, .regular, .light, .thin, .ultraLight: name = "Outfit-Medium"
        default: name = "Outfit-SemiBold"
        }
        return .custom(name, size: scaled(size, max: 1.25))
    }
    /// Behind list rows: the page colour.
    static var rowBackground: Color { background }
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

    /// Card shadows: black whatever the scheme (ink is light in Deck night).
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

    /// Headings and screen titles: Outfit ExtraBold.
    static func big(_ size: CGFloat) -> Font {
        outfit(size * 0.92, .heavy)
    }

    /// Big title text (player titles, ranks): Outfit ExtraBold, drawn a
    /// little smaller than `big`.
    static func serif(_ size: CGFloat) -> Font {
        outfit(size * 0.86, .heavy)
    }

    /// Row titles (episodes, shows, chapters): Outfit Bold.
    static func title(_ size: CGFloat) -> Font {
        outfit(size * 0.92, .bold)
    }

    /// Follows the iPhone's text size setting (Dynamic Type), within limits
    /// so the layouts still fit: up to 35% bigger for small text, 20% for
    /// the big titles; never smaller than designed.
    static func scaled(_ size: CGFloat, max factor: CGFloat = 1.35) -> CGFloat {
        let wanted = UIFontMetrics.default.scaledValue(for: size)
        return min(Swift.max(wanted, size), size * factor)
    }

    /// Body text at a set size (Outfit) that still follows the iPhone's
    /// text size setting, within limits.
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        outfit(size, weight)
    }

    /// Labels, times and counters: Outfit, small and a little heavier,
    /// with figures that don't jump about as they change.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        outfit(size + 0.5, weight == .regular ? .semibold : .bold).monospacedDigit()
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
