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
        private weak var keyboardTap: UITapGestureRecognizer?
        private weak var drawerTap: UITapGestureRecognizer?
        private var keyboardVisible = false

        deinit { NotificationCenter.default.removeObserver(self) }

        func install(in window: UIWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window
            listenForKeyboard()

            let keyboard = UITapGestureRecognizer(target: self, action: #selector(tappedKeyboard))
            keyboard.cancelsTouchesInView = false
            keyboard.delaysTouchesBegan = false
            keyboard.delaysTouchesEnded = false
            keyboard.delegate = self
            window.addGestureRecognizer(keyboard)
            keyboardTap = keyboard

            let drawer = UITapGestureRecognizer(target: self, action: #selector(tappedDrawer))
            drawer.cancelsTouchesInView = false
            drawer.delaysTouchesBegan = false
            drawer.delaysTouchesEnded = false
            drawer.delegate = self
            window.addGestureRecognizer(drawer)
            drawerTap = drawer
        }

        private func listenForKeyboard() {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardShown), name: UIResponder.keyboardDidShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardHidden), name: UIResponder.keyboardDidHideNotification, object: nil)
        }

        @objc private func keyboardShown() { keyboardVisible = true }
        @objc private func keyboardHidden() { keyboardVisible = false }

        @objc private func tappedKeyboard() {
            window?.endEditing(true)
        }

        @objc private func tappedDrawer(_ g: UITapGestureRecognizer) {
            guard KeyboardDismissal.isEnabled, !keyboardVisible else { return }
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
                if g === drawerTap { return isEmptySpaceAroundDrawer(touch) }
                // Keyboard: only while editing, so a tap on a sheet doesn't
                // compete with the top-of-scroll dismiss pan.
                if g === keyboardTap { return keyboardVisible && !isTextInput(touch.view) }
                return false
            }
        }

        private func isEmptySpaceAroundDrawer(_ touch: UITouch) -> Bool {
            guard let window, topPresentedSheet(in: window) != nil else { return false }
            if isDimming(touch.view) { return true }
            let point = touch.location(in: window)
            guard let sheet = topPresentedSheet(in: window) else { return false }
            let card = sheet.view.convert(sheet.view.bounds, to: window)
            return !card.insetBy(dx: 1, dy: 1).contains(point)
        }

        private func isTextInput(_ view: UIView?) -> Bool {
            var current = view
            while let v = current {
                if v is UITextField || v is UITextView || v is UISearchBar { return true }
                current = v.superview
            }
            return false
        }
    }
}
