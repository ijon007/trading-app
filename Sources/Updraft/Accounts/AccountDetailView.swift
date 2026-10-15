import SwiftUI
import UIKit

/// One account: rename, avatar color/emoji, address + QR, default, recovery
/// phrase (behind Face ID / passcode), transfer, and remove.
struct AccountDetailView: View {
    let accountID: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Account.storageKey) private var selectedID = ""
    @State private var name = ""
    @State private var showQR = false
    @State private var copied = false
    @State private var phrase: [String]?
    @State private var revealed = false
    @State private var transferring = false
    @State private var removing = false
    @FocusState private var nameFocused: Bool

    private var account: Account? { Account.all.first { $0.id == accountID } }

    var body: some View {
        Group {
            if let account { content(account) } else { Color.clear }
        }
        .background(Theme.background)
        .navigationTitle(account?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = account?.name ?? ""
            Account.ensureKeys(accountID)
        }
        .sheet(item: Binding(get: { phrase.map(PhraseBox.init) }, set: { if $0 == nil { phrase = nil } })) { box in
            phraseSheet(box.words)
        }
        .sheet(isPresented: $transferring) {
            InternalTransferSheet(fromID: accountID)
        }
        .sheet(isPresented: $removing) {
            if let account {
                RemoveAccountSheet(account: account) {
                    let wasSelected = selectedID == accountID
                    removing = false
                    dismiss()
                    withAnimation(.snappy) { Account.remove(accountID) }
                    if wasSelected { withAnimation(.spring(duration: 0.45, bounce: 0)) { selectedID = Account.defaultID } }
                }
            }
        }
    }

    private func content(_ account: Account) -> some View {
        List {
            Section {
                VStack(spacing: Space.sm) {
                    AccountAvatar(account: account, size: 72)
                        .animation(.snappy, value: account.emoji)
                        .animation(.snappy, value: account.color)
                    HStack(spacing: Space.xxs) {
                        if account.isDefault { AccountBadge(text: "Default") }
                        if account.isWatchOnly { AccountBadge(text: "Watch-only", icon: "eye") }
                    }
                    Text(account.totalBalance.fiat)
                        .font(Typo.figure)
                        .foregroundStyle(Theme.textSecondary)
                        .privateAmount()
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("Account name", text: $name)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    .onChange(of: nameFocused) { _, f in if !f { saveName() } }
                    .listRowBackground(Theme.surface)
            }

            Section("Avatar") {
                avatarPicker(account).listRowBackground(Theme.surface)
            }

            if let address = account.address {
                Section("Address") {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text(address)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                        if showQR {
                            QRCodeImage(text: address)
                                .frame(width: 180, height: 180)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        HStack(spacing: Space.xs) {
                            Button {
                                UIPasteboard.general.string = address
                                Haptics.success()
                                withAnimation(.snappy) { copied = true }
                                Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation(.snappy) { copied = false } }
                            } label: {
                                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            Button {
                                Haptics.tap()
                                withAnimation(.smooth(duration: 0.3)) { showQR.toggle() }
                            } label: {
                                Label(showQR ? "Hide QR" : "Show QR", systemImage: "qrcode")
                            }
                        }
                        .glassButton()
                        .controlSize(.small)
                        .tint(Theme.textPrimary)
                        .font(Typo.caption)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Theme.surface)
                }
            }

            Section {
                if !account.isDefault {
                    Button {
                        Haptics.success()
                        withAnimation(.snappy) { Account.setDefault(account.id) }
                        Account.update(account) // nudge observers so badges redraw
                    } label: { Label("Set as default", systemImage: "star") }
                }
                if !account.isWatchOnly {
                    Button { Haptics.tap(); transferring = true } label: {
                        Label("Transfer between accounts", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(account.holdings.isEmpty || Account.all.count < 2)
                    Button { revealPhrase() } label: { Label("Show recovery phrase", systemImage: "key") }
                }
            }
            .tint(Theme.textPrimary)
            .listRowBackground(Theme.surface)

            Section {
                Button(role: .destructive) {
                    Haptics.warning()
                    removing = true
                } label: {
                    Label("Remove account", systemImage: "trash")
                }
                .disabled(Account.all.count < 2)
                .listRowBackground(Theme.surface)
            } footer: {
                if Account.all.count < 2 { Text("You need at least one account.") }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func avatarPicker(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                ForEach(AccountPalette.keys, id: \.self) { key in
                    let selected = (account.color ?? "mono") == key
                    Button {
                        edit { $0.color = key == "mono" ? nil : key }
                    } label: {
                        Circle()
                            .fill(AccountPalette.color(key) ?? Theme.textPrimary)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Theme.background, lineWidth: selected ? 3 : 0))
                            .overlay(Circle().strokeBorder(selected ? Theme.textPrimary : .clear, lineWidth: 1.5).padding(-2))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(key)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: Space.xs) {
                emojiCell(nil, selected: account.emoji == nil, symbol: account.symbol)
                ForEach(AccountPalette.emojis, id: \.self) { e in
                    emojiCell(e, selected: account.emoji == e, symbol: account.symbol)
                }
            }
        }
        .padding(.vertical, Space.xs)
        .sensoryFeedback(.selection, trigger: account.color)
        .sensoryFeedback(.selection, trigger: account.emoji)
    }

    private func emojiCell(_ emoji: String?, selected: Bool, symbol: String) -> some View {
        Button {
            edit { $0.emoji = emoji }
        } label: {
            Group {
                if let emoji { Text(emoji).font(.system(size: 20)) } else {
                    Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 38, height: 38)
            .background(selected ? Theme.surfaceHi : .clear, in: .circle)
            .overlay(Circle().strokeBorder(selected ? Theme.textPrimary : Theme.hairline, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji ?? "Symbol")
    }

    private func edit(_ change: (inout Account) -> Void) {
        guard var a = account else { return }
        change(&a)
        withAnimation(.snappy) { Account.update(a) }
    }

    private func saveName() {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != account?.name else { name = account?.name ?? name; return }
        edit { $0.name = t }
    }

    private func revealPhrase() {
        Haptics.tap()
        Task {
            guard await DeviceAuth.verify(reason: "Show the recovery phrase for this account.") else { Haptics.error(); return }
            revealed = false
            phrase = Account.ensureKeys(accountID)
        }
    }

    private func phraseSheet(_ words: [String]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Anyone with these 12 words can take everything in this account. Never share them.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    PhraseGrid(words: words, revealed: $revealed)
                }
                .padding(Space.md)
            }
            .background(Theme.background)
            .navigationTitle("Recovery phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { phrase = nil } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PhraseBox: Identifiable {
    let words: [String]
    var id: String { words.joined(separator: " ") }
}

/// Remove confirmation. Accounts with keys: backup warning, then Face ID /
/// passcode, then hold to remove. Watch-only: a plain confirm.
private struct RemoveAccountSheet: View {
    let account: Account
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.sm) {
                AccountAvatar(account: account, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove \(account.name)?").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(account.isWatchOnly ? "You can add this address again any time."
                                             : "This removes the account from this iPhone.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
            }
            if !account.isWatchOnly {
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
                    Text("Make sure you've backed up your 12 words. Without them, this account can't be restored.")
                        .font(Typo.callout).foregroundStyle(Theme.textPrimary)
                }
                .transferCard()
            }
            if failed {
                Text("Couldn't verify it's you. Try again.")
                    .font(Typo.caption).foregroundStyle(Theme.negative)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            if account.isWatchOnly {
                Button(role: .destructive) { Haptics.success(); onRemove() } label: {
                    Text("Remove").font(Typo.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.negative)
                .controlSize(.large)
            } else {
                HoldToConfirm(title: "Hold to remove") { verifyAndRemove() }
            }
            Button("Cancel") { dismiss() }
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(Space.md)
        .padding(.top, Space.sm)
        .animation(.smooth(duration: 0.2), value: failed)
        .presentationDetents([.height(account.isWatchOnly ? 260 : 340)])
        .presentationDragIndicator(.visible)
        .background(Theme.background)
    }

    private func verifyAndRemove() {
        Task {
            if await DeviceAuth.verify(reason: "Remove \(account.name) from Updraft.") {
                Haptics.success()
                onRemove()
            } else {
                Haptics.error()
                failed = true
            }
        }
    }
}
