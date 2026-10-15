import Foundation

/// An account is a wallet: its own name, balance and holdings.
struct Account: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// SF Symbol used for the account's avatar.
    let symbol: String
    let holdings: [Holding]

    var totalBalance: Double { holdings.reduce(0) { $0 + $1.value } }
}

extension Account {
    /// UserDefaults key for the selected account id.
    static let storageKey = "account.current"

    /// Sample accounts. "Main" keeps the original sample portfolio.
    static let all: [Account] = [
        Account(id: "main", name: "Main", symbol: "person.fill", holdings: [
            Holding(asset: SampleData.asset("BTC"), amount: 0.4821),
            Holding(asset: SampleData.asset("ETH"), amount: 6.25),
            Holding(asset: SampleData.asset("SOL"), amount: 84.0),
            Holding(asset: SampleData.asset("LINK"), amount: 310.0),
            Holding(asset: SampleData.asset("ADA"), amount: 4_200.0),
        ]),
        Account(id: "savings", name: "Savings", symbol: "building.columns.fill", holdings: [
            Holding(asset: SampleData.asset("BTC"), amount: 0.215),
            Holding(asset: SampleData.asset("ETH"), amount: 3.1),
        ]),
        Account(id: "trading", name: "Trading", symbol: "bolt.fill", holdings: [
            Holding(asset: SampleData.asset("SOL"), amount: 142.0),
            Holding(asset: SampleData.asset("AVAX"), amount: 420.0),
            Holding(asset: SampleData.asset("DOT"), amount: 1_250.0),
            Holding(asset: SampleData.asset("XRP"), amount: 2_600.0),
            Holding(asset: SampleData.asset("LINK"), amount: 95.0),
        ]),
    ]

    /// The account the app is showing, falling back to Main.
    static var current: Account {
        let id = UserDefaults.standard.string(forKey: storageKey)
        return all.first { $0.id == id } ?? all[0]
    }
}
