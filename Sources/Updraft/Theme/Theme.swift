import SwiftUI
import UIKit

/// Updraft colorway: pure grayscale, light and dark. Only color is gains/losses.
enum Theme {
    // Surfaces
    static let background = Color(light: 0xF7F7F5, dark: 0x0B0B0C)
    static let surface    = Color(light: 0xFFFFFF, dark: 0x161617)
    static let surfaceHi  = Color(light: 0xEDEDEB, dark: 0x202022)
    static let hairline   = Color(light: 0xE2E2E0, dark: 0x2A2A2C)

    // Text
    static let textPrimary   = Color(light: 0x0B0B0C, dark: 0xF7F7F5)
    static let textSecondary = Color(light: 0x6B6B6E, dark: 0x9A9A9D)
    static let textTertiary  = Color(light: 0xA3A3A6, dark: 0x5C5C5F)

    // Accent = primary text (black / white)
    static let accent = textPrimary

    /// Toggle "on" tint: black in light; muted green in dark so on/off stay distinct.
    static let toggleTint = Color(light: 0x0B0B0C, dark: 0x34D399)

    // Market semantics (muted)
    static let positive = Color(light: 0x2F8F5B, dark: 0x34D399)
    static let negative = Color(light: 0xC0483C, dark: 0xF87171)

    // Type helpers (SF)
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .regular) }
    static func figure(_ size: CGFloat) -> Font { .system(size: size, weight: .medium).monospacedDigit() }

    static let radius: CGFloat = Radius.lg
}

extension PresentationDetent {
    /// Just short of `.large`, so iOS 26 keeps the floating glass gap at the edges.
    static let inset = PresentationDetent.fraction(0.92)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    init(light: UInt32, dark: UInt32) {
        func ui(_ h: UInt32) -> UIColor {
            UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255,
                    blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

extension View {
    /// Standard Liquid Glass card used across Updraft.
    func glassCard(radius: CGFloat = Theme.radius) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: radius))
    }

    /// Rubber-band (and the sheet-drag that rides on it) only when content overflows.
    func bounceWhenOverflows() -> some View {
        scrollBounceBehavior(.basedOnSize)
    }
}
