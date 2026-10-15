import SwiftUI

/// The P&L numbers a share card shows for one position over a timeframe.
struct PnLSummary {
    let amount: Double
    let percent: Double
    let label: String
    let values: [Double]

    init(asset: Asset, position: Position, timeframe: Timeframe) {
        if timeframe == .all {
            amount = position.totalReturn
            percent = position.totalReturnPercent
            label = "All time"
        } else {
            let pct = asset.change(over: timeframe)
            percent = pct
            amount = position.value * pct / (100 + pct)
            label = "Past \(timeframe.rawValue)"
        }
        values = asset.series(timeframe).map(\.price)
    }
}

/// Clean, shareable P&L card. Fixed size so the rendered image is consistent.
/// Its color scheme comes from the environment, so the caller picks light or dark.
struct PnLCard: View {
    let asset: Asset
    let summary: PnLSummary
    var hideAmounts = false

    static let size = CGSize(width: 340, height: 300)

    var body: some View {
        let up = summary.percent >= 0
        let tint = up ? Theme.positive : Theme.negative
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                CoinIcon(symbol: asset.symbol, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(summary.label).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Label("Updraft", systemImage: "wind")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(hideAmounts ? summary.percent.percent : signed(summary.amount))
                    .numeral()
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !hideAmounts {
                    HStack(spacing: Space.xxs) {
                        Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(tint)
                        Text(summary.percent.percent)
                            .font(Typo.figure)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            Sparkline(values: summary.values)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(maxHeight: .infinity)
            Text(asset.symbol + " position")
                .font(Typo.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Space.lg)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func signed(_ v: Double) -> String { (v >= 0 ? "+" : "−") + abs(v).fiat }
}
