import SwiftUI

/// Home empty state for an account with no assets: a bare icon, one line and an action.
struct EmptyAccountView: View {
    let onReceive: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No assets yet", systemImage: "wallet.bifold")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
        } description: {
            Text("Receive crypto to start this account.")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
        } actions: {
            Button {
                Haptics.tap()
                onReceive()
            } label: {
                Label("Receive", systemImage: "arrow.down")
                    .font(Typo.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Theme.background)
            .controlSize(.large)
        }
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(Theme.textSecondary)
        .padding(.vertical, Space.lg)
    }
}
