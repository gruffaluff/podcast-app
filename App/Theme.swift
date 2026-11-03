import SwiftUI

/// Colours and type: the "Tape Deck" look (Paul's pick, Nov 2026). Warm grey
/// device panels, ink keys, one orange accent, monospaced labels and times,
/// and a dark display panel for what's playing. See docs/DESIGN.md.
enum Theme {
    /// The device face behind everything.
    static let background = Color(hex: 0xE8E6E1)
    /// Raised panels and keys.
    static let surface = Color(hex: 0xF4F3EF)
    static let hairline = Color(hex: 0xDCD9D2)
    /// The shadow under a key (and outline buttons).
    static let controlBorder = Color(hex: 0xC9C6BE)
    static let ink = Color(hex: 0x1B1B1A)
    /// Secondary text (5.6:1 on the background).
    static let muted = Color(hex: 0x5F5C55)
    /// Orange keys and switches; text on it is ink.
    static let accentFill = Color(hex: 0xF05A1A)
    static let accentShadow = Color(hex: 0xB8410E)
    /// Orange text on light panels (5:1).
    static let accentText = Color(hex: 0xB03A0A)
    static let highlight = Color(hex: 0xFCD9C1)
    static let adMarker = Color(hex: 0xFFB000)

    // The dark display panel.
    static let display = Color(hex: 0x22231F)
    static let displayText = Color(hex: 0xE6EDD7)
    static let displayDim = Color(hex: 0x9DA690)
    static let displayTrack = Color(hex: 0x3A3C35)

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

    /// Screen and section titles: monospaced, bold.
    static func screenTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size * 0.72, weight: .bold, design: .monospaced)
    }

    /// Labels, times and counters.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
