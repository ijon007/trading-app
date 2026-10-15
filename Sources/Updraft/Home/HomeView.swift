import SwiftUI

struct HomeView: View {
    @State private var selected: Asset?
    @State private var transfer: TransferKind?
    /// Read so the screen redraws in the new currency.
    @AppStorage(Currency.storageKey) private var currency = Currency.usd.rawValue
    private let holdings = SampleData.holdings
    private let actions: [(title: String, icon: String)] = [
        ("Swap", "arrow.left.arrow.right"), ("Send", "arrow.up"), ("Receive", "arrow.down"),
    ]

    var body: some View {
        NavigationStack {
            List {
                VStack(spacing: Space.lg) {
                    balance
                    quickActions
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                Section {
                    ForEach(holdings) { holding in
                        HoldingRow(holding: holding)
                            .contentShape(Rectangle())
                            .onTapGesture { Haptics.tap(); selected = holding.asset }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Theme.hairline)
                            .listRowInsets(EdgeInsets(top: Space.row, leading: Space.md, bottom: Space.row, trailing: Space.md))
                    }
                } header: {
                    Text("Holdings")
                        .font(Typo.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .listStyle(.plain)
            .id(currency) // rows hold plain values; rebuild them on currency change
            .scrollContentBackground(.hidden)
            .sheet(item: $selected) { CoinDetailSheet(asset: $0) }
            .sheet(item: $transfer) { kind in
                switch kind {
                case .send: SendSheet()
                case .receive: ReceiveSheet()
                case .swap: SwapSheet()
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var balance: some View {
        VStack(spacing: Space.sm) {
            Text("Total balance")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            Text(SampleData.totalBalance.fiat)
                .heroNumeral()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, Space.md)
            ChangePill(value: SampleData.totalChange24h)
        }
    }

    private var quickActions: some View {
        HStack(spacing: Space.xl) {
            ForEach(actions, id: \.title) { action in
                VStack(spacing: Space.xs) {
                    Button {
                        Haptics.tap() // light impact
                        switch action.title {
                        case "Send": transfer = .send
                        case "Receive": transfer = .receive
                        case "Swap": transfer = .swap
                        default: break
                        }
                    } label: {
                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .glassCircleButton()
                    .tint(Theme.textPrimary)
                    .accessibilityLabel(action.title)
                    Text(action.title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

struct HoldingRow: View {
    let holding: Holding
    var body: some View {
        HStack(spacing: Space.sm) {
            CoinIcon(symbol: holding.asset.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text("\(holding.amount.formatted(.number.precision(.fractionLength(0...4)))) \(holding.asset.symbol)")
                    .font(Typo.figure).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.value.fiat).font(Typo.figure).foregroundStyle(Theme.textPrimary)
                ChangeText(value: holding.asset.change24h)
            }
        }
    }
}
