import Foundation

extension SampleData {
    /// Portfolio value over a timeframe: each holding's amount times its price
    /// series, summed point by point. The last point equals `totalBalance`.
    static func balanceSeries(_ timeframe: Timeframe, now: Date = .now) -> [PricePoint] {
        let series = holdings.map { ($0.amount, $0.asset.series(timeframe, now: now)) }
        guard let dates = series.first?.1.map(\.date) else { return [] }
        return dates.indices.map { i in
            let value = series.reduce(0) { sum, item in
                i < item.1.count ? sum + item.0 * item.1[i].price : sum
            }
            return PricePoint(date: dates[i], price: value)
        }
    }
}
