import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case home, explore, profile }
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) { HomeView() } label: { icon("house.fill", "Home") }
            Tab(value: AppTab.explore) { ExploreView() } label: { icon("safari.fill", "Explore") }
            Tab(value: AppTab.profile) { ProfileView() } label: { avatar }
        }
        .sensoryFeedback(.selection, trigger: tab)
    }

    /// Profile tab: the user's avatar, ringed when selected; falls back to a symbol.
    @ViewBuilder private var avatar: some View {
        if let image = TabAvatar.image(selected: tab == .profile) {
            Label {
                Text("Profile")
            } icon: {
                Image(uiImage: image).renderingMode(.original)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Profile")
        } else {
            icon("person.crop.circle.fill", "Profile")
        }
    }

    /// Icon-only tab label; the title stays for VoiceOver.
    private func icon(_ symbol: String, _ title: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .accessibilityLabel(title)
    }
}
