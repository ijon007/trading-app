import SwiftUI

/// Move coins between my own accounts: from / to, coin, amount with Max,
/// review, hold to confirm, done. Balances update locally on both accounts.
struct InternalTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fromID: String
    @State private var toID: String
    @State private var holding: Holding
    @State private var amountText = ""
    @State private var phase: Phase = .edit
    @FocusState private var amountFocused: Bool
    /// Called after a completed transfer (e.g. to close a parent Send sheet).
    var onFinish: (() -> Void)? = nil

    private enum Phase { case edit, review, done }

    init(fromID: String? = nil, toID: String? = nil, symbol: String? = nil, onFinish: (() -> Void)? = nil) {
        let sources = Account.all.filter { !$0.isWatchOnly }
        let from = sources.first { $0.id == (fromID ?? Account.current.id) } ?? sources.first ?? Account.all[0]
        let to = Account.all.first { $0.id == toID && $0.id != from.id } ?? Account.all.first { $0.id != from.id } ?? from
        let held = from.liveHoldings
        _fromID = State(initialValue: from.id)
        _toID = State(initialValue: to.id)
        _holding = State(initialValue: held.first { $0.asset.id == symbol } ?? held.first
                         ?? SampleData.allAssetsAsHoldings[0])
        self.onFinish = onFinish
    }

    private var from: Account? { Account.all.first { $0.id == fromID } }
    private var to: Account? { Account.all.first { $0.id == toID } }
    private var sourceHoldings: [Holding] { from?.liveHoldings ?? [] }
    private var available: Double { sourceHoldings.first { $0.asset.id == holding.asset.id }?.amount ?? 0 }
    private var amount: Double { Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var tooMuch: Bool { amount > available + 1e-12 }
    private var canReview: Bool { amount > 0 && !tooMuch && fromID != toID }

    var body: some View {
        NavigationStack {
            ZStack {
                switch phase {
                case .edit: editor.transition(.opacity.combined(with: .offset(x: -16)))
                case .review: review.transition(.opacity.combined(with: .offset(x: 16)))
                case .done: done.transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.smooth(duration: 0.3), value: phase)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background)
            .navigationTitle(phase == .done ? "" : "Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase == .review {
                        Button("Back", systemImage: "chevron.left") { phase = .edit }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if phase != .done { Button("Close", systemImage: "xmark") { dismiss() } }
                }
            }
            .safeAreaInset(edge: .bottom) { bottom }
        }
        .onChange(of: fromID) {
            if toID == fromID { toID = Account.all.first { $0.id != fromID }?.id ?? toID }
            holding = sourceHoldings.first { $0.asset.id == holding.asset.id } ?? sourceHoldings.first ?? holding
            amountText = ""
        }
        .onChange(of: holding) { amountText = "" }
        .sensoryFeedback(.selection, trigger: fromID)
        .sensoryFeedback(.selection, trigger: toID)
        .presentationDetents([.inset])
        .presentationDragIndicator(.visible)
    }

    // MARK: Edit

    private var editor: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: 0) {
                    accountRow("From", selection: $fromID, options: Account.all.filter { !$0.isWatchOnly })
                    Divider().overlay(Theme.hairline).padding(.vertical, Space.sm)
                    accountRow("To", selection: $toID, options: Account.all.filter { $0.id != fromID })
                }
                .transferCard()

                AssetPickerRow(holding: $holding, options: sourceHoldings)
                    .transferCard()

                VStack(spacing: Space.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .fixedSize()
                            .foregroundStyle(tooMuch ? Theme.negative : Theme.textPrimary)
                        Text(holding.asset.symbol).foregroundStyle(Theme.textSecondary)
                    }
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    .tracking(Typo.numeralTracking)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { amountFocused = true }
                    Text("≈ " + (amount * holding.asset.price).fiat)
                        .font(Typo.figure)
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText(value: amount))
                        .animation(.snappy(duration: 0.18), value: amount)
                    Button("Max") {
                        Haptics.tap()
                        amountText = available.formatted(.number.precision(.fractionLength(0...6)).grouping(.never)
                            .locale(Locale(identifier: "en_US_POSIX")))
                    }
                    .glassButton()
                    .controlSize(.small)
                    .tint(Theme.textPrimary)
                    .font(Typo.caption)
                    Text(tooMuch ? "Not enough \(holding.asset.symbol). You have \(available.units)."
                                 : "Available \(available.units) \(holding.asset.symbol)")
                        .font(Typo.callout)
                        .foregroundStyle(tooMuch ? Theme.negative : Theme.textSecondary)
                        .privateAmount()
                }
                .padding(.vertical, Space.sm)
            }
            .padding(Space.md)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func accountRow(_ label: String, selection: Binding<String>, options: [Account]) -> some View {
        let current = Account.all.first { $0.id == selection.wrappedValue }
        return Menu {
            ForEach(options) { a in
                Button { selection.wrappedValue = a.id } label: {
                    Text(a.name)
                    Image(systemName: a.id == selection.wrappedValue ? "checkmark" : a.symbol)
                }
            }
        } label: {
            HStack(spacing: Space.sm) {
                Text(label).font(Typo.callout).foregroundStyle(Theme.textSecondary).frame(width: 44, alignment: .leading)
                if let current { AccountAvatar(account: current, size: 30) }
                Text(current?.name ?? "Choose").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Review + done

    private var review: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.xs) {
                    CoinIcon(symbol: holding.asset.symbol, size: 44)
                    Text("\(amount.units) \(holding.asset.symbol)").numeral().foregroundStyle(Theme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text((amount * holding.asset.price).fiat).font(Typo.figure).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, Space.md)
                VStack(spacing: 0) {
                    line("From", from?.name ?? "")
                    Divider().overlay(Theme.hairline)
                    line("To", to?.name ?? "")
                    Divider().overlay(Theme.hairline)
                    line("Network fee", "Free between your accounts")
                }
                .transferCard()
            }
            .padding(.horizontal, Space.md)
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(Typo.figure).foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, Space.row)
    }

    private var done: some View {
        VStack(spacing: Space.md) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: phase == .done)
            Text("Transferred").titleStyle().foregroundStyle(Theme.textPrimary)
            Text("\(amount.units) \(holding.asset.symbol) moved from \(from?.name ?? "") to \(to?.name ?? "").")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var bottom: some View {
        Group {
            switch phase {
            case .edit:
                Button {
                    Haptics.tap()
                    amountFocused = false
                    phase = .review
                } label: {
                    Text(amount <= 0 ? "Enter an amount" : "Review").font(Typo.headline).frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                .disabled(!canReview)
            case .review:
                HoldToConfirm(title: "Hold to transfer") {
                    if Account.transfer(from: fromID, to: toID, symbol: holding.asset.id, amount: amount) {
                        Haptics.success()
                        phase = .done
                    } else {
                        Haptics.error()
                        phase = .edit
                    }
                }
            case .done:
                Button {
                    Haptics.tap()
                    dismiss()
                    onFinish?()
                } label: { Text("Done").font(Typo.headline).frame(maxWidth: .infinity) }
                .glassProminentButton()
                .controlSize(.large)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}
