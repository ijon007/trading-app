import Foundation

struct Position: Sendable {
    let amount: Double
    let value: Double
    let averageCost: Double
    var costBasis: Double { amount * averageCost }
    var totalReturn: Double { value - costBasis }
    var totalReturnPercent: Double { costBasis > 0 ? totalReturn / costBasis * 100 : 0 }
    let portfolioShare: Double // 0...1
}

struct Transaction: Identifiable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case bought = "Bought", sold = "Sold", received = "Received", sent = "Sent", swapped = "Swapped"
        var symbol: String {
            switch self {
            case .bought: "plus"
            case .sold: "minus"
            case .received: "arrow.down"
            case .sent: "arrow.up"
            case .swapped: "arrow.left.arrow.right"
            }
        }
        /// Whether the amount adds to the holding.
        var isInflow: Bool { self == .bought || self == .received }
    }
    let id: Int
    let kind: Kind
    let date: Date
    let amount: Double
    let fiat: Double
}

private struct ActivityRandom {
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
    var holding: Holding? { SampleData.holdings.first { $0.asset.id == id } }

    var position: Position? {
        guard let holding else { return nil }
        var rng = ActivityRandom(symbol + "cost")
        let returnFactor = 0.7 + rng.next() * 0.7 // average cost 70%...140% of price basis
        return Position(
            amount: holding.amount,
            value: holding.value,
            averageCost: price / (2.1 - returnFactor),
            portfolioShare: holding.value / SampleData.totalBalance
        )
    }

    /// Deterministic sample history, newest first. Empty for coins not held.
    func transactions(now: Date = .now) -> [Transaction] {
        guard let holding else { return [] }
        var rng = ActivityRandom(symbol + "tx")
        let count = 5 + Int(rng.next() * 4)
        var daysAgo = 1.0 + rng.next() * 3
        return (0..<count).map { i in
            let kind: Transaction.Kind = i == count - 1 ? .bought : Transaction.Kind.allCases[Int(rng.next() * 5) % 5]
            let amount = holding.amount * (0.05 + rng.next() * 0.35)
            let pastPrice = price * (0.75 + rng.next() * 0.4)
            defer { daysAgo += 4 + rng.next() * 25 }
            return Transaction(id: i, kind: kind, date: now.addingTimeInterval(-daysAgo * 86_400),
                               amount: amount, fiat: amount * pastPrice)
        }
    }
}
