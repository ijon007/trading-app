import Foundation

extension SampleData {
    /// Portfolio value over a timeframe: each holding's sample amount times its
    /// real price history (Coinbase candles), summed point by point and aligned
    /// on the newest candles. Empty while any coin's history is still loading.
    static func balanceSeries(_ timeframe: Timeframe) -> [PricePoint] {
        balanceSeries(timeframe, holdings: holdings)
    }

    /// Same, for any set of holdings (e.g. only public accounts).
    static func balanceSeries(_ timeframe: Timeframe, holdings: [Holding]) -> [PricePoint] {
        let series = holdings.map { ($0.amount, $0.asset.series(timeframe)) }
        guard !series.isEmpty, series.allSatisfy({ !$0.1.isEmpty }),
              let count = series.map(\.1.count).min() else { return [] }
        let dates = series[0].1.suffix(count).map(\.date)
        return (0..<count).map { i in
            let value = series.reduce(0) { sum, item in sum + item.0 * item.1[item.1.count - count + i].price }
            return PricePoint(date: dates[i], price: value)
        }
    }
}
