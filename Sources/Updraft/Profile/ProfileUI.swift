import SwiftUI
import UIKit

extension View {
    /// Plain (non-glass) content card on the Theme surface. Use glass only for floating/interactive controls.
    func surfaceCard(radius: CGFloat = Radius.lg) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: radius))
    }

    /// Dismisses the keyboard when tapping anywhere outside a text field, without blocking other taps.
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private var recognizer: UITapGestureRecognizer?
        private weak var host: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recognizer { host?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            guard let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
            host = window
        }

        @objc private func dismiss() { window?.endEditing(true) }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var v = touch.view
            while let view = v {
                if view is UITextField || view is UITextView { return false }
                v = view.superview
            }
            return true
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

/// Horizontal shake used for wrong input. Animate `shakes` up by 1 to play once.
struct Shake: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(shakes * .pi * 4), y: 0))
    }
}
