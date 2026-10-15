import Foundation

struct Asset: Identifiable, Hashable, Sendable {
    let id: String          // symbol
    let name: String
    let price: Double
    let change24h: Double   // percent
    let marketCap: Double
    var symbol: String { id }
}

struct Holding: Identifiable, Hashable, Sendable {
    let asset: Asset
    let amount: Double
    var id: String { asset.id }
    var value: Double { amount * asset.price }
}

enum SampleData {
    static let assets: [Asset] = [
        Asset(id: "BTC", name: "Bitcoin", price: 112_480.20, change24h: 1.84, marketCap: 2_230_000_000_000),
        Asset(id: "ETH", name: "Ethereum", price: 4_312.55, change24h: -0.92, marketCap: 520_000_000_000),
        Asset(id: "SOL", name: "Solana", price: 218.40, change24h: 4.31, marketCap: 104_000_000_000),
        Asset(id: "XRP", name: "XRP", price: 2.94, change24h: -2.15, marketCap: 168_000_000_000),
        Asset(id: "ADA", name: "Cardano", price: 0.88, change24h: 0.47, marketCap: 31_000_000_000),
        Asset(id: "AVAX", name: "Avalanche", price: 31.72, change24h: 6.02, marketCap: 13_000_000_000),
        Asset(id: "LINK", name: "Chainlink", price: 22.15, change24h: -1.38, marketCap: 14_500_000_000),
        Asset(id: "DOT", name: "Polkadot", price: 4.62, change24h: 2.71, marketCap: 7_000_000_000),
    ]

    static func asset(_ s: String) -> Asset { assets.first { $0.id == s }! }

    static let holdings: [Holding] = [
        Holding(asset: asset("BTC"), amount: 0.4821),
        Holding(asset: asset("ETH"), amount: 6.25),
        Holding(asset: asset("SOL"), amount: 84.0),
        Holding(asset: asset("LINK"), amount: 310.0),
        Holding(asset: asset("ADA"), amount: 4_200.0),
    ]

    static var totalBalance: Double { holdings.reduce(0) { $0 + $1.value } }
    static var totalChange24h: Double {
        let prev = holdings.reduce(0) { $0 + $1.value / (1 + $1.asset.change24h / 100) }
        return (totalBalance - prev) / prev * 100
    }

    /// Name from onboarding, falling back to the sample user.
    static var profile: (name: String, handle: String) {
        let saved = UserDefaults.standard.string(forKey: "onboarding.name") ?? ""
        let name = saved.isEmpty ? "Jon" : saved
        let handle = "@" + name.lowercased().replacingOccurrences(of: " ", with: "")
        return (name, handle)
    }
}

extension Double {
    /// USD amount shown in the selected display currency.
    var fiat: String { Currency.current.format(self) }
    var compactFiat: String { Currency.current.format(self, compact: true) }
    var percent: String { (self >= 0 ? "+" : "") + formatted(.number.precision(.fractionLength(2))) + "%" }
}
