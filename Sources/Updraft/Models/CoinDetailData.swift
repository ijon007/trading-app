import Foundation

enum Timeframe: String, CaseIterable, Identifiable, Sendable {
    case day = "1D", week = "1W", month = "1M", year = "1Y", all = "All"
    var id: String { rawValue }

    var span: TimeInterval {
        switch self {
        case .day: 86_400
        case .week: 7 * 86_400
        case .month: 30 * 86_400
        case .year: 365 * 86_400
        case .all: 5 * 365 * 86_400
        }
    }

    var pointCount: Int {
        switch self {
        case .day: 96
        case .week: 84
        case .month: 90
        case .year: 120
        case .all: 150
        }
    }
}

struct PricePoint: Identifiable, Hashable, Sendable {
    let date: Date
    let price: Double
    var id: Date { date }
}

struct MarketInfo: Sendable {
    let marketCap: Double
    let volume24h: Double
    let circulatingSupply: Double
    let allTimeHigh: Double
    let rank: Int
}

/// Seeded generator so every coin always draws the same sample data.
private struct SeededRandom {
    private var state: UInt64
    init(_ text: String) {
        state = text.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

extension Asset {
    /// Percent change over a timeframe; 1D matches `change24h`.
    func change(over timeframe: Timeframe) -> Double {
        guard timeframe != .day else { return change24h }
        var rng = SeededRandom(symbol + timeframe.rawValue + "chg")
        let scale: Double = switch timeframe {
        case .week: 9
        case .month: 22
        case .year: 80
        default: 240
        }
        let bias = timeframe == .all ? 0.75 : 0.35
        return (rng.next() - 0.5 + bias) * scale
    }

    /// Deterministic random walk ending at the current price.
    func series(_ timeframe: Timeframe, now: Date = .now) -> [PricePoint] {
        var rng = SeededRandom(symbol + timeframe.rawValue)
        let n = timeframe.pointCount
        var walk = [0.0]
        for _ in 1..<n { walk.append(walk[walk.count - 1] + (rng.next() - 0.5)) }
        let startPrice = price / (1 + change(over: timeframe) / 100)
        let first = walk[0], last = walk[n - 1]
        let lo = walk.min() ?? 0, hi = walk.max() ?? 1
        let wiggle = abs(price - startPrice) * 0.6 + price * 0.01
        return walk.enumerated().map { i, v in
            let t = Double(i) / Double(n - 1)
            let trend = startPrice + (price - startPrice) * t
            let noise = ((v - first) - (last - first) * t) / max(hi - lo, 0.001) * wiggle
            let date = now.addingTimeInterval(-timeframe.span * (1 - t))
            return PricePoint(date: date, price: max(trend + noise, price * 0.02))
        }
    }

    var marketInfo: MarketInfo {
        var rng = SeededRandom(symbol + "info")
        let rank = (SampleData.assets.sorted { $0.marketCap > $1.marketCap }.firstIndex(of: self) ?? 0) + 1
        return MarketInfo(
            marketCap: marketCap,
            volume24h: marketCap * (0.02 + rng.next() * 0.06),
            circulatingSupply: marketCap / price,
            allTimeHigh: price * (1.05 + rng.next() * 0.9),
            rank: rank
        )
    }
}
