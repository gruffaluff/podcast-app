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
