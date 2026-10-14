import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Portfolio", systemImage: "chart.pie") { PlaceholderScreen(title: "Portfolio") }
            Tab("Markets", systemImage: "chart.line.uptrend.xyaxis") { PlaceholderScreen(title: "Markets") }
            Tab("Trade", systemImage: "arrow.left.arrow.right") { PlaceholderScreen(title: "Trade") }
            Tab("Account", systemImage: "person.crop.circle") { PlaceholderScreen(title: "Account") }
        }
    }
}
