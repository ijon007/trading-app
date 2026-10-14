import SwiftUI

struct HomeView: View {
    private let holdings = SampleData.holdings
    private let actions: [(String, String)] = [
        ("Buy", "plus"), ("Sell", "minus"), ("Swap", "arrow.left.arrow.right"),
        ("Send", "arrow.up"), ("Receive", "arrow.down"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Space.lg) {
                        balance
                        quickActions
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("Holdings") {
                    ForEach(holdings) { holding in
                        HoldingRow(holding: holding)
                            .contentShape(Rectangle())
                            .onTapGesture { Haptics.tap() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Home")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private var balance: some View {
        VStack(spacing: Space.xs) {
            Text("Total balance").eyebrow().foregroundStyle(Theme.textSecondary)
            Text(SampleData.totalBalance.fiat)
                .heroNumeral()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: Space.xxs) {
                ChangeText(value: SampleData.totalChange24h)
                Text("24h").font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: Space.md) {
            ForEach(actions, id: \.0) { title, icon in
                VStack(spacing: Space.xs) {
                    Button {
                        Haptics.tap() // light impact
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 30, height: 30)
                    }
                    .glassCircleButton()
                    .tint(Theme.textPrimary)
                    Text(title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

struct HoldingRow: View {
    let holding: Holding
    var body: some View {
        HStack(spacing: Space.sm) {
            CoinIcon(symbol: holding.asset.symbol)
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
        .padding(.vertical, Space.xxs)
    }
}
