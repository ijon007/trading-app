import SwiftUI

/// Add an account (a wallet): create a new one, or import one from a recovery
/// phrase or private key. Import is a UI mock with light validation only.
struct AddAccountSheet: View {
    /// Called with the new account; the caller appends and selects it.
    let onAdd: (Account) -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case create = "Create new", importWallet = "Import"
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
    @FocusState private var focused: Bool
    /// Content height (plus nav bar and button insets), so the sheet opens fitted.
    @State private var fittedHeight: CGFloat = 520
    @State private var detent: PresentationDetent = .height(520)

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var secretKind: SecretKind { SecretKind(secret) }
    private var canSubmit: Bool {
        !trimmedName.isEmpty && (mode == .create || secretKind.isValid)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Picker("Type", selection: $mode.animation(.smooth(duration: 0.3))) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    field("Name") {
                        TextField("Account name", text: $name)
                            .font(Typo.body)
                            .foregroundStyle(Theme.textPrimary)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(Space.md)
                            .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                    }

                    field("Icon") {
                        symbolGrid
                            .padding(Space.md)
                            .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                    }

                    if mode == .importWallet {
                        field("Recovery phrase or private key") {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                TextField("Paste it here", text: $secret, axis: .vertical)
                                    .font(Typo.body.monospaced())
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(3...6)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focused)
                                    .padding(Space.md)
                                    .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                                Label(secretKind.message, systemImage: secretKind.isValid ? "checkmark.circle.fill" : "info.circle")
                                    .font(Typo.caption)
                                    .foregroundStyle(secretKind.isValid ? Theme.positive : Theme.textSecondary)
                                    .contentTransition(.interpolate)
                                    .animation(.smooth(duration: 0.2), value: secretKind.isValid)
                            }
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
            .sensoryFeedback(.selection, trigger: mode)
            .sensoryFeedback(.selection, trigger: symbol)
        }
        .presentationDetents([.height(fittedHeight), .large], selection: $detent)
        .presentationDragIndicator(.visible)
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
            Text(mode == .create ? "Create" : "Import")
                .font(Typo.headline)
                .frame(maxWidth: .infinity)
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
        let account = Account(id: UUID().uuidString, name: trimmedName, symbol: symbol, holdings: [])
        Haptics.success()
        onAdd(account)
        dismiss()
    }
}

/// Light, offline validation for the import mock.
private enum SecretKind {
    case empty, phrase(Int), privateKey, invalid

    init(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty { self = .empty; return }
        let hex = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        if hex.count == 64, hex.allSatisfy(\.isHexDigit) { self = .privateKey; return }
        let words = text.split(whereSeparator: \.isWhitespace)
        if words.allSatisfy({ $0.allSatisfy(\.isLetter) }) {
            self = .phrase(words.count)
        } else {
            self = .invalid
        }
    }

    var isValid: Bool {
        switch self {
        case .privateKey: true
        case .phrase(let n): [12, 15, 18, 21, 24].contains(n)
        default: false
        }
    }

    var message: String {
        switch self {
        case .empty: "Paste a 12 or 24 word phrase, or a 64 character private key."
        case .privateKey: "Private key looks good."
        case .phrase(let n) where isValid: "\(n) word recovery phrase looks good."
        case .phrase(let n): "\(n) word\(n == 1 ? "" : "s"). Recovery phrases have 12 or 24 words."
        case .invalid: "That doesn't look like a recovery phrase or private key."
        }
    }
}
