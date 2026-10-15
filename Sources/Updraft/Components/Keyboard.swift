import UIKit

/// Keyboard helpers shared across Updraft.
@MainActor
enum Keyboard {
    /// Ends editing in whatever field is focused.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
