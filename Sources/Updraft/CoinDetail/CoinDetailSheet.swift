import SwiftUI
import Charts

/// Coin detail presented as a native glass sheet.
struct CoinDetailSheet: View {
    let asset: Asset
    @State private var timeframe: Timeframe = .day
    @State private var selectedDate: Date?

    private var points: [PricePoint] { asset.series(timeframe) }
    private var change: Double { asset.change(over: timeframe) }
    private var tint: Color { change >= 0 ? Theme.positive : Theme.negative }

    private var selected: PricePoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                // A fresh chart per timeframe, crossfaded, so marks never interpolate
                // between series with different point counts and x-domains.
                ZStack {
                    chart
                        .id(timeframe)
                        .transition(.opacity)
                }
                Picker("Timeframe", selection: $timeframe.animation(.easeInOut(duration: 0.2))) {
                    ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if let position = asset.position {
                    positionCard(position)
                }
                marketInfo
                history
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.md)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { actions }
        .sensoryFeedback(.selection, trigger: timeframe)
        .onChange(of: timeframe) { selectedDate = nil }
        .sensoryFeedback(.selection, trigger: selected?.date) { _, new in new != nil }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                CoinIcon(symbol: asset.symbol, size: 28)
                Text(asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(asset.symbol).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            Text((selected?.price ?? asset.price).fiat)
                .numeral()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Group {
                if let selected {
                    Text(selected.date, format: dateFormat)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    HStack(spacing: Space.xxs) {
                        Text(change.percent).foregroundStyle(tint)
                        Text(timeframe == .all ? "all time" : "past \(timeframe.rawValue)")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .font(Typo.figure)
            .frame(height: 20, alignment: .leading)
        }
    }

    private var dateFormat: Date.FormatStyle {
        switch timeframe {
        case .day: .dateTime.hour().minute()
        case .week, .month: .dateTime.month(.abbreviated).day().hour()
        case .year, .all: .dateTime.month(.abbreviated).day().year()
        }
    }

    // MARK: Chart

    private var chart: some View {
        let prices = points.map(\.price)
        let lo = prices.min() ?? 0, hi = prices.max() ?? 1
        let pad = (hi - lo) * 0.08
        return Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Price", point.price))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(tint)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Theme.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", selected.date), y: .value("Price", selected.price))
                    .foregroundStyle(tint)
                    .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXSelection(value: $selectedDate)
        .frame(height: 220)
        .accessibilityLabel("\(asset.name) price chart, \(timeframe.rawValue)")
    }

    // MARK: Position

    private func positionCard(_ p: Position) -> some View {
        let tint = p.totalReturn >= 0 ? Theme.positive : Theme.negative
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your position").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(p.amount.formatted(.number.precision(.fractionLength(0...4)))) \(asset.symbol)")
                    .font(Typo.figure).foregroundStyle(Theme.textSecondary)
            }
            Text(p.value.fiat)
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
                .tracking(-0.6)
                .foregroundStyle(Theme.textPrimary)
            Grid(alignment: .leading, horizontalSpacing: Space.lg, verticalSpacing: Space.sm) {
                GridRow {
                    stat("Average cost", p.averageCost.fiat)
                    stat("Portfolio", p.portfolioShare.formatted(.percent.precision(.fractionLength(1))))
                }
                GridRow {
                    stat("Total return", (p.totalReturn >= 0 ? "+" : "−") + abs(p.totalReturn).fiat, tint: tint)
                    stat("Return", p.totalReturnPercent.percent, tint: tint)
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: String, _ value: String, tint: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(Typo.figure).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // MARK: Market info

    private var marketInfo: some View {
        let info = asset.marketInfo
        return VStack(alignment: .leading, spacing: 0) {
            Text("Market info")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, Space.xs)
            infoRow("Market cap", info.marketCap.compactFiat)
            infoRow("24h volume", info.volume24h.compactFiat)
            infoRow("Circulating supply", "\(info.circulatingSupply.formatted(.number.notation(.compactName).precision(.fractionLength(0...2)))) \(asset.symbol)")
            infoRow("All-time high", info.allTimeHigh.fiat)
            infoRow("Rank", "#\(info.rank)", divider: false)
        }
    }

    private func infoRow(_ title: String, _ value: String, divider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value).font(Typo.figure).foregroundStyle(Theme.textPrimary)
            }
            .padding(.vertical, Space.row)
            if divider { Divider().overlay(Theme.hairline) }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: History

    private var history: some View {
        let items = asset.transactions()
        return VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, Space.xs)
            if items.isEmpty {
                VStack(spacing: Space.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No activity yet").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xl)
            } else {
                ForEach(items) { tx in
                    transactionRow(tx, divider: tx.id != items.last?.id)
                }
            }
        }
    }

    private func transactionRow(_ tx: Transaction, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Image(systemName: tx.kind.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceHi, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.kind.rawValue).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(tx.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tx.kind.isInflow ? "+" : "−")\(tx.amount.formatted(.number.precision(.fractionLength(0...4)))) \(asset.symbol)")
                        .font(Typo.figure)
                        .foregroundStyle(tx.kind.isInflow ? Theme.positive : Theme.textPrimary)
                    Text(tx.fiat.fiat).font(Typo.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, Space.row)
            if divider { Divider().overlay(Theme.hairline) }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: Space.sm) {
            Button {
                Haptics.tap()
            } label: {
                Text("Sell").font(Typo.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(Theme.textPrimary)

            Button {
                Haptics.tap()
            } label: {
                Text("Buy").font(Typo.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
        }
        .controlSize(.large)
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.xs)
    }
}

extension Double {
    var compactFiat: String {
        formatted(.currency(code: "USD").notation(.compactName).precision(.fractionLength(0...2)))
    }
}
