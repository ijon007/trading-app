import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case home, explore, profile }
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
        .task { MarketStore.shared.start() }
        // No socket in the background; reconnect on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { MarketStore.shared.start() } else if phase == .background { MarketStore.shared.stop() }
        }
    }

    private var tabs: some View {
        // Custom glass bar (Components/GlassTabBar.swift); pages stay alive in the ZStack.
        ZStack {
            HomeView().glassTabPage(tab == .home)
            ExploreView().glassTabPage(tab == .explore)
            ProfileView().glassTabPage(tab == .profile)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(selection: $tab, items: [
                GlassTabItem(AppTab.home, "Home", image: Image(uiImage: UpdraftTabIcon.image)),
                GlassTabItem(AppTab.explore, "Explore", systemImage: "safari.fill"),
                GlassTabItem(AppTab.profile, "Profile", systemImage: "person.crop.circle.fill"),
            ])
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .privacyFlipToHide()
    }

    /// Icon-only tab label; the title stays for VoiceOver.
    private func icon(_ symbol: String, _ title: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .accessibilityLabel(title)
    }
}
