import SwiftUI

/// Minimal line chart for a series of values, normalized to its frame.
struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let lo = values.min(), let hi = values.max() else { return path }
        let span = max(hi - lo, .ulpOfOne)
        for (i, v) in values.enumerated() {
            let p = CGPoint(x: rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1),
                            y: rect.maxY - rect.height * CGFloat((v - lo) / span))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        return path
    }
}

extension Asset {
    /// Deterministic 24h sample series that ends in the direction of `change24h`.
    var sparkline: [Double] {
        // Real 7 day prices from CoinGecko, thinned to ~42 points.
        if let real = MarketStore.shared.catalogCoin(symbol)?.sparkline, real.count > 8 {
            let step = max(1, real.count / 42)
            return stride(from: 0, to: real.count, by: step).map { real[$0] } + [real[real.count - 1]]
        }
        var seed = symbol.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) }
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max) - 0.5
        }
        let count = 24
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return t * change24h + next() * max(abs(change24h), 1) * 0.6
        }
    }
}
