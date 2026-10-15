import SwiftUI

/// Import entry: a recovery phrase typed or pasted as word chips (checked
/// against the BIP-39 list), or a private key. Validation via `Wallet.service`.
struct ImportWalletFields: View {
    @Binding var secret: String
    @Binding var usesKey: Bool
    var focused: FocusState<Bool>.Binding

    @State private var showKey = false
    /// Phrase entry: finished words as chips, plus the word being typed.
    @State private var committed: [String] = []
    @State private var draft = ""

    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
    }

    static func isValid(_ secret: String, usesKey: Bool) -> Bool {
        usesKey ? Wallet.service.isValidPrivateKey(secret) : Wallet.service.isValidPhrase(words(secret))
    }

    /// The address the secret imports, once valid.
    static func address(_ secret: String, usesKey: Bool) -> String? {
        guard isValid(secret, usesKey: usesKey) else { return nil }
        return usesKey ? Wallet.service.address(forPrivateKey: secret) : Wallet.service.address(forPhrase: words(secret))
    }

    private var words: [String] { Self.words(secret) }

    /// Space, comma or return finishes a word; a pasted phrase splits into chips.
    private func absorb(_ text: String) {
        guard text.contains(where: { $0.isWhitespace || $0 == "," }) else { sync(); return }
        let parts = Self.words(text)
        let finished = text.last.map { $0.isWhitespace || $0 == "," } ?? false
        withAnimation(.snappy(duration: 0.2)) { committed += finished ? parts : Array(parts.dropLast()) }
        draft = finished ? "" : (parts.last ?? "")
        sync()
    }

    private func remove(_ index: Int) {
        Haptics.tap()
        withAnimation(.snappy(duration: 0.2)) { _ = committed.remove(at: index) }
        sync()
    }

    private func sync() {
        secret = (committed + Self.words(draft)).joined(separator: " ")
    }
    private var invalidCount: Int { words.filter { !Wallet.service.isValidWord($0) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Picker("Import with", selection: $usesKey.animation(.smooth(duration: 0.25))) {
                Text("Recovery phrase").tag(false)
                Text("Private key").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: usesKey) { secret = ""; committed = []; draft = "" }

            if usesKey { keyField } else { phraseField }

            Label(message, systemImage: Self.isValid(secret, usesKey: usesKey) ? "checkmark.circle.fill" : "info.circle")
                .font(Typo.caption)
                .foregroundStyle(tone)
                .contentTransition(.interpolate)
                .animation(.smooth(duration: 0.2), value: message)
        }
        .sensoryFeedback(.selection, trigger: usesKey)
    }

    private var phraseField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if !committed.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.xs)], alignment: .leading, spacing: Space.xs) {
                    ForEach(Array(committed.enumerated()), id: \.offset) { i, word in
                        Button { remove(i) } label: { chip(i, word) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Removes this word")
                    }
                }
            }
            HStack(alignment: .top, spacing: Space.xs) {
                TextField(committed.isEmpty ? "Type or paste 12 words" : "Word \(committed.count + 1)", text: $draft)
                    .font(Typo.body.monospaced())
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.next)
                    .focused(focused)
                    .onChange(of: draft) { _, new in absorb(new) }
                    .onSubmit { absorb(draft + " "); focused.wrappedValue = true }
                if secret.isEmpty {
                    PasteButton(payloadType: String.self) { strings in
                        let text = strings.first ?? ""
                        Task { @MainActor in absorb(text + " ") }
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(Theme.textPrimary)
                } else {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy(duration: 0.2)) { committed = [] }
                        draft = ""
                        secret = ""
                    }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(Space.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
    }

    private func chip(_ index: Int, _ word: String) -> some View {
        let valid = Wallet.service.isValidWord(word)
        return HStack(spacing: Space.xxs) {
            Text("\(index + 1)").font(Typo.caption).monospacedDigit().foregroundStyle(Theme.textTertiary)
            Text(word)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(valid ? Theme.textPrimary : Theme.negative)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceHi.opacity(valid ? 1 : 0.5), in: .capsule)
        .overlay(Capsule().strokeBorder(valid ? Color.clear : Theme.negative.opacity(0.6)))
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var keyField: some View {
        HStack(spacing: Space.xs) {
            Group {
                if showKey {
                    TextField("64 hex characters", text: $secret)
                } else {
                    SecureField("64 hex characters", text: $secret)
                }
            }
            .font(Typo.body.monospaced())
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused(focused)
            Button(showKey ? "Hide" : "Show", systemImage: showKey ? "eye.slash" : "eye") { showKey.toggle() }
                .labelStyle(.iconOnly)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(Space.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
    }

    private var message: String {
        if usesKey {
            if secret.isEmpty { return "Paste a 64 character private key." }
            return Wallet.service.isValidPrivateKey(secret) ? "Private key looks good." : "A private key is 64 hex characters (0–9, a–f)."
        }
        let n = words.count
        if n == 0 { return "Enter your 12 or 24 word recovery phrase." }
        if invalidCount > 0 { return "\(invalidCount) word\(invalidCount == 1 ? " isn't" : "s aren't") on the recovery word list." }
        if [12, 24].contains(n) { return "\(n) word recovery phrase looks good." }
        return "\(n) of 12 words."
    }

    private var tone: Color {
        if Self.isValid(secret, usesKey: usesKey) { return Theme.positive }
        if !usesKey, invalidCount > 0 { return Theme.negative }
        return Theme.textSecondary
    }
}
