import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case home, explore, social, profile }
    @State private var tab: AppTab = .home
    @AppStorage(OnboardingKeys.done) private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if hasOnboarded {
                tabs.transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasOnboarded)
        .appLock()
        .task { MarketStore.shared.start() }
        // No socket in the background; reconnect on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { MarketStore.shared.start() } else if phase == .background { MarketStore.shared.stop() }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) { HomeView() } label: { Label { Text("Home") } icon: { Image(uiImage: UpdraftTabIcon.image) }.labelStyle(.iconOnly).accessibilityLabel("Home") }
            Tab(value: AppTab.explore) { ExploreView() } label: { icon("safari.fill", "Explore") }
            Tab(value: AppTab.social) { SocialView() } label: { icon("person.2.fill", "Social") }
            Tab(value: AppTab.profile) { ProfileView() } label: { icon("person.crop.circle.fill", "Profile") }
        }
        .sensoryFeedback(.selection, trigger: tab)
        .privacyFlipToHide()
    }

    /// Icon-only tab label; the title stays for VoiceOver.
    private func icon(_ symbol: String, _ title: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .accessibilityLabel(title)
    }
}
