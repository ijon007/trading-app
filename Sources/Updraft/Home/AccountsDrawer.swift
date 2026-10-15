import SwiftUI

/// Account drawer from Home: tap to switch, swipe to delete or set default,
/// add at the bottom.
struct AccountsDrawer: View {
    @Binding var accountID: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrivacyMode.storageKey) private var hideAmounts = false
    @State private var adding = false
    @State private var deleting: Account?
    @State private var authFailed = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Account.all) { account in
                    Button { select(account) } label: { row(account) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.hairline)
                        .swipeActions(edge: .trailing) {
                            if Account.all.count > 1 {
                                Button("Delete", systemImage: "trash") { Haptics.warning(); deleting = account }
                                    .tint(Theme.negative)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !account.isDefault {
                                Button("Default", systemImage: "star") { setDefault(account) }
                                    .tint(Theme.textSecondary)
                            }
                        }
                        .contextMenu {
                            if !account.isDefault {
                                Button("Set as default", systemImage: "star") { setDefault(account) }
                            }
                            if Account.all.count > 1 {
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = account }
                            }
                        }
                }
                Button { Haptics.tap(); adding = true } label: {
                    Label("Add account", systemImage: "plus")
                        .font(Typo.body.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(.snappy, value: Account.all.map(\.id))
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn't verify it's you", isPresented: $authFailed) { Button("OK", role: .cancel) {} }
            .confirmationDialog(deleteTitle, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible, presenting: deleting) { account in
                Button("Delete \(account.name)", role: .destructive) { delete(account) }
            } message: { account in
                Text(account.isWatchOnly ? "You can add this address again any time."
                     : "Make sure you've backed up your 12 words. Without them, this account can't be restored.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $adding) {
            AddAccountSheet { account in
                Account.add(account)
                select(account)
            }
        }
    }

    private var deleteTitle: String { "Delete \(deleting?.name ?? "account")?" }

    private func row(_ account: Account) -> some View {
        HStack(spacing: Space.sm) {
            AccountAvatar(account: account, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.xxs) {
                    Text(account.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    if account.isDefault { AccountBadge(text: "Default") }
                    if account.isWatchOnly { AccountBadge(text: "Watch", icon: "eye") }
                }
                if let address = account.address {
                    Text(Account.shortAddress(address))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: Space.xs)
            Text(hideAmounts ? "••••" : account.totalBalance.fiat)
                .font(Typo.figure)
                .foregroundStyle(Theme.textPrimary)
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .opacity(account.id == accountID ? 1 : 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(account.id == accountID ? .isSelected : [])
    }

    private func select(_ account: Account) {
        Haptics.select()
        withAnimation(.spring(duration: 0.45, bounce: 0)) { accountID = account.id }
        dismiss()
    }

    private func setDefault(_ account: Account) {
        Haptics.success()
        Account.setDefault(account.id)
        Account.update(account) // redraw badges
    }

    private func delete(_ account: Account) {
        guard !account.isWatchOnly else { remove(account); return }
        Task {
            if await DeviceAuth.verify(reason: "Delete \(account.name) from Updraft.") { remove(account) }
            else { Haptics.error(); authFailed = true }
        }
    }

    private func remove(_ account: Account) {
        let wasSelected = account.id == accountID
        withAnimation(.snappy) { _ = Account.remove(account.id) }
        Haptics.success()
        if wasSelected { withAnimation(.spring(duration: 0.45, bounce: 0)) { accountID = Account.defaultID } }
    }
}
