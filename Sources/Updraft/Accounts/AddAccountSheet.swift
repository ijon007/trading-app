import SwiftUI

/// Add an account (a wallet): create a new one, or import one from a recovery
/// phrase or private key. Import is a UI mock with light validation only.
struct AddAccountSheet: View {
    /// Called with the new account; the caller appends and selects it.
    let onAdd: (Account) -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case create = "Create new", importWallet = "Import", watch = "Watch"
        var id: String { rawValue }
    }

    /// Avatar symbols, matching how existing accounts are shown.
    private static let symbols = [
        "person.fill", "building.columns.fill", "bolt.fill", "leaf.fill",
        "flame.fill", "star.fill", "briefcase.fill", "airplane",
        "house.fill", "heart.fill", "globe", "lock.fill",
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .create
    @State private var name = "Account \(Account.all.count + 1)"
    @State private var symbol = AddAccountSheet.symbols
        .first { s in !Account.all.contains { $0.symbol == s } } ?? "person.fill"
    @State private var secret = ""
    @State private var usesKey = false
    /// Create pushes the backup flow before the account is added.
    @State private var creating = false
    @State private var address = ""
    /// Watch: resolving the ENS name / fetching balances, and the last failure.
    @State private var resolving = false
    @State private var watchError: String?
    /// Last name we filled in from the address; replaced only while the user hasn't edited it.
    @State private var autoName: String?
    @FocusState private var focused: Bool
    /// Content height (plus nav bar and button insets), so the sheet opens fitted.
    @State private var fittedHeight: CGFloat = 520
    @State private var detent: PresentationDetent = .height(520)

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch mode {
        case .create: return true
        case .importWallet: return ImportWalletFields.isValid(secret, usesKey: usesKey)
        case .watch: return WatchInput.isValid(address) && !resolving
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Picker("Type", selection: $mode.animation(.smooth(duration: 0.3))) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .watch {
                        watchFields
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    field("Name") {
                        TextField("Account name", text: $name)
                            .font(Typo.body)
                            .foregroundStyle(Theme.textPrimary)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(Space.md)
                            .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                    }

                    if mode != .watch {
                        field("Icon") {
                            symbolGrid
                                .padding(Space.md)
                                .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                        }
                    }

                    if mode == .importWallet {
                        field("Wallet") {
                            ImportWalletFields(secret: $secret, usesKey: $usesKey, focused: $focused)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.md)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                (geo.contentSize.height + geo.contentInsets.top + geo.contentInsets.bottom).rounded()
            } action: { _, height in
                guard height > 0, abs(height - fittedHeight) > 1 else { return }
                let follow = detent == .height(fittedHeight)
                fittedHeight = height
                if follow { withAnimation(.smooth(duration: 0.3)) { detent = .height(height) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Add account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { submitButton }
            .navigationDestination(isPresented: $creating) {
                CreateWalletFlow(name: trimmedName, symbol: symbol) { account in
                    onAdd(account)
                    dismiss()
                }
            }
            .onChange(of: creating) { _, on in
                if on { withAnimation(.smooth(duration: 0.3)) { detent = .large } }
            }
            .sensoryFeedback(.selection, trigger: mode)
            .sensoryFeedback(.selection, trigger: symbol)
        }
        .presentationDetents([.height(fittedHeight), .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var watchFields: some View {
        let trimmed = WatchInput.trimmed(address)
        let valid = WatchInput.isValid(address)
        return VStack(alignment: .leading, spacing: Space.md) {
            field("Address") {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xs) {
                        TextField("0x… or name.eth", text: $address)
                            .font(Typo.body.monospaced())
                            .foregroundStyle(Theme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .submitLabel(.done)
                            .focused($focused)
                        PasteButton(payloadType: String.self) { strings in
                            let text = strings.first ?? ""
                            Task { @MainActor in address = text }
                        }
                        .labelStyle(.titleOnly)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(Theme.textPrimary)
                    }
                    .padding(.leading, Space.md)
                    .padding(.trailing, Space.sm)
                    .padding(.vertical, Space.sm)
                    .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                    Label(watchError ?? WatchInput.hint(address),
                          systemImage: watchError != nil ? "exclamationmark.circle.fill" : valid ? "checkmark.circle.fill" : "info.circle")
                        .font(Typo.caption)
                        .foregroundStyle(watchError != nil ? Theme.negative : valid ? Theme.positive : (trimmed.isEmpty ? Theme.textSecondary : Theme.negative))
                        .contentTransition(.interpolate)
                        .animation(.smooth(duration: 0.2), value: valid)
                }
            }
            HStack(spacing: Space.xs) {
                Image(systemName: "eye")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                Text("View only. You can't send from this account.")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .onChange(of: address) { _, new in
            watchError = nil
            guard WatchInput.isValid(new) else { return }
            let short = WatchInput.short(new)
            // Prefill the name unless the user typed their own.
            if autoName == trimmedName || name == "Account \(Account.all.count + 1)" {
                name = short
                autoName = short
            }
        }
    }

    /// Section label above a surface card, as in the other Updraft sheets.
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 6), spacing: Space.sm) {
            ForEach(Self.symbols, id: \.self) { s in
                let selected = s == symbol
                Button {
                    withAnimation(.snappy(duration: 0.2)) { symbol = s }
                } label: {
                    Image(systemName: s)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? Theme.background : Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(selected ? Theme.textPrimary : Color.clear, in: .circle)
                        .overlay(Circle().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1))
                        .scaleEffect(selected ? 1.06 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            ZStack {
                Text(mode == .create ? "Continue" : mode == .importWallet ? "Import" : "Add")
                    .opacity(resolving ? 0 : 1)
                if resolving { ProgressView().tint(Theme.background) }
            }
            .font(Typo.headline)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.2), value: resolving)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(!canSubmit)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
    }

    private func submit() {
        guard canSubmit else { Haptics.error(); return }
        focused = false
        if mode == .watch { addWatch(); return }
        if mode == .create { creating = true; return }
        let account = Account(id: UUID().uuidString, name: trimmedName, symbol: symbol, holdings: [],
                              address: ImportWalletFields.address(secret, usesKey: usesKey))
        Haptics.success()
        onAdd(account)
        dismiss()
    }

    /// Resolves the address or ENS name and loads balances via the data layer.
    private func addWatch() {
        resolving = true
        watchError = nil
        Task {
            do {
                let account = try await Accounts.addWatch(address: WatchInput.trimmed(address), name: trimmedName)
                Haptics.success()
                onAdd(account)
                dismiss()
            } catch {
                resolving = false
                Haptics.error()
                withAnimation(.smooth(duration: 0.2)) {
                    watchError = (error as? LocalizedError)?.errorDescription ?? "Couldn't add this address. Try again."
                }
            }
        }
    }
}

/// Light validation for the watch field: a 0x address or an ENS name.
private enum WatchInput {
    static func trimmed(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Ethereum address: 0x plus 40 hex characters.
    static func isAddress(_ t: String) -> Bool {
        t.count == 42 && t.lowercased().hasPrefix("0x") && t.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// ENS name like vitalik.eth: dot-separated labels of letters, digits and hyphens.
    static func isENS(_ t: String) -> Bool {
        let lower = t.lowercased()
        guard lower.hasSuffix(".eth"), lower.count > 4 else { return false }
        let labels = lower.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }
    }

    static func isValid(_ raw: String) -> Bool { let t = trimmed(raw); return isAddress(t) || isENS(t) }

    static func short(_ raw: String) -> String {
        let t = trimmed(raw)
        return isENS(t) ? t.lowercased() : String(t.prefix(6)) + "…" + String(t.suffix(4))
    }

    static func hint(_ raw: String) -> String {
        let t = trimmed(raw)
        if t.isEmpty { return "Paste an Ethereum address (0x…) or an ENS name." }
        if isAddress(t) { return "Valid Ethereum address." }
        if isENS(t) { return "ENS name. We'll look up its address." }
        if t.lowercased().hasPrefix("0x") {
            let body = t.dropFirst(2)
            if !body.allSatisfy(\.isHexDigit) { return "Only 0–9 and a–f after 0x." }
            return "\(body.count) of 40 characters after 0x."
        }
        return "Use a 0x address or a name ending in .eth."
    }
}
