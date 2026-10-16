import SwiftUI

/// What the user is about to send, handed to the review step.
struct SendDraft: Hashable {
    let asset: Asset
    let network: String
    let address: String
    let amount: Double  // asset units
    let fee: Double     // USD
    /// ENS name the address was resolved from, if any.
    var ensName: String? = nil
    /// First send to this address (shows a warning on review).
    var isNewRecipient = true
    var value: Double { amount * asset.price }
}

private struct TransferTarget: Identifiable { let id: String }

/// Addresses sent to before, so review can flag a new one.
enum SendRecipients {
    private static let key = "send.recipients.v1"
    static func isKnown(_ address: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(address.lowercased())
    }
    static func remember(_ address: String) {
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !list.contains(address.lowercased()) else { return }
        list.append(address.lowercased())
        UserDefaults.standard.set(list, forKey: key)
    }
}

/// Small "Sepolia test network" title, shown on the send screens.
struct TestNetworkTitle: View {
    let title: String
    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(Typo.headline).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 5, height: 5)
                Text("Sepolia test network")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Send drawer: asset, recipient, amount, fee, then review.
struct SendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var holding = SampleData.holdings.first ?? SampleData.allAssetsAsHoldings[0]
    @State private var network = (SampleData.holdings.first ?? SampleData.allAssetsAsHoldings[0]).asset.networks[0]
    @State private var address = ""
    @State private var amountText = ""
    @State private var inFiat = false
    @State private var review: SendDraft?
    /// "My accounts" pick: opens an internal transfer to that account.
    @State private var internalTo: String?
    /// Looking up an ENS recipient, and the last failure.
    @State private var resolving = false
    @State private var resolveError: String?
    @FocusState private var amountFocused: Bool

    private var asset: Asset { holding.asset }
    private var currency: Currency { .current }

    /// Typed number, accepting a comma or a dot.
    private var typed: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    /// Amount in asset units, whatever the input mode.
    private var amount: Double { inFiat ? typed / currency.rate / asset.price : typed }
    private var fee: Double { asset.networkFee(on: network) }

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isENS: Bool {
        let t = trimmedAddress.lowercased()
        return t.hasSuffix(".eth") && t.count > 4 && !t.contains(" ")
    }

    private enum Issue { case noAddress, badAddress, noAmount, insufficient }
    private var issue: Issue? {
        if amount > holding.amount + 1e-12 { return .insufficient }
        if trimmedAddress.isEmpty { return .noAddress }
        if !isENS, trimmedAddress.count < 26 { return .badAddress }
        if amount <= 0 { return .noAmount }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    VStack(spacing: Space.md) {
                        AssetPickerRow(holding: $holding)
                        if asset.networks.count > 1 {
                            Divider().overlay(Theme.hairline)
                            NetworkRow(networks: asset.networks, network: $network)
                        }
                    }
                    .transferCard()

                    recipient
                    amountEntry
                    feeRow
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) { reviewButton }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { TestNetworkTitle(title: "Send") }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(item: Binding(get: { internalTo.map(TransferTarget.init) }, set: { internalTo = $0?.id })) { target in
                InternalTransferSheet(fromID: Account.current.id, toID: target.id, symbol: asset.id) { dismiss() }
            }
            .navigationDestination(item: $review) { draft in
                SendReviewStep(draft: draft) { dismiss() }
            }
        }
        .onChange(of: holding) {
            network = holding.asset.networks[0]
            amountText = ""
        }
        .sensoryFeedback(.selection, trigger: holding)
        .sensoryFeedback(.selection, trigger: network)
        .sensoryFeedback(.selection, trigger: inFiat)
        .presentationDetents([.inset])
        .presentationDragIndicator(.visible)
    }

    // MARK: Recipient

    private var recipient: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("To").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .center, spacing: Space.xs) {
                TextField("0x… or name.eth", text: $address, axis: .vertical)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                if address.isEmpty {
                    PasteButton(payloadType: String.self) { strings in
                        address = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(Theme.surfaceHi)
                } else {
                    Button("Clear", systemImage: "xmark.circle.fill") { address = "" }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.textTertiary)
                }
                Button("Scan QR code", systemImage: "qrcode.viewfinder") { Haptics.tap() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .transferCard()
        .overlay(alignment: .bottomLeading) {
            if let resolveError {
                Text(resolveError)
                    .font(Typo.caption)
                    .foregroundStyle(Theme.negative)
                    .offset(y: 20)
                    .transition(.opacity)
            }
        }
        .onChange(of: address) { resolveError = nil }
        .safeAreaInset(edge: .bottom, spacing: Space.sm) { myAccounts }
        .animation(.smooth(duration: 0.2), value: resolveError)
    }

    /// Other accounts as quick recipients; picking one switches to a transfer.
    @ViewBuilder
    private var myAccounts: some View {
        let others = Account.all.filter { $0.id != Account.current.id }
        if !others.isEmpty, !Account.current.isWatchOnly {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("My accounts").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        ForEach(others) { a in
                            Button {
                                Haptics.tap()
                                internalTo = a.id
                            } label: {
                                HStack(spacing: Space.xs) {
                                    AccountAvatar(account: a, size: 22)
                                    Text(a.name).font(Typo.callout).foregroundStyle(Theme.textPrimary)
                                }
                                .padding(.leading, 4)
                                .padding(.trailing, Space.sm)
                                .padding(.vertical, 4)
                                .overlay(Capsule().strokeBorder(Theme.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, Space.xs)
        }
    }

    // MARK: Amount

    private var amountEntry: some View {
        VStack(spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {
                if inFiat, currency != .pln, currency != .chf {
                    Text(currency.symbol).foregroundStyle(Theme.textSecondary)
                }
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .fixedSize()
                    .foregroundStyle(issue == .insufficient ? Theme.negative : Theme.textPrimary)
                Text(inFiat ? (currency == .pln || currency == .chf ? currency.symbol : "") : asset.symbol)
                    .foregroundStyle(Theme.textSecondary)
            }
            // One font for prefix, number and suffix. Text fields don't honor
            // minimumScaleFactor, so long amounts step the shared size down instead.
            .font(amountFont)
            .tracking(Typo.numeralTracking)
            .lineLimit(1)
            .animation(.snappy(duration: 0.2), value: amountFont)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }

            Text(inFiat ? "≈ \(amount.units) \(asset.symbol)" : "≈ \((amount * asset.price).fiat)")
                .font(Typo.figure)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText(value: amount))
                .animation(.snappy(duration: 0.18), value: amount)

            HStack(spacing: Space.xs) {
                Button {
                    switchMode()
                } label: {
                    Label(inFiat ? asset.symbol : currency.rawValue, systemImage: "arrow.up.arrow.down")
                }
                Button("Max") {
                    Haptics.tap()
                    let max = inFiat ? holding.amount * asset.price * currency.rate : holding.amount
                    amountText = trimmed(max, digits: inFiat ? currency.fractionDigits : 6)
                }
            }
            .glassButton()
            .controlSize(.small)
            .tint(Theme.textPrimary)
            .font(Typo.caption)

            if let message {
                Text(message)
                    .font(Typo.callout)
                    .foregroundStyle(issue == .insufficient ? Theme.negative : Theme.textSecondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, Space.sm)
        .animation(.snappy, value: message)
    }

    private var amountFont: Font {
        let size: CGFloat = amountText.count > 12 ? 24 : amountText.count > 8 ? 28 : 34
        return .system(size: size, weight: .semibold).monospacedDigit()
    }

    private var message: String? {
        switch issue {
        case .insufficient: "Not enough \(asset.symbol). You have \(holding.amount.units)."
        case .badAddress: "That doesn't look like a full address."
        default: nil
        }
    }

    private func switchMode() {
        let current = amount
        inFiat.toggle()
        guard current > 0 else { return }
        amountText = inFiat
            ? trimmed(current * asset.price * currency.rate, digits: currency.fractionDigits)
            : trimmed(current, digits: 6)
    }

    private func trimmed(_ v: Double, digits: Int) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = digits
        f.usesGroupingSeparator = false
        f.decimalSeparator = "."
        return f.string(from: NSNumber(value: v)) ?? ""
    }

    // MARK: Fee + review

    private var feeRow: some View {
        HStack {
            Label("Network fee", systemImage: "fuelpump")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("~" + fee.fiat).font(Typo.figure).foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Space.xxs)
    }

    private var reviewButton: some View {
        Button {
            Haptics.tap()
            amountFocused = false
            startReview()
        } label: {
            ZStack {
                Text(issue == .noAddress ? "Enter an address" : issue == .noAmount ? "Enter an amount" : "Review")
                    .opacity(resolving ? 0 : 1)
                if resolving { ProgressView().tint(Theme.background) }
            }
            .font(Typo.headline)
            .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(issue != nil || resolving)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }

    /// Resolves an ENS recipient first, then opens review.
    private func startReview() {
        let input = trimmedAddress
        func open(_ resolved: String, ens: String?) {
            review = SendDraft(asset: asset, network: network, address: resolved, amount: amount, fee: fee,
                               ensName: ens, isNewRecipient: !SendRecipients.isKnown(resolved))
        }
        guard isENS else { open(input, ens: nil); return }
        resolving = true
        Task {
            do {
                let resolved = try await EthereumWatch.resolve(input)
                resolving = false
                open(resolved, ens: input.lowercased())
            } catch {
                resolving = false
                Haptics.error()
                resolveError = (error as? LocalizedError)?.errorDescription ?? "Couldn't look up that name."
            }
        }
    }
}
