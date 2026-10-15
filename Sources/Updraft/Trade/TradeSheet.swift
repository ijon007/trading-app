import SwiftUI

enum TradeSide: String, CaseIterable, Identifiable, Hashable {
    case buy = "Buy", sell = "Sell"
    var id: String { rawValue }
}

/// A priced, validated order ready for review (mock, no backend).
struct TradeQuote: Hashable {
    let side: TradeSide
    let asset: Asset
    /// Amount entered, in USD (what you pay for Buy, what you sell for Sell).
    let grossUSD: Double
    let feeUSD: Double
    let feeNote: String
    let method: String
    let methodIcon: String

    var netUSD: Double { grossUSD - feeUSD }
    /// Coins received (Buy) or sold (Sell).
    var coin: Double { side == .buy ? netUSD / asset.price : grossUSD / asset.price }
}

extension Asset {
    /// Decimal places used when entering or showing this coin in trades.
    var tradeDigits: Int { price >= 1_000 ? 6 : price >= 1 ? 4 : 2 }
    func coinText(_ amount: Double) -> String {
        AmountInput.grouped(AmountInput.text(for: amount, maxFractionDigits: tradeDigits)) + " " + symbol
    }
}

enum TradeRules {
    static let minimumUSD: Double = 10
    static let limitUSD: Double = 25_000
    static let sellFeeRate: Double = 0.005

    static func percent(_ rate: Double) -> String {
        (rate * 100).formatted(.number.precision(.fractionLength(0...2))) + "%"
    }

    static func feeRate(for kind: PaymentMethod.Kind) -> Double {
        switch kind {
        case .applePay: 0
        case .card: 0.0149
        case .bank: 0.005
        }
    }
}

/// Buy or Sell sheet opened from the coin detail. Amount → Review → Done.
struct TradeSheet: View {
    let asset: Asset
    @State private var side: TradeSide
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Currency.storageKey) private var currencyCode = Currency.usd.rawValue

    @State private var text = "0"
    @State private var inCoin = false
    @State private var chip: String?
    @State private var shake = 0
    @State private var payments = PaymentStore()
    @State private var paymentID: UUID?
    @State private var quote: TradeQuote?
    @State private var methodsOpen = false

    init(asset: Asset, side: TradeSide) {
        self.asset = asset
        _side = State(initialValue: side)
    }

    private var currency: Currency { Currency(rawValue: currencyCode) ?? .usd }
    private var balance: Double { asset.position?.amount ?? 0 }
    private var value: Double { AmountInput.value(text) }
    private var usd: Double { inCoin ? value * asset.price : value / currency.rate }
    private var coin: Double { usd / asset.price }
    private var digits: Int { inCoin ? asset.tradeDigits : currency.fractionDigits }
    private var method: PaymentMethod? {
        payments.methods.first { $0.id == paymentID } ?? payments.methods.first
    }

    // MARK: Validation

    private enum Issue: Equatable { case empty, belowMinimum, noBalance, insufficient, overLimit }

    private var issue: Issue? {
        if side == .sell && balance <= 0 { return .noBalance }
        if value <= 0 { return .empty }
        if side == .sell && coin > balance * 1.000001 { return .insufficient }
        if side == .buy && usd > TradeRules.limitUSD { return .overLimit }
        if usd < TradeRules.minimumUSD - 0.000001 { return .belowMinimum }
        return nil
    }

    private var isBlockingError: Bool {
        issue == .insufficient || issue == .overLimit || issue == .noBalance
    }

    private var helper: String {
        switch issue {
        case .noBalance: "You don't own any \(asset.symbol) yet"
        case .insufficient: "Not enough \(asset.symbol). You have \(asset.coinText(balance))"
        case .overLimit: "The limit is \(TradeRules.limitUSD.fiat) per purchase"
        case .belowMinimum, .empty:
            side == .sell
                ? "\(asset.coinText(balance)) available"
                : "Minimum \(TradeRules.minimumUSD.fiat)"
        case nil:
            side == .sell ? "\(asset.coinText(balance)) available" : "1 \(asset.symbol) = \(asset.price.fiat)"
        }
    }

    // MARK: Display

    private func fiatString(_ raw: String) -> String {
        let g = AmountInput.grouped(raw)
        switch currency {
        case .chf: return "CHF " + g
        case .pln: return g + " zł"
        default: return currency.symbol + g
        }
    }

    private var primary: String {
        inCoin ? AmountInput.grouped(text) + " " + asset.symbol : fiatString(text)
    }

    private var secondary: String {
        inCoin ? "≈ " + usd.fiat : "≈ " + asset.coinText(coin)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.md) {
                Spacer(minLength: 0)
                AmountDisplay(amount: primary, value: value, secondary: secondary,
                              isError: isBlockingError, shake: shake) { swapUnit() }
                Text(helper)
                    .font(Typo.callout)
                    .foregroundStyle(isBlockingError ? Theme.negative : Theme.textSecondary)
                    .contentTransition(.opacity)
                    .animation(.smooth(duration: 0.2), value: helper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                AmountChips(chips: chips)
                if side == .buy { paymentRow } else { payoutRow }
                AmountKeypad(text: $text, maxFractionDigits: digits,
                             onChange: { chip = nil },
                             onReject: { shake += 1 })
                Button {
                    Haptics.tap()
                    quote = makeQuote()
                } label: {
                    Text(reviewTitle).font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
                }
                .glassProminentButton()
                .controlSize(.large)
                .disabled(issue != nil)
                .animation(.smooth(duration: 0.2), value: issue)
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.xs)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Side", selection: $side) {
                        ForEach(TradeSide.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $quote) { q in
                TradeReviewScreen(quote: q) { dismiss() }
            }
        }
        .sensoryFeedback(.selection, trigger: side)
        .sensoryFeedback(.warning, trigger: isBlockingError) { old, new in !old && new }
        .onChange(of: side) { methodsOpen = false; reset() }
        .onChange(of: isBlockingError) { _, new in if new { shake += 1 } }
        .onAppear { paymentID = paymentID ?? payments.defaultID }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var reviewTitle: String {
        side == .buy ? "Review purchase" : "Review sale"
    }

    // MARK: Chips

    private var chips: [AmountChip] {
        switch side {
        case .buy:
            let base: [Double] = currency.rate > 20 ? [5_000, 10_000, 25_000, 50_000] : [50, 100, 250, 500]
            return base.map { amount in
                let title = fiatString(AmountInput.text(for: amount, maxFractionDigits: 0))
                return AmountChip(id: title, title: title, isSelected: chip == title) {
                    setUSD(amount / currency.rate, chip: title)
                }
            }
        case .sell:
            return [(0.25, "25%"), (0.5, "50%"), (0.75, "75%"), (1, "Max")].map { share, title in
                AmountChip(id: title, title: title, isSelected: chip == title) {
                    setCoin(balance * share, chip: title)
                }
            }
        }
    }

    private func setUSD(_ amount: Double, chip id: String) {
        text = inCoin
            ? AmountInput.text(for: amount / asset.price, maxFractionDigits: asset.tradeDigits)
            : AmountInput.text(for: amount * currency.rate, maxFractionDigits: currency.fractionDigits)
        chip = id
    }

    private func setCoin(_ amount: Double, chip id: String) {
        text = inCoin
            ? AmountInput.text(for: amount, maxFractionDigits: asset.tradeDigits)
            : AmountInput.text(for: amount * asset.price * currency.rate, maxFractionDigits: currency.fractionDigits)
        chip = id
    }

    private func swapUnit() {
        let current = usd
        withAnimation(.snappy(duration: 0.2)) {
            inCoin.toggle()
            text = inCoin
                ? AmountInput.text(for: current / asset.price, maxFractionDigits: asset.tradeDigits)
                : AmountInput.text(for: current * currency.rate, maxFractionDigits: currency.fractionDigits)
        }
    }

    private func reset() {
        text = "0"
        chip = nil
    }

    // MARK: Method rows

    private var methodOptions: [DropdownOption<UUID>] {
        payments.methods.map { DropdownOption(id: $0.id, title: $0.title, subtitle: feeSubtitle($0), icon: $0.icon) }
    }

    private var paymentRow: some View {
        Dropdown(caption: "Pay with", options: methodOptions,
                 selection: Binding(get: { method?.id }, set: { paymentID = $0 }),
                 isOpen: $methodsOpen, placeholder: "Add a payment method")
    }

    private func feeSubtitle(_ m: PaymentMethod) -> String {
        let rate = TradeRules.feeRate(for: m.kind)
        let fee = rate == 0 ? "No fee" : TradeRules.percent(rate) + " fee"
        switch m.kind {
        case .bank: return fee + " · 1–2 business days"
        default: return fee + " · Instant"
        }
    }

    private var payoutRow: some View {
        OptionRowLabel(caption: "Deposit to", title: "Cash balance",
                       subtitle: TradeRules.percent(TradeRules.sellFeeRate) + " fee · Available instantly",
                       icon: "banknote")
            .padding(Space.sm)
            .surfaceCard(radius: Radius.md)
    }

    private func makeQuote() -> TradeQuote {
        switch side {
        case .buy:
            let m = method
            let rate = m.map { TradeRules.feeRate(for: $0.kind) } ?? 0
            return TradeQuote(side: .buy, asset: asset, grossUSD: usd, feeUSD: usd * rate,
                              feeNote: rate == 0 ? "No fee with Apple Pay" : TradeRules.percent(rate),
                              method: m?.title ?? "", methodIcon: m?.icon ?? "creditcard")
        case .sell:
            // "Max" sells the exact balance, never a rounded-up amount.
            let sold = min(coin, balance)
            let gross = sold * asset.price
            return TradeQuote(side: .sell, asset: asset, grossUSD: gross, feeUSD: gross * TradeRules.sellFeeRate,
                              feeNote: TradeRules.percent(TradeRules.sellFeeRate),
                              method: "Cash balance", methodIcon: "banknote")
        }
    }
}

// MARK: - Review

private struct TradeReviewScreen: View {
    let quote: TradeQuote
    let onDone: () -> Void

    private enum Phase: Equatable { case idle, authenticating, processing, done }
    @State private var phase: Phase = .idle
    @State private var alert: String?
    private let faceID = Biometrics.availability == .available

    private var buying: Bool { quote.side == .buy }

    var body: some View {
        ZStack {
            if phase == .done {
                VStack {
                    Spacer()
                    TradeResultView(
                        title: buying ? "Purchase complete" : "Sale complete",
                        message: buying
                            ? "\(quote.asset.coinText(quote.coin)) is now in your portfolio."
                            : "\(quote.netUSD.fiat) was added to your cash balance.")
                    Spacer()
                    Button {
                        Haptics.tap()
                        onDone()
                    } label: {
                        Text("Done").font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
                    }
                    .glassProminentButton()
                    .controlSize(.large)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                review.transition(.opacity)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
        .background(Theme.background)
        .navigationTitle(phase == .done ? "" : "Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase != .idle)
        .interactiveDismissDisabled(phase == .authenticating || phase == .processing)
        .animation(.smooth(duration: 0.35), value: phase)
        .alert("Couldn't confirm", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private var review: some View {
        VStack(spacing: Space.md) {
            ScrollView {
                TradeReview(rows: rows, total: total) {
                    VStack(spacing: Space.xs) {
                        CoinIcon(symbol: quote.asset.symbol, size: Space.xxl)
                        Text(buying ? "You get" : "You sell")
                            .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                        Text(quote.asset.coinText(quote.coin))
                            .numeral()
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.top, Space.lg)
                }
                Text("Crypto prices move quickly. Your order fills at the market price when you confirm.")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.md)
                    .padding(.horizontal, Space.md)
            }
            .scrollIndicators(.hidden)

            Button(action: confirm) {
                HStack(spacing: Space.xs) {
                    if phase == .processing {
                        ProgressView().tint(Theme.background)
                    } else if faceID {
                        Image(systemName: "faceid")
                    }
                    Text(confirmTitle)
                }
                .font(Typo.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xxs)
            }
            .glassProminentButton()
            .controlSize(.large)
            .disabled(phase != .idle)
        }
    }

    private var confirmTitle: String {
        switch phase {
        case .processing: buying ? "Buying" : "Selling"
        default: faceID ? "Confirm with Face ID" : (buying ? "Confirm purchase" : "Confirm sale")
        }
    }

    private var rows: [TradeReviewRow] {
        var r = [TradeReviewRow(title: "Price", value: rateText)]
        if buying {
            r.append(TradeReviewRow(title: "Purchase", value: quote.netUSD.fiat))
            r.append(TradeReviewRow(title: "Fee", value: quote.feeUSD.fiat, detail: quote.feeNote))
            r.append(TradeReviewRow(title: "Pay with", value: quote.method))
        } else {
            r.append(TradeReviewRow(title: "Sale value", value: quote.grossUSD.fiat))
            r.append(TradeReviewRow(title: "Fee", value: "−" + quote.feeUSD.fiat, detail: quote.feeNote))
            r.append(TradeReviewRow(title: "Deposit to", value: quote.method))
        }
        return r
    }

    private var total: TradeReviewRow {
        buying
            ? TradeReviewRow(title: "Total", value: quote.grossUSD.fiat)
            : TradeReviewRow(title: "You receive", value: quote.netUSD.fiat)
    }

    private var rateText: String { "1 \(quote.asset.symbol) = \(quote.asset.price.fiat)" }

    private func confirm() {
        Haptics.tap()
        Task {
            if faceID {
                phase = .authenticating
                let reason = buying ? "Confirm your \(quote.asset.symbol) purchase." : "Confirm your \(quote.asset.symbol) sale."
                switch await Biometrics.authenticate(reason: reason) {
                case .success: break
                case .cancelled: phase = .idle; return
                case .failed(let m): phase = .idle; Haptics.error(); alert = m; return
                }
            }
            phase = .processing
            try? await Task.sleep(for: .seconds(1.1))
            Haptics.success()
            phase = .done
        }
    }
}
