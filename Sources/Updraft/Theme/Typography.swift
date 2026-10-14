import SwiftUI

/// Type scale. SF for UI, tight tracking and monospaced digits on numerals.
enum Typo {
    static let hero     = Font.system(size: 48, weight: .semibold).monospacedDigit()
    static let numeral  = Font.system(size: 34, weight: .semibold).monospacedDigit()
    static let title    = Font.system(size: 28, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body     = Font.system(size: 16, weight: .regular)
    static let callout  = Font.system(size: 15, weight: .regular)
    static let caption  = Font.system(size: 12, weight: .medium)
    static let figure   = Font.system(size: 15, weight: .medium).monospacedDigit()

    static let heroTracking: CGFloat = -1.6
    static let numeralTracking: CGFloat = -1.0
    static let titleTracking: CGFloat = -0.6
    static let captionTracking: CGFloat = 0.6
}

extension View {
    func heroNumeral() -> some View { font(Typo.hero).tracking(Typo.heroTracking) }
    func numeral() -> some View { font(Typo.numeral).tracking(Typo.numeralTracking) }
    func titleStyle() -> some View { font(Typo.title).tracking(Typo.titleTracking) }
    func eyebrow() -> some View { font(Typo.caption).tracking(Typo.captionTracking).textCase(.uppercase) }
}
