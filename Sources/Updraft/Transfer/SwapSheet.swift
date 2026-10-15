import SwiftUI

/// What the user is about to swap, handed to the review step.
struct SwapDraft: Hashable {
    let from: Asset
    let to: Asset
    let amount: Double   // from units
    let output: Double   // to units, after fee
    let feeUSD: Double
    var rate: Double { from.price / to.price }
    var minReceived: Double { output * (1 - Swap.slippage) }
}

/// Sample swap terms.
enum Swap {
    static let feeRate = 0.003   // 0.3%
    static let slippage = 0.005  // 0.5%
}

/// Swap drawer: from coin + amount, flip, to coin with estimate, then review.
struct SwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var from = SampleData.holdings[0]
    @State private var to = SampleData.allAssetsAsHoldings.first { $0.asset.id == "ETH" } ?? SampleData.holdings[1]
    @State private var amountText = ""
    @State private var flipTurns = 0.0
    @State private var review: SwapDraft?
    @FocusState private var amountFocused: Bool

    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var rate: Double { from.asset.price / to.asset.price }
    private var output: Double { amount * rate * (1 - Swap.feeRate) }
    private var feeUSD: Double { amount * from.asset.price * Swap.feeRate }
    private var insufficient: Bool { amount > from.amount + 1e-12 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    ZStack {
                        VStack(spacing: Space.xs) {
                            fromCard
                            toCard
                        }
                        flipButton
                    }
                    details
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) { reviewButton }
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(item: $review) { draft in
                SwapReviewStep(draft: draft) { dismiss() }
            }
        }
        .onChange(of: from) { old, new in
            if new.id == to.id { to = holdingForTo(old.asset) }
        }
        .onChange(of: to) { old, new in
            if new.id == from.id, let h = SampleData.holdings.first(where: { $0.asset.id == old.asset.id }) { from = h }
        }
        .sensoryFeedback(.selection, trigger: from)
        .sensoryFeedback(.selection, trigger: to)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func holdingForTo(_ asset: Asset) -> Holding {
        SampleData.allAssetsAsHoldings.first { $0.asset.id == asset.id } ?? Holding(asset: asset, amount: 0)
    }

    /// Text-field value: dot decimal, no grouping, up to 6 decimals.
    private func plain(_ v: Double) -> String {
        let f = NumberFormatter()
        f.maximumFractionDigits = 6
        f.usesGroupingSeparator = false
        f.decimalSeparator = "."
        return f.string(from: NSNumber(value: v)) ?? ""
    }

    // MARK: Cards

    private var fromCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("From").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Max") {
                    Haptics.tap()
                    amountText = plain(from.amount)
                }
                .glassButton()
                .controlSize(.mini)
                .tint(Theme.textPrimary)
                .font(Typo.caption)
            }
            AssetPickerRow(holding: $from, title: "Swap from")
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                .tracking(Typo.numeralTracking)
                .foregroundStyle(insufficient ? Theme.negative : Theme.textPrimary)
            Text(insufficient ? "Not enough \(from.asset.symbol)" : (amount * from.asset.price).fiat)
                .font(Typo.figure)
                .foregroundStyle(insufficient ? Theme.negative : Theme.textSecondary)
                .contentTransition(.numericText(value: amount))
                .animation(.snappy(duration: 0.18), value: amount)
        }
        .transferCard()
    }

    private var toCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("To (estimated)").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            AssetPickerRow(holding: $to, options: SampleData.allAssetsAsHoldings, title: "Swap to")
            Text(output > 0 ? output.units : "0")
                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                .tracking(Typo.numeralTracking)
                .foregroundStyle(output > 0 ? Theme.textPrimary : Theme.textTertiary)
                .lineLimit(1)
                .contentTransition(.numericText(value: output))
                .animation(.snappy(duration: 0.18), value: output)
            Text((output * to.asset.price).fiat)
                .font(Typo.figure)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText(value: output))
                .animation(.snappy(duration: 0.18), value: output)
        }
        .transferCard()
    }

    private var flipButton: some View {
        Button {
            Haptics.tap()
            let newAmount = output
            withAnimation(.snappy) {
                flipTurns += 0.5
                let oldFrom = from
                from = SampleData.holdings.first { $0.asset.id == to.asset.id } ?? from
                to = holdingForTo(oldFrom.asset)
            }
            if from.asset.id != to.asset.id, newAmount > 0 { amountText = plain(newAmount) }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(flipTurns * 360))
        }
        .glassCircleButton()
        .tint(Theme.textPrimary)
        // Only a held coin can be the "from" side.
        .disabled(!SampleData.holdings.contains { $0.asset.id == to.asset.id })
        .accessibilityLabel("Switch coins")
    }

    // MARK: Details

    private var details: some View {
        VStack(spacing: Space.sm) {
            detailRow("Rate", "1 \(from.asset.symbol) = \(rate.units) \(to.asset.symbol)")
            detailRow("Fee", "0.3% · " + (feeUSD > 0 ? feeUSD.fiat : "—"))
            detailRow("Max slippage", "0.5%")
        }
        .padding(.horizontal, Space.xxs)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Typo.figure)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: value)
        }
    }

    private var reviewButton: some View {
        Button {
            Haptics.tap()
            amountFocused = false
            review = SwapDraft(from: from.asset, to: to.asset, amount: amount, output: output, feeUSD: feeUSD)
        } label: {
            Text(amount <= 0 ? "Enter an amount" : insufficient ? "Not enough \(from.asset.symbol)" : "Review")
                .font(Typo.headline)
                .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(amount <= 0 || insufficient || from.id == to.id)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}

/// Review, confirm and success for a swap. Private to Swap for now.
private struct SwapReviewStep: View {
    let draft: SwapDraft
    let onFinish: () -> Void

    private enum Phase { case review, swapping, done }
    @State private var phase: Phase = .review

    var body: some View {
        ZStack {
            if phase == .done {
                TradeResultView(
                    title: "Swapped",
                    message: "You got \(draft.output.units) \(draft.to.symbol) for \(draft.amount.units) \(draft.from.symbol)."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                summary.transition(.opacity)
            }
        }
        .animation(.snappy, value: phase)
        .navigationTitle(phase == .done ? "" : "Review swap")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase != .review)
        .interactiveDismissDisabled(phase == .swapping)
        .safeAreaInset(edge: .bottom) { button }
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                HStack(spacing: Space.md) {
                    side(draft.from, draft.amount, "You pay")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    side(draft.to, draft.output, "You get")
                }
                .padding(.top, Space.md)

                VStack(spacing: 0) {
                    row("Rate", "1 \(draft.from.symbol) = \(draft.rate.units) \(draft.to.symbol)")
                    row("Fee (0.3%)", draft.feeUSD.fiat)
                    row("Max slippage", "0.5%")
                    row("Minimum received", "\(draft.minReceived.units) \(draft.to.symbol)", divider: false)
                }
                .transferCard()

                Text("The final amount can change with the market, but you'll never get less than the minimum.")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private func side(_ asset: Asset, _ amount: Double, _ caption: String) -> some View {
        VStack(spacing: Space.xs) {
            CoinIcon(symbol: asset.symbol, size: 40)
            Text(caption).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            Text("\(amount.units) \(asset.symbol)")
                .font(Typo.headline.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text((amount * asset.price).fiat).font(Typo.figure).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ title: String, _ value: String, divider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value).font(Typo.figure).foregroundStyle(Theme.textPrimary)
            }
            .padding(.vertical, Space.row)
            if divider { Divider().overlay(Theme.hairline) }
        }
    }

    private var button: some View {
        Button {
            switch phase {
            case .review:
                Haptics.medium()
                phase = .swapping
                Task {
                    try? await Task.sleep(for: .seconds(1.1)) // sample round trip
                    Haptics.success()
                    phase = .done
                }
            case .swapping: break
            case .done: Haptics.tap(); onFinish()
            }
        } label: {
            ZStack {
                if phase == .swapping {
                    ProgressView().tint(Theme.background)
                } else {
                    Text(phase == .done ? "Done" : "Swap \(draft.from.symbol) to \(draft.to.symbol)").font(Typo.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(phase == .swapping)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}
