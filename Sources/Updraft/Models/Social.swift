import Foundation
import Observation

/// Leaderboard periods. Opens on 1D.
enum LeaderPeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case day = "1D", week = "1W", month = "1M", all = "All"
    var id: String { rawValue }
}

/// A person on Updraft: you or someone you can follow. Returns are percentages only.
struct SocialProfile: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var handle: String          // without "@"
    var bio: String = ""
    /// Return % per period.
    var returns: [LeaderPeriod: Double] = [:]
    /// Return % per period a day earlier, for rank-change arrows.
    var previousReturns: [LeaderPeriod: Double] = [:]
    /// Top holdings as coin symbols with portfolio share (0–1).
    var topHoldings: [Holding] = []
    /// They chose to hide holdings.
    var hidesHoldings = false
    var followerCount = 0
    var followingCount = 0
    /// Current (public) account value. Optional so older saved profiles still decode.
    var value: Double? = nil
    /// How many coins they hold in total (for the "N+" in coin stacks).
    var holdingCount: Int? = nil

    struct Holding: Hashable, Codable, Sendable { let symbol: String; let share: Double }

    var atHandle: String { "@" + handle }
    func returnFor(_ p: LeaderPeriod) -> Double { returns[p] ?? 0 }
    /// Dollar P&L over the period: value now minus value at the period start.
    func pnlFor(_ p: LeaderPeriod) -> Double { pnl(returnFor(p)) }
    func previousPnlFor(_ p: LeaderPeriod) -> Double { pnl(previousReturns[p] ?? returnFor(p)) }
    private func pnl(_ r: Double) -> Double {
        let v = value ?? 0
        return r <= -100 ? -v : v - v / (1 + r / 100)
    }
}

/// One line in the Activity feed.
struct ActivityItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case bought(String), sold(String)
        /// A holding moved a lot (symbol, percent).
        case bigMove(String, Double)
        /// Started following someone (their id).
        case followed(String)
    }
    let id: String
    let personID: String
    let kind: Kind
    let date: Date

    /// Sample trade size in USD, seeded from the id (buys and sells only).
    var amount: Double {
        var seed: UInt64 = 1469598103934665603
        for b in id.utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        return Double(150 + seed % 12_000) + Double(seed % 100) / 100
    }
}

/// Social backend. The app uses `MockSocialService` (local sample data);
/// a real service can replace it without touching the screens.
protocol SocialService: Sendable {
    func people() -> [SocialProfile]
    func activity() -> [ActivityItem]
    /// Ids of sample people who follow you.
    func followerIDs() -> [String]
    /// Account value over a period, ending at their return for it.
    func series(for profile: SocialProfile, period: LeaderPeriod) -> [PricePoint]
}

struct MockSocialService: SocialService {
    func people() -> [SocialProfile] { Self.samplePeople }
    func followerIDs() -> [String] { ["f1", "f3", "f4", "f7", "f8"] }

    /// Seeded random walk per person and period that starts at 100 and ends at
    /// 100 × (1 + return), so the line always agrees with the % shown.
    func series(for profile: SocialProfile, period: LeaderPeriod) -> [PricePoint] {
        let (count, step): (Int, TimeInterval) = switch period {
        case .day: (96, 900)
        case .week: (84, 7200)
        case .month: (90, 28_800)
        case .all: (120, 86_400 * 3)
        }
        var seed: UInt64 = 1469598103934665603
        for b in (profile.id + period.rawValue).utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53) - 0.5
        }
        let end = 100 * (1 + profile.returnFor(period) / 100)
        let vol = max(abs(end - 100), 1.5) * 0.18
        var walk: [Double] = [0]
        for _ in 1..<count { walk.append(walk[walk.count - 1] + next() * vol) }
        // Bridge: bend the walk so it starts at 100 and lands exactly on `end`.
        let last = walk[count - 1]
        let now = Date.now
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            let value = 100 + (end - 100) * t + (walk[i] - last * t)
            return PricePoint(date: now.addingTimeInterval(-Double(count - 1 - i) * step), price: max(value, 1))
        }
    }

    func activity() -> [ActivityItem] {
        let now = Date.now
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            .init(id: "a1", personID: "f1", kind: .bought("BTC"), date: ago(4)),
            .init(id: "a2", personID: "f4", kind: .bigMove("SOL", 8.4), date: ago(18)),
            .init(id: "a3", personID: "f2", kind: .sold("LINK"), date: ago(42)),
            .init(id: "a4", personID: "f6", kind: .followed("f3"), date: ago(75)),
            .init(id: "a5", personID: "f3", kind: .bought("AVAX"), date: ago(130)),
            .init(id: "a6", personID: "f6", kind: .bigMove("PEPE", -12.6), date: ago(220)),
            .init(id: "a7", personID: "f5", kind: .bought("ETH"), date: ago(400)),
            .init(id: "a8", personID: "f7", kind: .sold("ETH"), date: ago(700)),
            .init(id: "a9", personID: "f2", kind: .followed("f1"), date: ago(1300)),
            .init(id: "a10", personID: "f8", kind: .bigMove("BTC", 4.1), date: ago(2000)),
        ]
    }

    private static func p(_ id: String, _ name: String, _ handle: String, _ bio: String,
                          _ r: [Double], _ prev: [Double], _ holdings: [(String, Double)],
                          followers: Int, following: Int, hides: Bool = false) -> SocialProfile {
        let periods = LeaderPeriod.allCases
        // Seeded per person so values stay put between launches.
        var seed: UInt64 = 1469598103934665603
        for b in id.utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        let value = 8_000 + Double(seed % 420_000) + Double(seed % 100) / 100
        let count = holdings.count + Int((seed >> 8) % 110)
        return SocialProfile(id: id, name: name, handle: handle, bio: bio,
                             returns: Dictionary(uniqueKeysWithValues: zip(periods, r)),
                             previousReturns: Dictionary(uniqueKeysWithValues: zip(periods, prev)),
                             topHoldings: holdings.map { .init(symbol: $0.0, share: $0.1) }, hidesHoldings: hides,
                             followerCount: followers, followingCount: following,
                             value: value, holdingCount: count)
    }

    static let samplePeople: [SocialProfile] = [
        p("f1", "Maya Chen", "maya", "Long BTC, short opinions.",
          [3.42, 8.10, 14.2, 61.0], [2.10, 9.40, 12.8, 58.0], [("BTC", 0.55), ("ETH", 0.25), ("SOL", 0.12)],
          followers: 1240, following: 180),
        p("f2", "Leo Park", "leo", "DCA every Friday.",
          [1.18, 4.25, 9.6, 34.5], [1.90, 3.80, 10.1, 33.0], [("ETH", 0.48), ("LINK", 0.22), ("UNI", 0.10)],
          followers: 312, following: 95),
        p("f3", "Sara Ruiz", "sara", "Here for the charts.",
          [-0.84, 2.40, -3.1, 12.2], [-1.20, 1.10, -2.4, 11.0], [("SOL", 0.40), ("AVAX", 0.30), ("DOT", 0.15)],
          followers: 88, following: 140),
        p("f4", "Noah Kim", "noah", "",
          [5.95, 12.6, 22.4, 140.0], [4.20, 13.9, 20.0, 131.0], [("BTC", 0.80), ("ETH", 0.20)],
          followers: 5300, following: 12),
        p("f5", "Ava Novak", "ava", "Stablecoins and sleep.",
          [0.21, 0.80, 1.9, 6.3], [0.40, 0.70, 2.2, 6.0], [("USDC", 0.70), ("BTC", 0.30)],
          followers: 64, following: 70, hides: true),
        p("f6", "Ilan Weiss", "ilan", "Alt season any day now.",
          [-2.65, -5.10, 6.8, -18.4], [-1.10, -3.90, 7.5, -16.0], [("PEPE", 0.35), ("SHIB", 0.25), ("DOGE", 0.20)],
          followers: 410, following: 600),
        p("f7", "Tom Becker", "tom", "Builder. Mostly ETH.",
          [2.02, 6.4, 11.0, 48.0], [1.50, 6.0, 10.2, 46.0], [("ETH", 0.6), ("ARB", 0.2)],
          followers: 990, following: 210),
        p("f8", "Zoe Hart", "zoe", "",
          [-0.40, 1.9, 4.4, 22.0], [-0.10, 1.4, 4.0, 21.0], [("BTC", 0.5), ("SOL", 0.3)],
          followers: 150, following: 160),
        p("f9", "Kai Osei", "kai", "Quant by day.",
          [1.70, 3.3, 7.9, 29.0], [1.40, 3.6, 7.0, 27.0], [("BTC", 0.4), ("ETH", 0.4), ("SOL", 0.2)],
          followers: 2100, following: 300),
    ]
}

/// Your profile, who you follow, and the people and activity you see. Persisted locally.
@MainActor @Observable
final class SocialStore {
    static let shared = SocialStore()
    let service: any SocialService = MockSocialService()

    var me: SocialProfile { didSet { save(me, Keys.me) } }
    /// Ids of people you follow.
    private(set) var following: [String] { didSet { save(following, Keys.following) } }
    let people: [SocialProfile]
    let followerIDs: [String]

    /// Your profile photo (JPEG), stored as a file in Documents. Nil shows a silhouette.
    var photo: Data? {
        didSet {
            if let photo { try? photo.write(to: Self.photoURL) } else { try? FileManager.default.removeItem(at: Self.photoURL) }
        }
    }
    private static var photoURL: URL { URL.documentsDirectory.appending(path: "social-avatar.jpg") }

    /// Your profile banner (JPEG) in Documents. Nil shows a gradient.
    var banner: Data? {
        didSet {
            if let banner { try? banner.write(to: Self.bannerURL) } else { try? FileManager.default.removeItem(at: Self.bannerURL) }
        }
    }
    private static var bannerURL: URL { URL.documentsDirectory.appending(path: "social-banner.jpg") }

    private enum Keys { static let me = "social.me.v2", following = "social.following.v1" }

    private init() {
        let mock = MockSocialService()
        let base = SampleData.profile
        people = mock.people()
        followerIDs = mock.followerIDs()
        me = Self.load(Keys.me) ?? SocialProfile(id: "me", name: base.name, handle: Self.normalized(base.handle))
        following = Self.load(Keys.following) ?? ["f1", "f2", "f3", "f4", "f6"]
        photo = try? Data(contentsOf: Self.photoURL)
        banner = try? Data(contentsOf: Self.bannerURL)
    }

    // MARK: People

    func person(_ id: String) -> SocialProfile? { people.first { $0.id == id } }
    func isFollowing(_ id: String) -> Bool { following.contains(id) }

    func toggleFollow(_ id: String) {
        if let i = following.firstIndex(of: id) { following.remove(at: i) } else { following.insert(id, at: 0) }
    }

    var followingPeople: [SocialProfile] { following.compactMap(person) }
    var followerPeople: [SocialProfile] { followerIDs.compactMap(person) }

    /// Name or @handle match, best first.
    func search(_ query: String) -> [SocialProfile] {
        let q = Self.normalized(query)
        guard !q.isEmpty else { return [] }
        return people.filter { $0.handle.contains(q) || $0.name.lowercased().contains(q) }
            .sorted { ($0.handle.hasPrefix(q) ? 0 : 1, $0.name) < ($1.handle.hasPrefix(q) ? 0 : 1, $1.name) }
    }

    /// Activity from people you follow, newest first.
    var feed: [ActivityItem] {
        service.activity().filter { following.contains($0.personID) }.sorted { $0.date > $1.date }
    }

    // MARK: Me

    /// Your returns come from the current account: 1D is the live 24h change,
    /// longer periods follow the balance history.
    func myReturns() -> [LeaderPeriod: Double] {
        let holdings = publicHoldings
        func change(_ t: Timeframe) -> Double {
            let s = SampleData.balanceSeries(t, holdings: holdings)
            guard let first = s.first?.price, let last = s.last?.price, first > 0 else { return 0 }
            return (last - first) / first * 100
        }
        let now = holdings.reduce(0) { $0 + $1.value }
        let prev = holdings.reduce(0) { $0 + $1.value / (1 + $1.asset.change24h / 100) }
        let day = prev > 0 ? (now - prev) / prev * 100 : 0
        return [.day: day, .week: change(.week), .month: change(.month), .all: change(.all)]
    }

    /// Holdings of your public accounts only (watch-only included), merged by coin.
    var publicHoldings: [Holding] {
        var amounts: [String: Double] = [:]
        for account in Account.all where !account.isPrivate {
            for h in account.holdings { amounts[h.asset.id, default: 0] += h.amount }
        }
        return amounts.map { Holding(asset: SampleData.asset($0.key), amount: $0.value) }.sorted { $0.asset.id < $1.asset.id }
    }

    /// False when every account is private: others see a Private state.
    var hasPublicAccounts: Bool { Account.all.contains { !$0.isPrivate } }

    var meWithStats: SocialProfile {
        var m = me
        m.returns = myReturns()
        m.previousReturns = m.returns.mapValues { $0 * 0.9 }
        m.followerCount = followerIDs.count
        m.followingCount = following.count
        let holdings = publicHoldings
        let total = holdings.reduce(0) { $0 + $1.value }
        if total > 0 {
            m.topHoldings = holdings.sorted { $0.value > $1.value }.prefix(3)
                .map { .init(symbol: $0.asset.id, share: $0.value / total) }
        }
        m.hidesHoldings = !hasPublicAccounts
        m.value = total
        m.holdingCount = holdings.filter { $0.amount > 0 }.count
        return m
    }

    // MARK: Leaderboard

    /// You plus everyone you follow, ranked by return.
    func board(_ period: LeaderPeriod) -> [Ranked] {
        // Private (no public accounts): you're left off the board.
        let all = (hasPublicAccounts ? [meWithStats] : []) + followingPeople
        // Strictly by return; ties fall back to name, then id, so order never flickers.
        func ordered(_ value: (SocialProfile) -> Double) -> [SocialProfile] {
            all.sorted { a, b in
                let va = value(a), vb = value(b)
                if va != vb { return va > vb }
                if a.name != b.name { return a.name < b.name }
                return a.id < b.id
            }
        }
        // Ranked by dollar P&L, the number every row shows.
        let now = ordered { $0.pnlFor(period) }
        let before = ordered { $0.previousPnlFor(period) }
        return now.enumerated().map { i, p in
            let prev = before.firstIndex { $0.id == p.id } ?? i
            return Ranked(rank: i + 1, change: prev - i, profile: p, isMe: p.id == me.id)
        }
    }

    struct Ranked: Identifiable, Hashable {
        let rank: Int
        /// Positions gained (+) or lost (−) since yesterday.
        let change: Int
        let profile: SocialProfile
        let isMe: Bool
        var id: String { profile.id }
    }

    /// Shareable profile link.
    var profileLink: URL { URL(string: "https://updraft.app/u/\(me.handle)")! }

    // MARK: Handles

    nonisolated static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "@", with: "")
    }

    /// 3–15 characters: a–z, 0–9 and underscore.
    nonisolated static func isValidHandle(_ h: String) -> Bool {
        (3...15).contains(h.count) && h.allSatisfy { ($0.isLetter && $0.isASCII) || $0.isNumber || $0 == "_" }
    }

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
