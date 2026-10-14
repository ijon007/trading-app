import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Text(title)
                .font(Theme.display(34))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
