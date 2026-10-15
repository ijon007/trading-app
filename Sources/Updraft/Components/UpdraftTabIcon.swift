import SwiftUI
import UIKit

/// The Updraft stripes (UpdraftLogoShape) as a template image for the tab bar,
/// so it tints like the SF Symbols beside it for selected and unselected states.
@MainActor
enum UpdraftTabIcon {
    /// Sized to sit optically with house/safari/person symbols in the tab bar.
    static let image: UIImage = {
        let canvas = CGSize(width: 24, height: 24)
        let mark = CGRect(x: 0, y: 0, width: 15, height: 20)
            .offsetBy(dx: (canvas.width - 15) / 2, dy: (canvas.height - 20) / 2)
        let image = UIGraphicsImageRenderer(size: canvas).image { ctx in
            UIColor.black.setFill()
            ctx.cgContext.addPath(UpdraftLogoShape().path(in: mark).cgPath)
            ctx.cgContext.fillPath()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }()
}
