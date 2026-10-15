import SwiftUI
import Charts

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
                HStack(spacing: Space.xxs) {
                    UpdraftLogoShape()
                        .frame(width: 12, height: 16)
                    Text("Updraft").font(Typo.caption)
                }
                .foregroundStyle(Theme.textTertiary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Updraft")
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
            PnLChart(values: summary.values, tint: tint)
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

/// The Updraft mark: two rising, softly cornered bands, traced from the app icon
/// (Resources/AppIcon.png) without its square, so it tints with the foreground style.
struct UpdraftLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Source geometry, in app-icon pixels: the mark spans x 292...732, y 215...808.
        let minX: CGFloat = 292, minY: CGFloat = 215, w: CGFloat = 440, h: CGFloat = 593
        let s = min(rect.width / w, rect.height / h)
        let ox = rect.midX - w * s / 2, oy = rect.midY - h * s / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + (x - minX) * s, y: oy + (y - minY) * s) }

        var path = Path()
        for dy: CGFloat in [0, 215] {
            path.move(to: p(292, 593 + dy))
            path.addLine(to: p(292, 490 + dy))
            path.addQuadCurve(to: p(345, 416 + dy), control: p(292, 443 + dy))
            path.addLine(to: p(732, 215 + dy))
            path.addLine(to: p(732, 318 + dy))
            path.addQuadCurve(to: p(679, 392 + dy), control: p(732, 364 + dy))
            path.closeSubpath()
        }
        return path
    }
}

/// Mini chart with the same line and soft gradient area as the Home and coin charts.
private struct PnLChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = (hi - lo) * 0.08
        Chart(Array(values.enumerated()), id: \.offset) { i, value in
            AreaMark(x: .value("Index", i),
                     yStart: .value("Base", lo - pad),
                     yEnd: .value("Value", value))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Index", i), y: .value("Value", value))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(tint)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartPlotStyle { $0.padding(.zero) }
    }
}
