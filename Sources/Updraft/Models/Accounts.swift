import Foundation
import Observation

/// An account is a wallet: its own name, balance and holdings.
/// Owned accounts hold sample amounts; watch accounts track a real Ethereum address.
struct Account: Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case owned, watch }

    let id: String
    var name: String
    /// SF Symbol used for the account's avatar.
    var symbol: String
    var holdings: [Holding]
    /// Watch-only accounts track a real address and can't send or swap.
    var isWatchOnly: Bool = false
    /// Ethereum address for watch accounts.
    var address: String? = nil
    /// Avatar color key (see `AccountPalette`); nil keeps the monochrome look.
    var color: String? = nil
    /// Emoji avatar; replaces the symbol when set.
    var emoji: String? = nil

    var kind: Kind { isWatchOnly ? .watch : .owned }
    var isWatch: Bool { isWatchOnly }

    /// Amounts valued at live prices.
    var liveHoldings: [Holding] { holdings.map { Holding(asset: SampleData.asset($0.asset.id), amount: $0.amount) } }

    var totalBalance: Double { liveHoldings.reduce(0) { $0 + $1.value } }
}

/// Observable home for the account list, so views redraw when accounts are
/// added or watch balances refresh. Persists everything except the built-in samples.
@Observable
final class AccountStore: @unchecked Sendable {
    static let shared = AccountStore()

    var accounts: [Account] {
        didSet { save() }
    }

    /// v1 held only created accounts; v2 holds the whole ordered list (renamed,
    /// reordered and removed samples included).
    private static let legacyKey = "accounts.saved.v1"
    private static let fileKey = "accounts.saved.v2"

    private init() {
        accounts = Self.load() ?? (Account.samples + (Self.load(key: Self.legacyKey) ?? []))
        if accounts.isEmpty { accounts = Account.samples }
        // Reopen on the last selected account once saved ones are loaded;
        // a stale id (e.g. a removed account) falls back to the default.
        let key = Account.storageKey
        if let id = UserDefaults.standard.string(forKey: key), !accounts.contains(where: { $0.id == id }) {
            UserDefaults.standard.set(Account.defaultID(in: accounts), forKey: key)
        }
    }

    // MARK: Persistence

    private struct Stored: Codable {
        struct Amount: Codable { let symbol: String; let amount: Double }
        let id: String
        let name: String
        let symbol: String
        let kind: Account.Kind
        let address: String?
        let holdings: [Amount]
        var color: String?
        var emoji: String?
    }

    private func save() {
        let stored = accounts.map { a in
            Stored(id: a.id, name: a.name, symbol: a.symbol, kind: a.kind, address: a.address,
                   holdings: a.holdings.map { .init(symbol: $0.asset.id, amount: $0.amount) },
                   color: a.color, emoji: a.emoji)
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.fileKey)
        }
    }

    private static func load(key: String = fileKey) -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return nil }
        return stored.map { s in
            Account(id: s.id, name: s.name, symbol: s.symbol,
                    holdings: s.holdings.map { Holding(asset: SampleData.asset($0.symbol), amount: $0.amount) },
                    isWatchOnly: s.kind == .watch, address: s.address, color: s.color, emoji: s.emoji)
        }
    }
}

extension Account {
    /// UserDefaults key for the selected account id.
    static let storageKey = "account.current"

    /// All accounts (built-in samples, then created and watch accounts). Persisted.
    static var all: [Account] {
        get { AccountStore.shared.accounts }
        set { AccountStore.shared.accounts = newValue }
    }

    /// Built-in sample accounts. "Main" keeps the original sample portfolio.
    static let samples: [Account] = [
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

    /// The account the app is showing, falling back to the default.
    static var current: Account {
        let id = UserDefaults.standard.string(forKey: storageKey)
        return all.first { $0.id == id } ?? all.first { $0.id == defaultID } ?? all[0]
    }

    // MARK: Management

    /// UserDefaults key for the default account (used when the last one is gone).
    static let defaultKey = "account.default"

    static func defaultID(in list: [Account]) -> String {
        let id = UserDefaults.standard.string(forKey: defaultKey)
        return list.first { $0.id == id }?.id ?? list[0].id
    }

    static var defaultID: String { defaultID(in: all) }
    var isDefault: Bool { id == Account.defaultID }

    static func setDefault(_ id: String) { UserDefaults.standard.set(id, forKey: defaultKey) }

    /// Replaces an account's editable fields (name, avatar).
    static func update(_ account: Account) {
        guard let i = all.firstIndex(where: { $0.id == account.id }) else { return }
        all[i] = account
    }

    static func move(fromOffsets: IndexSet, toOffset: Int) {
        var list = all
        list.move(fromOffsets: fromOffsets, toOffset: toOffset)
        all = list
    }

    /// Removes an account. The last one can't go. If it was selected, the app
    /// switches to the default; if it was the default, the first becomes default.
    @discardableResult
    static func remove(_ id: String) -> Bool {
        guard all.count > 1, let i = all.firstIndex(where: { $0.id == id }) else { return false }
        let wasDefault = all[i].isDefault
        all.remove(at: i)
        Wallet.service.deletePhrase(for: id)
        if wasDefault { setDefault(all[0].id) }
        if UserDefaults.standard.string(forKey: storageKey) == id {
            UserDefaults.standard.set(defaultID, forKey: storageKey)
        }
        return true
    }

    /// Moves an amount of one coin between two of my accounts (sample balances).
    /// Watch-only accounts can't be the source.
    @discardableResult
    static func transfer(from: String, to: String, symbol: String, amount: Double) -> Bool {
        guard from != to, amount > 0,
              let f = all.firstIndex(where: { $0.id == from }), !all[f].isWatchOnly,
              let t = all.firstIndex(where: { $0.id == to }),
              let h = all[f].holdings.firstIndex(where: { $0.asset.id == symbol }),
              all[f].holdings[h].amount + 1e-12 >= amount else { return false }
        var list = all
        let left = list[f].holdings[h].amount - amount
        if left < 1e-9 { list[f].holdings.remove(at: h) } else {
            list[f].holdings[h] = Holding(asset: list[f].holdings[h].asset, amount: left)
        }
        if let j = list[t].holdings.firstIndex(where: { $0.asset.id == symbol }) {
            list[t].holdings[j] = Holding(asset: list[t].holdings[j].asset, amount: list[t].holdings[j].amount + amount)
        } else {
            list[t].holdings.append(Holding(asset: SampleData.asset(symbol), amount: amount))
        }
        all = list
        return true
    }

    // MARK: Watch accounts

    /// Adds a watch-only account for an Ethereum address or ENS name, with its
    /// real balances, and returns it. Throws `EthereumWatch.WatchError` on bad
    /// input or network failure. Does not select it.
    @MainActor @discardableResult
    static func addWatch(address input: String, name: String) async throws -> Account {
        let address = try await EthereumWatch.resolve(input)
        let balances = try await EthereumWatch.balances(of: address)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = Account(
            id: UUID().uuidString,
            name: trimmed.isEmpty ? shortAddress(address) : trimmed,
            symbol: "eye.fill",
            holdings: balances.map { Holding(asset: SampleData.asset($0.symbol), amount: $0.amount) },
            isWatchOnly: true,
            address: address
        )
        all.append(account)
        return account
    }

    /// Re-fetches balances for a watch account. No-op for owned accounts.
    @MainActor
    static func refreshWatch(id: String) async {
        guard let account = all.first(where: { $0.id == id }), account.isWatch, let address = account.address,
              let balances = try? await EthereumWatch.balances(of: address),
              let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].holdings = balances.map { Holding(asset: SampleData.asset($0.symbol), amount: $0.amount) }
    }

    /// Adds an account from the add-account sheet. A watch account without
    /// an address yet (id "watch-0x…") gets one from its id; its balances load right away.
    @MainActor
    static func add(_ account: Account) {
        var account = account
        if account.id.hasPrefix("watch-"), account.address == nil {
            let address = String(account.id.dropFirst(6))
            if EthereumWatch.isValidAddress(address) { account.isWatchOnly = true; account.address = address }
        }
        if let i = all.firstIndex(where: { $0.id == account.id }) { all[i] = account } else { all.append(account) }
        if account.isWatchOnly { Task { await refreshWatch(id: account.id) } }
    }

    /// 0x1234…abcd
    static func shortAddress(_ address: String) -> String {
        address.count > 12 ? "\(address.prefix(6))…\(address.suffix(4))" : address
    }
}

/// Convenience namespace for account actions used by UI (e.g. the add-account sheet).
enum Accounts {
    @MainActor @discardableResult
    static func addWatch(address: String, name: String) async throws -> Account {
        try await Account.addWatch(address: address, name: name)
    }

    @MainActor static func refresh(id: String) async { await Account.refreshWatch(id: id) }
}
