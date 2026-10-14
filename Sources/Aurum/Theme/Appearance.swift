import SwiftUI

/// Light or dark. Stored under "appearance"; unset means follow the system.
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark
    var id: String { rawValue }
    var title: String { self == .light ? "Light" : "Dark" }
    var scheme: ColorScheme { self == .light ? .light : .dark }
    init(_ scheme: ColorScheme) { self = scheme == .dark ? .dark : .light }
}
