import SwiftUI

/// Compact account switcher for the top of Home: avatar, name and a chevron,
/// opening a native menu of accounts with their balances.
struct AccountSwitcher: View {
    @Binding var accountID: String
    @State private var open = false

    private var current: Account { Account.all.first { $0.id == accountID } ?? Account.all[0] }

    var body: some View {
        Button {
            Haptics.tap()
            open = true
        } label: {
            HStack(spacing: Space.xs) {
                AccountAvatar(account: current, size: 26)
                Text(current.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.interpolate)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, Space.sm)
            .padding(.vertical, 4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { AccountsDrawer(accountID: $accountID) }
        .accessibilityLabel("Account, \(current.name)")
        .accessibilityHint("Switch account")
    }
}

/// Round avatar: the account's emoji or symbol on its color (default inverts with the theme).
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 26

    var body: some View {
        let tint = AccountPalette.color(account.color)
        Group {
            if let emoji = account.emoji {
                Text(emoji).font(.system(size: size * 0.5))
            } else {
                Image(systemName: account.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(tint == nil ? Theme.background : Color.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: size, height: size)
        .background(tint ?? (account.emoji == nil ? Theme.textPrimary : Theme.surfaceHi), in: .circle)
    }
}
