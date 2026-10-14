import SwiftUI

@main
struct AurumApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.gold)
                .preferredColorScheme(.dark)
        }
    }
}
