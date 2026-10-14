import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text(title)
                    .titleStyle()
                    .foregroundStyle(Theme.textPrimary)
            }
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
