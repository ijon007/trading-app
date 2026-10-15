import SwiftUI
import Charts

/// Home header: total balance, change for the timeframe, an edge-to-edge
/// balance chart with scrubbing, and the timeframe switcher.
struct PortfolioHeader: View {
    @State private var timeframe: Timeframe = .day
    @State private var selectedDate: Date?

    private var points: [PricePoint] { SampleData.balanceSeries(timeframe) }
    private var startValue: Double { points.first?.price ?? SampleData.totalBalance }
    private var endValue: Double { points.last?.price ?? SampleData.totalBalance }

    private var selected: PricePoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    /// Value shown in the big number: the scrubbed point or the live total.
    private var shown: Double { selected?.price ?? endValue }
    private var delta: Double { shown - startValue }
    private var deltaPercent: Double { startValue > 0 ? delta / startValue * 100 : 0 }
    /// Line color follows the whole timeframe, not the scrub position.
    private var tint: Color { endValue >= startValue ? Theme.positive : Theme.negative }
    private var deltaTint: Color { delta >= 0 ? Theme.positive : Theme.negative }

    var body: some View {
        VStack(spacing: Space.md) {
            summary
            ZStack {
                chart
                    .id(timeframe) // fresh chart per timeframe: no marks interpolating between series
                    .transition(.opacity)
            }
            Picker("Timeframe", selection: $timeframe.animation(.easeInOut(duration: 0.2))) {
                ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Space.md)
        }
        .sensoryFeedback(.selection, trigger: timeframe)
        .sensoryFeedback(.selection, trigger: selected?.date) { _, new in new != nil }
        .onChange(of: timeframe) { selectedDate = nil }
    }

    // MARK: Summary

    private var summary: some View {
        VStack(spacing: Space.xs) {
            Text("Total balance")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            Text(shown.fiat)
                .heroNumeral()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: shown))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, Space.md)
            HStack(spacing: Space.xxs) {
                Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 9))
                Text((delta >= 0 ? "+" : "−") + abs(delta).fiat)
                    .contentTransition(.numericText(value: delta))
                Text("(\(deltaPercent.percent))")
                    .contentTransition(.numericText(value: deltaPercent))
                Group {
                    if let selected {
                        Text(selected.date, format: dateFormat)
                    } else {
                        Text(timeframe == .all ? "all time" : "past \(timeframe.rawValue)")
                    }
                }
                .foregroundStyle(Theme.textTertiary)
            }
            .font(Typo.figure)
            .foregroundStyle(deltaTint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        // Short and snappy so scrubbing keeps up with the finger.
        .animation(.snappy(duration: 0.18), value: shown)
        .accessibilityElement(children: .combine)
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
        let values = points.map(\.price)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.1, 1)
        let floor = lo - pad
        return Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date),
                         yStart: .value("Base", floor),
                         yEnd: .value("Balance", point.price))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date), y: .value("Balance", point.price))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(tint)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Theme.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", selected.date), y: .value("Balance", selected.price))
                    .foregroundStyle(tint)
                    .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: floor...(hi + pad))
        .chartPlotStyle { $0.padding(.zero) }
        .chartXSelection(value: $selectedDate)
        .frame(height: 180)
        .accessibilityLabel("Portfolio balance chart, \(timeframe.rawValue)")
    }
}
