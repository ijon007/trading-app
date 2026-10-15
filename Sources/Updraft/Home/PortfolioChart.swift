import SwiftUI
import Charts

/// Home header: total balance, change for the timeframe, an edge-to-edge
/// balance chart with scrubbing, and the timeframe switcher.
///
/// Performance: the series is cached, the drag position lives inside
/// `ScrubbableChart`, and this view only hears about it when the nearest
/// point index changes, so a drag doesn't rebuild the header on every tick.
struct PortfolioHeader: View {
    @State private var timeframe: Timeframe = .hour
    @State private var selectedIndex: Int?
    /// Read so the header follows the selected account.
    @AppStorage(Account.storageKey) private var accountID = Account.all[0].id

    private var points: [PricePoint] { SampleData.balanceSeries(timeframe) }

    var body: some View {
        let points = points
        let start = points.first?.price ?? SampleData.totalBalance
        let end = points.last?.price ?? SampleData.totalBalance
        let selected = selectedIndex.flatMap { points.indices.contains($0) ? points[$0] : nil }
        let tint = end >= start ? Theme.positive : Theme.negative
        // An empty account has no history: show 0 without a chart or timeframes.
        let isEmpty = SampleData.holdings.isEmpty

        VStack(spacing: Space.md) {
            BalanceSummary(value: isEmpty ? 0 : selected?.price ?? end, start: isEmpty ? 0 : start,
                           date: selected?.date, timeframe: timeframe, showsChange: !isEmpty)
            if !isEmpty {
            // Stable identity: an .id(timeframe) swap inside this List row made the
            // cell reload (whole header flashed) on the first scrub after a switch.
            // Drop the animation instead so marks don't interpolate between series.
            Group {
                if points.isEmpty {
                    ChartLoadingPlaceholder()
                } else {
                    ScrubbableChart(points: points, tint: tint, selectedIndex: $selectedIndex)
                        .transaction(value: timeframe) { $0.animation = nil }
                }
            }
            .frame(height: 180)
            Picker("Timeframe", selection: $timeframe.animation(.easeInOut(duration: 0.2))) {
                ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Space.md)
            }
        }
        .sensoryFeedback(.selection, trigger: timeframe)
        .sensoryFeedback(.selection, trigger: selectedIndex) { _, new in new != nil }
        .onChange(of: timeframe) { selectedIndex = nil }
        .onChange(of: accountID) { selectedIndex = nil }
    }
}

/// Big balance number and the change line; rolls digits on index changes only.
private struct BalanceSummary: View {
    let value: Double
    let start: Double
    let date: Date?
    let timeframe: Timeframe
    var showsChange = true

    var body: some View {
        let delta = value - start
        let percent = start > 0 ? delta / start * 100 : 0
        VStack(spacing: Space.xs) {
            HStack(spacing: Space.xxs) {
                Text("Total balance")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    // Debug: long-press to replay onboarding.
                    .contextMenu {
                        Button("Replay onboarding", systemImage: "arrow.counterclockwise") { OnboardingAnswers.reset() }
                    }
                PrivacyEyeButton()
            }
            Text(value.fiat)
                .heroNumeral()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: value))
                .privateAmount()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, Space.md)
            if showsChange {
            HStack(spacing: Space.xxs) {
                Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 9))
                Text((delta >= 0 ? "+" : "−") + abs(delta).fiat)
                    .contentTransition(.numericText(value: delta))
                    .privateAmount()
                Text("(\(percent.percent))")
                    .contentTransition(.numericText(value: percent))
                Group {
                    if let date {
                        Text(date, format: dateFormat)
                    } else {
                        Text(timeframe == .all ? "all time" : "past \(timeframe.rawValue)")
                    }
                }
                .foregroundStyle(Theme.textTertiary)
            }
            .font(Typo.figure)
            .foregroundStyle(delta >= 0 ? Theme.positive : Theme.negative)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            }
        }
        // Short and snappy so scrubbing keeps up with the finger.
        .animation(.snappy(duration: 0.15), value: value)
        .accessibilityElement(children: .combine)
    }

    private var dateFormat: Date.FormatStyle {
        switch timeframe {
        case .hour, .day: .dateTime.hour().minute()
        case .week, .month: .dateTime.month(.abbreviated).day().hour()
        case .year, .all: .dateTime.month(.abbreviated).day().year()
        }
    }
}

/// Owns the raw drag position. The heavy plot is an Equatable view that only
/// redraws when the data or color changes; the indicator is a light overlay.
private struct ScrubbableChart: View {
    let points: [PricePoint]
    let tint: Color
    @Binding var selectedIndex: Int?
    @State private var selectedDate: Date?

    var body: some View {
        let values = points.map(\.price)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.1, 1)
        let domain = (lo - pad)...(hi + pad)

        PortfolioPlot(points: points, tint: tint, domain: domain, selection: $selectedDate)
            .equatable()
            .overlay {
                if let i = selectedIndex, points.indices.contains(i) {
                    ScrubIndicator(index: i, count: points.count, value: points[i].price,
                                   domain: domain, tint: tint)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: selectedDate) { _, date in
                let index = date.map(nearestIndex)
                if index != selectedIndex { selectedIndex = index }
            }
    }

    /// Points are evenly spaced in time, so the nearest index is O(1).
    private func nearestIndex(_ date: Date) -> Int {
        guard let first = points.first?.date, let last = points.last?.date, points.count > 1 else { return 0 }
        let t = date.timeIntervalSince(first) / last.timeIntervalSince(first)
        return min(max(Int((t * Double(points.count - 1)).rounded()), 0), points.count - 1)
    }
}

/// Line + gradient area. Skipped on re-render unless points/color/domain change.
private struct PortfolioPlot: View, Equatable {
    let points: [PricePoint]
    let tint: Color
    let domain: ClosedRange<Double>
    @Binding var selection: Date?

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.points == b.points && a.tint == b.tint && a.domain == b.domain
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Date", point.date),
                     yStart: .value("Base", domain.lowerBound),
                     yEnd: .value("Balance", point.price))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Date", point.date), y: .value("Balance", point.price))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(tint)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: domain)
        .chartPlotStyle { $0.padding(.zero) }
        .chartXSelection(value: $selection)
        .accessibilityLabel("Portfolio balance chart")
    }
}

/// Vertical rule and dot at the selected point, positioned by index.
private struct ScrubIndicator: View {
    let index: Int
    let count: Int
    let value: Double
    let domain: ClosedRange<Double>
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let x = count > 1 ? geo.size.width * CGFloat(index) / CGFloat(count - 1) : 0
            let span = domain.upperBound - domain.lowerBound
            let y = geo.size.height * (1 - CGFloat((value - domain.lowerBound) / (span > 0 ? span : 1)))
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.textTertiary)
                    .frame(width: 1, height: geo.size.height)
                    .offset(x: x - 0.5)
                Circle()
                    .fill(tint)
                    .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                    .frame(width: 10, height: 10)
                    .offset(x: x - 5, y: y - 5)
            }
        }
    }
}
