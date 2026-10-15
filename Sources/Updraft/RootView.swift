import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case home, explore, profile }
    @State private var tab: AppTab = .home
    @AppStorage(OnboardingKeys.done) private var hasOnboarded = false

    var body: some View {
        ZStack {
            if hasOnboarded {
                tabs.transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasOnboarded)
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) { HomeView() } label: { icon("house.fill", "Home") }
            Tab(value: AppTab.explore) { ExploreView() } label: { icon("safari.fill", "Explore") }
            Tab(value: AppTab.profile) { ProfileView() } label: { icon("person.crop.circle.fill", "Profile") }
        }
        .sensoryFeedback(.selection, trigger: tab)
    }

    /// Icon-only tab label; the title stays for VoiceOver.
    private func icon(_ symbol: String, _ title: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .accessibilityLabel(title)
    }
}
