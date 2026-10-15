import SwiftUI
import Charts

/// Coin detail presented as a native glass sheet.
struct CoinDetailSheet: View {
    private let seed: Asset
    /// Live view of the coin (price and 24h change follow the market).
    private var asset: Asset { SampleData.assets.first { $0.id == seed.id } ?? seed }
    init(asset: Asset) { seed = asset }
    @State private var timeframe: Timeframe = .hour
    @State private var selectedDate: Date?
    @State private var trade: TradeSide?
    @State private var sharingPnL = false
    /// Read so the screen redraws in the new currency.
    @AppStorage(Currency.storageKey) private var currency = Currency.usd.rawValue

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
        .id(currency)
        .safeAreaInset(edge: .bottom) { actions }
        .sensoryFeedback(.selection, trigger: timeframe)
        .onChange(of: timeframe) { selectedDate = nil }
        .sensoryFeedback(.selection, trigger: selected?.date) { _, new in new != nil }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $trade) { TradeSheet(asset: asset, side: $0) }
        .sheet(isPresented: $sharingPnL) {
            if let position = asset.position { PnLShareSheet(asset: asset, position: position) }
        }
    }

    // MARK: Header

    private var displayedPrice: Double { selected?.price ?? asset.price }

    private var starButton: some View {
        let starred = Watchlist.shared.contains(asset.id)
        return Button {
            Haptics.tap()
            withAnimation(.snappy) { Watchlist.shared.toggle(asset.id) }
        } label: {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(starred ? Color.yellow : Theme.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: starred)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(starred ? "Remove from watchlist" : "Add to watchlist")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                CoinIcon(symbol: asset.symbol, size: 28)
                Text(asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(asset.symbol).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                Spacer()
                starButton
            }
            Text(displayedPrice.fiat)
                .numeral()
                .foregroundStyle(Theme.textPrimary)
                // Digits roll up or down with the value; kept short so scrubbing stays responsive.
                .contentTransition(.numericText(value: displayedPrice))
                .animation(.snappy(duration: 0.18), value: displayedPrice)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Group {
                if let selected {
                    Text(selected.date, format: dateFormat)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    HStack(spacing: Space.xxs) {
                        Text(change.percent)
                            .foregroundStyle(tint)
                            .contentTransition(.numericText(value: change))
                            .animation(.snappy, value: change)
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
        case .hour, .day: .dateTime.hour().minute()
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
                // Same soft fill as the Home balance chart, in the timeframe's color.
                AreaMark(x: .value("Date", point.date),
                         yStart: .value("Base", lo - pad),
                         yEnd: .value("Price", point.price))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
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
        .overlay { if points.isEmpty { ChartLoadingPlaceholder().padding(.horizontal, -Space.md) } }
        .frame(height: 220)
        .accessibilityLabel("\(asset.name) price chart, \(timeframe.rawValue)")
    }

    // MARK: Position

    private func positionCard(_ p: Position) -> some View {
        let up = p.totalReturn >= 0
        let tint = up ? Theme.positive : Theme.negative
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                CoinIcon(symbol: asset.symbol, size: 22)
                Text(asset.symbol).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Theme.positive).frame(width: 6, height: 6)
                    Text("Open").font(Typo.caption).foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.surfaceHi, in: .capsule)
                Button {
                    Haptics.tap()
                    sharingPnL = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(Typo.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.leading, Space.xxs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share P&L")
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(p.value.fiat)
                        .privateAmount()
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                        .tracking(-0.6)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("\(p.amount.formatted(.number.precision(.fractionLength(0...5)))) \(asset.symbol)")
                        .font(Typo.figure).foregroundStyle(Theme.textSecondary).privateAmount()
                }
                Spacer(minLength: Space.sm)
                VStack(alignment: .trailing, spacing: Space.xxs) {
                    Text(signed(p.totalReturn))
                        .privateAmount()
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                        .tracking(-0.6)
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                    HStack(spacing: 4) {
                        Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(tint)
                        Text(p.totalReturnPercent.percent)
                            .font(Typo.figure).foregroundStyle(Theme.textPrimary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            DashedLine()
                .stroke(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .frame(height: 1)
            VStack(spacing: Space.xs) {
                positionRow("Today's return", signed(p.todayReturn), tint: p.todayReturn >= 0 ? Theme.positive : Theme.negative)
                positionRow("Amount invested", p.costBasis.fiat)
                positionRow("Realized", signed(p.realized), tint: p.realized >= 0 ? Theme.positive : Theme.negative)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func signed(_ v: Double) -> String { (v >= 0 ? "+" : "−") + abs(v).fiat }

    private func positionRow(_ title: String, _ value: String, tint: Color = Theme.textPrimary) -> some View {
        HStack {
            Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(Typo.figure).foregroundStyle(tint).contentTransition(.numericText()).privateAmount()
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
            infoRow("Market cap", info.marketCapText)
            infoRow("24h volume", info.volumeText)
            infoRow("Circulating supply", info.supplyText(info.circulatingSupply, symbol: asset.symbol))
            infoRow("Max supply", info.supplyText(info.maxSupply, symbol: asset.symbol))
            infoRow("All-time high", info.allTimeHighText)
            infoRow("Rank", info.rankText, divider: false)
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
                trade = .sell
            } label: {
                Text("Sell").font(Typo.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(Theme.textPrimary)

            Button {
                Haptics.tap()
                trade = .buy
            } label: {
                Text("Buy").font(Typo.headline).foregroundStyle(Theme.background).frame(maxWidth: .infinity)
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

/// A horizontal line path, used for the dashed divider.
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}
