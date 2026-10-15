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
    /// Listed coins with sample prices; live quotes override them in `assets`.
    static let baseAssets: [Asset] = [
        Asset(id: "BTC", name: "Bitcoin", price: 112_480.20, change24h: 1.84, marketCap: 2_230_000_000_000),
        Asset(id: "ETH", name: "Ethereum", price: 4_312.55, change24h: -0.92, marketCap: 520_000_000_000),
        Asset(id: "SOL", name: "Solana", price: 218.40, change24h: 4.31, marketCap: 104_000_000_000),
        Asset(id: "XRP", name: "XRP", price: 2.94, change24h: -2.15, marketCap: 168_000_000_000),
        Asset(id: "ADA", name: "Cardano", price: 0.88, change24h: 0.47, marketCap: 31_000_000_000),
        Asset(id: "AVAX", name: "Avalanche", price: 31.72, change24h: 6.02, marketCap: 13_000_000_000),
        Asset(id: "LINK", name: "Chainlink", price: 22.15, change24h: -1.38, marketCap: 14_500_000_000),
        Asset(id: "DOT", name: "Polkadot", price: 4.62, change24h: 2.71, marketCap: 7_000_000_000),
    ]

    /// Coins at live prices (Coinbase/CoinGecko) when available, sample otherwise.
    /// Reading this inside a view body subscribes it to price updates.
    static var assets: [Asset] {
        let market = MarketStore.shared
        let quotes = market.quotes
        var seen = Set<String>()
        var list: [Asset] = []
        // Top coins by market cap from CoinGecko, then any sample coin not in that list.
        for coin in market.catalog where seen.insert(coin.symbol).inserted {
            let base = baseAssets.first { $0.id == coin.symbol }
            let quote = quotes[coin.symbol]
            list.append(Asset(id: coin.symbol, name: base?.name ?? coin.name,
                              price: quote?.price ?? coin.price,
                              change24h: quote?.change24h ?? coin.change24h,
                              marketCap: quote?.marketCap ?? coin.marketCap))
        }
        for a in baseAssets where seen.insert(a.id).inserted {
            guard let q = quotes[a.id] else { list.append(a); continue }
            list.append(Asset(id: a.id, name: a.name, price: q.price, change24h: q.change24h, marketCap: q.marketCap ?? a.marketCap))
        }
        return list
    }

    /// Any coin by symbol; unknown symbols (e.g. a token before the catalog loads)
    /// get a zero-priced placeholder instead of crashing.
    static func asset(_ s: String) -> Asset {
        assets.first { $0.id == s } ?? baseAssets.first { $0.id == s }
            ?? Asset(id: s, name: s, price: 0, change24h: 0, marketCap: 0)
    }

    /// Holdings of the selected account; everything else derives from this.
    static var holdings: [Holding] { Account.current.liveHoldings }

    static var totalBalance: Double { holdings.reduce(0) { $0 + $1.value } }
    static var totalChange24h: Double {
        let prev = holdings.reduce(0) { $0 + $1.value / (1 + $1.asset.change24h / 100) }
        return prev > 0 ? (totalBalance - prev) / prev * 100 : 0
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
