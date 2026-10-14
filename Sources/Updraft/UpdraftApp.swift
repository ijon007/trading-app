import SwiftUI

@main
struct UpdraftApp: App {
    @AppStorage("appearance") private var appearance: Appearance?

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(appearance?.scheme)
        }
    }
}
