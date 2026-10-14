import SwiftUI

/// Thin wrappers over native iOS 26 glass button styles.
extension View {
    /// Native `.glass` button with a light haptic.
    func glassButton() -> some View { buttonStyle(.glass) }
    /// Native `.glassProminent` button, tinted with the primary (black/white) color.
    func glassProminentButton() -> some View { buttonStyle(.glassProminent).tint(Theme.accent) }
    /// Native glass circle button (icon only).
    func glassCircleButton() -> some View { buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.large) }
}
