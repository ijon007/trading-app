import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeView() }
            Tab("Explore", systemImage: "safari") { ExploreView() }
            Tab("Profile", systemImage: "person.crop.circle") { ProfileView() }
        }
    }
}
