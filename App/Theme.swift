import SwiftUI

/// Colours and type from docs/DESIGN.md.
enum Theme {
    static let background = Color(hex: 0xFAF8F3)
    static let surface = Color(hex: 0xF1EEE6)
    static let hairline = Color(hex: 0xE8E3D8)
    static let controlBorder = Color(hex: 0xD9D4C7)
    static let ink = Color(hex: 0x1F1E1B)
    static let muted = Color(hex: 0x6B675E)
    static let accentFill = Color(hex: 0xAD5230)
    static let accentText = Color(hex: 0xA4512F)
    static let highlight = Color(hex: 0xF3E3C6)
    static let adMarker = Color(hex: 0xD9A441)

    /// Muted tones for artwork placeholders.
    static let placeholders: [Color] = ([0x4A5D73, 0x4F6B5A, 0x7A5368, 0x8A6A3F, 0x5B5750, 0x6A5E86] as [UInt32]).map { Color(hex: $0) }

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

    static func screenTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .medium, design: .serif)
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
