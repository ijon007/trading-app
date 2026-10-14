import SwiftUI

struct RootView: View {
    enum AppTab: Hashable { case home, explore, profile }
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            Tab("Explore", systemImage: "safari", value: AppTab.explore) { ExploreView() }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) { ProfileView() }
        }
        .sensoryFeedback(.selection, trigger: tab)
    }
}
