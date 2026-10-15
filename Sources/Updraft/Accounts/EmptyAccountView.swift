import SwiftUI

/// Home state for an account with no assets: a quiet symbol, one line of
/// guidance and a single action. The action is routed through Home's own
/// drawer state, so no sheet is ever presented from inside this view.
struct EmptyAccountView: View {
    let onReceive: () -> Void

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .staggered(0)
            VStack(spacing: Space.xxs) {
                Text("No assets yet")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("Receive crypto to start using this account.")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .staggered(1)
            Button {
                Haptics.tap()
                onReceive()
            } label: {
                Label("Receive", systemImage: "arrow.down")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, Space.xs)
            }
            .glassProminentButton()
            .controlSize(.regular)
            .padding(.top, Space.xs)
            .staggered(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .accessibilityElement(children: .contain)
    }
}
