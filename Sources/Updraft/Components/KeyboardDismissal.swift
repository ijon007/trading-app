import SwiftUI
import UIKit

/// Installs one window-level tap recognizer that ends editing when the user taps
/// anywhere outside a text input, and closes an inset drawer when the tap lands
/// on empty space around it. It never cancels or delays touches, so buttons,
/// rows and gestures underneath behave exactly as before. Covers sheets too,
/// since they present in the same window.
struct KeyboardDismissal: UIViewRepresentable {
    /// Screens that manage focus themselves can switch this off while visible.
    @MainActor static var isEnabled = true

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

        @objc private func tapped(_ g: UITapGestureRecognizer) {
            // Keyboard first: a tap that only meant to end editing shouldn't also
            // close the drawer the user is filling in.
            let hidKeyboard = window?.endEditing(true) == true
            guard !hidKeyboard, KeyboardDismissal.isEnabled else { return }
            dismissDrawerIfEmptySpace(g)
        }

        /// Closes the topmost sheet when the tap is on the dimming view or in the
        /// gap around an inset liquid-glass drawer — not when it hits the sheet.
        private func dismissDrawerIfEmptySpace(_ g: UITapGestureRecognizer) {
            guard let window, let sheet = topPresentedSheet(in: window) else { return }
            let point = g.location(in: window)
            let card = sheet.view.convert(sheet.view.bounds, to: window)
            let hit = window.hitTest(point, with: nil)
            let outside = !card.insetBy(dx: 1, dy: 1).contains(point)
            if outside || isDimming(hit) {
                sheet.dismiss(animated: true)
            }
        }

        private func topPresentedSheet(in window: UIWindow) -> UIViewController? {
            var top = window.rootViewController
            while let next = top?.presentedViewController { top = next }
            guard let sheet = top, sheet !== window.rootViewController else { return nil }
            if sheet is UIAlertController { return nil }
            return sheet
        }

        private func isDimming(_ view: UIView?) -> Bool {
            var current = view
            while let v = current {
                if NSStringFromClass(type(of: v)).localizedCaseInsensitiveContains("Dimming") { return true }
                current = v.superview
            }
            return false
        }

        nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            MainActor.assumeIsolated {
                guard KeyboardDismissal.isEnabled else { return false }
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
