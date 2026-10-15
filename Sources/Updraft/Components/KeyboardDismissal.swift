import SwiftUI
import UIKit

/// Installs one window-level tap recognizer that ends editing when the user taps
/// anywhere outside a text input. It never cancels or delays touches, so buttons,
/// rows and gestures underneath behave exactly as before. Covers sheets too,
/// since they present in the same window.
struct KeyboardDismissal: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        let coordinator = context.coordinator
        Task { @MainActor in coordinator.install(in: view.window) }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.install(in: view.window)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?

        func install(in window: UIWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func tapped() { window?.endEditing(true) }

        nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            MainActor.assumeIsolated {
                // Let taps inside text inputs (and their clear buttons) keep focus.
                var view = touch.view
                while let v = view {
                    if v is UITextField || v is UITextView || v is UISearchBar { return false }
                    view = v.superview
                }
                return true
            }
        }
    }
}
