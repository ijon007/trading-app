import SwiftUI
import UIKit

/// Circular avatar pre-rendered for the tab bar (template rendering off).
enum TabAvatar {
    static let size: CGFloat = 26

    /// Returns nil when no avatar asset exists, so callers fall back to a symbol.
    static func image(selected: Bool) -> UIImage? {
        guard let source = UIImage(named: "avatar-sample", in: .module, with: nil) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let ring: CGFloat = 1.5
        let image = UIGraphicsImageRenderer(size: rect.size).image { _ in
            let inset = selected ? rect.insetBy(dx: ring + 1, dy: ring + 1) : rect
            UIBezierPath(ovalIn: inset).addClip()
            source.draw(in: inset)
            if selected {
                UIGraphicsGetCurrentContext()?.resetClip()
                let path = UIBezierPath(ovalIn: rect.insetBy(dx: ring / 2, dy: ring / 2))
                path.lineWidth = ring
                UIColor.label.setStroke()
                path.stroke()
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
