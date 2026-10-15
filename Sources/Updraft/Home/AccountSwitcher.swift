import SwiftUI

/// Compact account switcher for the top of Home: avatar, name and a chevron,
/// opening a native menu of accounts with their balances.
struct AccountSwitcher: View {
    @Binding var accountID: String

    private var current: Account { Account.all.first { $0.id == accountID } ?? Account.all[0] }

    var body: some View {
        Menu {
            Section("Accounts") {
                ForEach(Account.all) { account in
                    Button {
                        select(account)
                    } label: {
                        Text(account.name)
                        Text(account.totalBalance.fiat)
                        Image(systemName: account.id == current.id ? "checkmark" : account.symbol)
                    }
                }
            }
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
        .menuOrder(.fixed)
        .accessibilityLabel("Account, \(current.name)")
        .accessibilityHint("Switch account")
    }

    private func select(_ account: Account) {
        guard account.id != accountID else { return }
        // One spring for the whole Home: name, balance digits, chart line and rows.
        withAnimation(.spring(duration: 0.45, bounce: 0)) { accountID = account.id }
    }
}

/// Round avatar with the account's symbol; inverts with the theme.
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: account.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.background)
            .frame(width: size, height: size)
            .background(Theme.textPrimary, in: .circle)
            .contentTransition(.symbolEffect(.replace))
    }
}
