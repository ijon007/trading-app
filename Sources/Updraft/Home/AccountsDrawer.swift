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
    /// Sheet fits its rows (capped at large), so there's no empty space below.
    @State private var fittedHeight: CGFloat = 320
    @State private var detent: PresentationDetent = .height(320)

    var body: some View {
        NavigationStack {
            List {
                ForEach(Account.all) { account in
                    Button { select(account) } label: { row(account) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: Space.md, bottom: 10, trailing: Space.md))
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
                .listRowInsets(EdgeInsets(top: 12, leading: Space.md, bottom: 4, trailing: Space.md))
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                // The bottom inset includes the tab bar this sheet covers. Counting
                // it opens a blank band under the last row; keep only a short pad.
                let bottom = min(geo.contentInsets.bottom, Space.xs)
                return (geo.contentSize.height + geo.contentInsets.top + bottom).rounded()
            } action: { _, h in
                // Same as AddAccountSheet: follow content height while on the fitted detent.
                guard h > 0, abs(h - fittedHeight) > 1 else { return }
                let follow = detent == .height(fittedHeight)
                fittedHeight = h
                if follow { withAnimation(.smooth(duration: 0.3)) { detent = .height(h) } }
            }
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
        .presentationDetents([.height(fittedHeight), .inset], selection: $detent)
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
        let selected = account.id == accountID
        return HStack(spacing: Space.sm) {
            AccountAvatar(account: account, size: 38)
                // Selected: a thin ring with a small gap, springing in on switch.
                .overlay {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 2)
                        .padding(-5)
                        .scaleEffect(selected ? 1 : 0.85)
                        .opacity(selected ? 1 : 0)
                        .animation(.spring(duration: 0.35, bounce: 0.3), value: selected)
                }
                .padding(.horizontal, 3)
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
        }
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
