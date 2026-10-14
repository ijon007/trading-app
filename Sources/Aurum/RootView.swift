import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "circle.hexagongrid") { PlaceholderScreen(title: "Home") }
            Tab("Markets", systemImage: "chart.line.uptrend.xyaxis") { PlaceholderScreen(title: "Markets") }
            Tab("Wallet", systemImage: "wallet.bifold") { PlaceholderScreen(title: "Wallet") }
            Tab("Profile", systemImage: "person.crop.circle") { PlaceholderScreen(title: "Profile") }
        }
    }
}
