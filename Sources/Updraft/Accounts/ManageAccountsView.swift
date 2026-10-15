import SwiftUI

/// Manage accounts: every account with avatar, short address, balance and
/// Default / Watch-only badges. Edit to drag-reorder; tap for details.
struct ManageAccountsView: View {
    @AppStorage(PrivacyMode.storageKey) private var hideAmounts = false
    @AppStorage(Account.storageKey) private var selectedID = ""
    @State private var adding = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(Account.all) { account in
                    NavigationLink(value: account.id) { row(account) }
                        .listRowBackground(Theme.surface)
                }
                .onMove { from, to in
                    Haptics.select()
                    withAnimation(.snappy) { Account.move(fromOffsets: from, toOffset: to) }
                }
            } footer: {
                Text("The default account opens when the last one you used is gone. Tap Edit to reorder.")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Section {
                Button { Haptics.tap(); adding = true } label: {
                    Label("Add account", systemImage: "plus")
                        .foregroundStyle(Theme.textPrimary)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { AccountDetailView(accountID: $0) }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .animation(.snappy, value: Account.all.map(\.id))
        .sheet(isPresented: $adding) {
            AddAccountSheet { account in
                Account.add(account)
                withAnimation(.spring(duration: 0.45, bounce: 0)) { selectedID = account.id }
            }
        }
    }

    private func row(_ account: Account) -> some View {
        HStack(spacing: Space.sm) {
            AccountAvatar(account: account, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.xxs) {
                    Text(account.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if account.isDefault { AccountBadge(text: "Default") }
                    if account.isWatchOnly { AccountBadge(text: "Watch-only", icon: "eye") }
                }
                Text(account.address.map(Account.shortAddress) ?? "No address yet")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Space.xs)
            Text(hideAmounts ? "••••" : account.totalBalance.fiat)
                .font(Typo.figure)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: account.totalBalance))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
