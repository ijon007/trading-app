import SwiftUI

/// What the user is about to send, handed to the review step.
struct SendDraft: Hashable {
    let asset: Asset
    let network: String
    let address: String
    let amount: Double  // asset units
    let fee: Double     // USD
    var value: Double { amount * asset.price }
}

/// Send drawer: asset, recipient, amount, fee, then review.
struct SendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var holding = SampleData.holdings[0]
    @State private var network = SampleData.holdings[0].asset.networks[0]
    @State private var address = ""
    @State private var amountText = ""
    @State private var inFiat = false
    @State private var review: SendDraft?
    @FocusState private var amountFocused: Bool

    private var asset: Asset { holding.asset }
    private var currency: Currency { .current }

    /// Typed number, accepting a comma or a dot.
    private var typed: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    /// Amount in asset units, whatever the input mode.
    private var amount: Double { inFiat ? typed / currency.rate / asset.price : typed }
    private var fee: Double { asset.networkFee(on: network) }

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    private enum Issue { case noAddress, badAddress, noAmount, insufficient }
    private var issue: Issue? {
        if amount > holding.amount + 1e-12 { return .insufficient }
        if trimmedAddress.isEmpty { return .noAddress }
        if trimmedAddress.count < 26 { return .badAddress }
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
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { reviewButton }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Recipient

    private var recipient: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("To").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .center, spacing: Space.xs) {
                TextField("\(asset.symbol) address", text: $address, axis: .vertical)
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
            review = SendDraft(asset: asset, network: network, address: trimmedAddress, amount: amount, fee: fee)
        } label: {
            Text(issue == .noAddress ? "Enter an address" : issue == .noAmount ? "Enter an amount" : "Review")
                .font(Typo.headline)
                .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(issue != nil)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}
