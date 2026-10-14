import SwiftUI

/// Aurum colorway: obsidian blacks, warm ivory text, champagne-gold accent.
enum Theme {
    // Surfaces
    static let background = Color(hex: 0x0B0B0D)   // obsidian
    static let surface    = Color(hex: 0x151518)   // raised card
    static let surfaceHi  = Color(hex: 0x1F1F23)   // elevated / pressed
    static let hairline   = Color.white.opacity(0.08)

    // Text
    static let textPrimary   = Color(hex: 0xF4F1EA) // ivory
    static let textSecondary = Color(hex: 0xA19D94) // warm gray
    static let textTertiary  = Color(hex: 0x5E5B55)

    // Accent
    static let gold     = Color(hex: 0xC9A96E)      // champagne gold
    static let goldSoft = Color(hex: 0xC9A96E).opacity(0.14)

    // Market semantics (muted, not neon)
    static let positive = Color(hex: 0x5FB38A)
    static let negative = Color(hex: 0xD06A5E)

    // Type: serif display for luxury headlines, SF for UI, mono for figures
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular) }
    static func figure(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded).monospacedDigit() }

    // Shape
    static let radius: CGFloat = 22
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension View {
    /// Standard Liquid Glass card used across Aurum.
    func aurumGlass(radius: CGFloat = Theme.radius) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: radius))
    }
}
