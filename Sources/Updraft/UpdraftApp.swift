import SwiftUI

@main
struct UpdraftApp: App {
    @AppStorage("appearance") private var appearance: Appearance?

    var body: some Scene {
        WindowGroup {
            RootView()
                // App-wide: tap on empty space dismisses the keyboard and closes drawers.
                .background(KeyboardDismissal())
                .tint(Theme.accent)
                .preferredColorScheme(appearance?.scheme)
        }
    }
}
