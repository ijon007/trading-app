import Foundation
import Observation

/// Leaderboard periods. Opens on 1D.
enum LeaderPeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case day = "1D", week = "1W", month = "1M", all = "All"
    var id: String { rawValue }
}

/// A person on Updraft: you or a friend. Returns are percentages only.
struct SocialProfile: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var handle: String          // without "@"
    var bio: String = ""
    var emoji: String? = nil
    var color: String? = nil    // AccountPalette key
    /// Return % per period.
    var returns: [LeaderPeriod: Double] = [:]
    /// Return % per period a day earlier, for rank-change arrows.
    var previousReturns: [LeaderPeriod: Double] = [:]
    /// Top holdings as coin symbols with portfolio share (0–1).
    var topHoldings: [Holding] = []
    /// Friend chose to hide holdings.
    var hidesHoldings = false

    struct Holding: Hashable, Codable, Sendable { let symbol: String; let share: Double }

    var atHandle: String { "@" + handle }
    func returnFor(_ p: LeaderPeriod) -> Double { returns[p] ?? 0 }
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct FriendRequest: Identifiable, Hashable, Codable, Sendable {
    var id: String { profile.id }
    let profile: SocialProfile
}

/// Social backend. The app uses `MockSocialService` (local sample data);
/// a real service can replace it without touching the screens.
protocol SocialService: Sendable {
    func loadFriends() -> [SocialProfile]
    func loadRequests() -> [FriendRequest]
    /// Finds a person by handle (with or without "@").
    func lookup(handle: String) async -> SocialProfile?
}

struct MockSocialService: SocialService {
    func loadFriends() -> [SocialProfile] { Array(Self.people.prefix(6)) }
    func loadRequests() -> [FriendRequest] { Self.people[6...7].map { FriendRequest(profile: $0) } }

    func lookup(handle: String) async -> SocialProfile? {
        try? await Task.sleep(for: .milliseconds(450)) // sample round trip
        let h = SocialStore.normalized(handle)
        if let known = Self.people.first(where: { $0.handle == h }) { return known }
        guard SocialStore.isValidHandle(h) else { return nil }
        // Any valid handle "exists" in the demo, with stable sample stats.
        var seed = UInt64(5381)
        for b in h.utf8 { seed = seed &* 33 &+ UInt64(b) }
        func r(_ k: UInt64, _ range: Double) -> Double { Double((seed >> k) % 2000) / 1000 * range - range }
        return SocialProfile(id: "u-" + h, name: h.capitalized, handle: h, bio: "",
                             emoji: nil, color: AccountPalette.keys[Int(seed % 8)],
                             returns: [.day: r(3, 4), .week: r(9, 9), .month: r(15, 18), .all: r(21, 60)],
                             previousReturns: [.day: r(5, 4), .week: r(11, 9), .month: r(17, 18), .all: r(23, 60)],
                             topHoldings: [.init(symbol: "BTC", share: 0.5), .init(symbol: "ETH", share: 0.3)])
    }

    private static func p(_ id: String, _ name: String, _ handle: String, _ bio: String, _ emoji: String?, _ color: String?,
                          _ r: [Double], _ prev: [Double], _ holdings: [(String, Double)], hides: Bool = false) -> SocialProfile {
        let periods = LeaderPeriod.allCases
        return SocialProfile(id: id, name: name, handle: handle, bio: bio, emoji: emoji, color: color,
                             returns: Dictionary(uniqueKeysWithValues: zip(periods, r)),
                             previousReturns: Dictionary(uniqueKeysWithValues: zip(periods, prev)),
                             topHoldings: holdings.map { .init(symbol: $0.0, share: $0.1) }, hidesHoldings: hides)
    }

    static let people: [SocialProfile] = [
        p("f1", "Maya Chen", "maya", "Long BTC, short opinions.", "🦊", "orange",
          [3.42, 8.10, 14.2, 61.0], [2.10, 9.40, 12.8, 58.0], [("BTC", 0.55), ("ETH", 0.25), ("SOL", 0.12)]),
        p("f2", "Leo Park", "leo", "DCA every Friday.", nil, "blue",
          [1.18, 4.25, 9.6, 34.5], [1.90, 3.80, 10.1, 33.0], [("ETH", 0.48), ("LINK", 0.22), ("UNI", 0.10)]),
        p("f3", "Sara Ruiz", "sara", "Here for the charts.", "🌙", "purple",
          [-0.84, 2.40, -3.1, 12.2], [-1.20, 1.10, -2.4, 11.0], [("SOL", 0.40), ("AVAX", 0.30), ("DOT", 0.15)]),
        p("f4", "Noah Kim", "noah", "", "🐳", "teal",
          [5.95, 12.6, 22.4, 140.0], [4.20, 13.9, 20.0, 131.0], [("BTC", 0.80), ("ETH", 0.20)], hides: true),
        p("f5", "Ava Novak", "ava", "Stablecoins and sleep.", nil, nil,
          [0.21, 0.80, 1.9, 6.3], [0.40, 0.70, 2.2, 6.0], [("USDC", 0.70), ("BTC", 0.30)]),
        p("f6", "Ilan Weiss", "ilan", "Alt season any day now.", "🔥", "red",
          [-2.65, -5.10, 6.8, -18.4], [-1.10, -3.90, 7.5, -16.0], [("PEPE", 0.35), ("SHIB", 0.25), ("DOGE", 0.20)]),
        p("r1", "Tom Becker", "tom", "Builder. Mostly ETH.", "⚡️", "green",
          [2.02, 6.4, 11.0, 48.0], [1.50, 6.0, 10.2, 46.0], [("ETH", 0.6), ("ARB", 0.2)]),
        p("r2", "Zoe Hart", "zoe", "", "🌱", "pink",
          [-0.40, 1.9, 4.4, 22.0], [-0.10, 1.4, 4.0, 21.0], [("BTC", 0.5), ("SOL", 0.3)]),
    ]
}

/// Your social profile, friends and requests. Persisted locally.
@MainActor @Observable
final class SocialStore {
    static let shared = SocialStore()
    let service: any SocialService = MockSocialService()

    var me: SocialProfile { didSet { save(me, Keys.me) } }
    private(set) var friends: [SocialProfile] { didSet { save(friends, Keys.friends) } }
    private(set) var requests: [FriendRequest] { didSet { save(requests, Keys.requests) } }
    /// Your profile photo (JPEG), stored as a file in Documents.
    var photo: Data? {
        didSet {
            if let photo { try? photo.write(to: Self.photoURL) } else { try? FileManager.default.removeItem(at: Self.photoURL) }
        }
    }
    private static var photoURL: URL { URL.documentsDirectory.appending(path: "social-avatar.jpg") }

    /// Handles you've sent requests to (demo: they accept after a moment).
    private(set) var pending: Set<String> = []

    private enum Keys {
        static let me = "social.me.v1", friends = "social.friends.v1", requests = "social.requests.v1"
    }

    private init() {
        let base = SampleData.profile
        me = Self.load(Keys.me) ?? SocialProfile(
            id: "me", name: base.name, handle: Self.normalized(base.handle), bio: "", emoji: nil, color: nil)
        friends = Self.load(Keys.friends) ?? MockSocialService().loadFriends()
        requests = Self.load(Keys.requests) ?? MockSocialService().loadRequests()
        photo = try? Data(contentsOf: Self.photoURL)
    }

    // MARK: Me

    /// Your returns come from the current account: 1D is the live 24h change,
    /// longer periods follow the balance history.
    func myReturns() -> [LeaderPeriod: Double] {
        func change(_ t: Timeframe) -> Double {
            let s = SampleData.balanceSeries(t)
            guard let first = s.first?.price, let last = s.last?.price, first > 0 else { return 0 }
            return (last - first) / first * 100
        }
        return [.day: SampleData.totalChange24h, .week: change(.week), .month: change(.month), .all: change(.all)]
    }

    var meWithReturns: SocialProfile {
        var m = me
        m.returns = myReturns()
        m.previousReturns = m.returns.mapValues { $0 * 0.9 }
        m.topHoldings = topHoldings()
        return m
    }

    private func topHoldings() -> [SocialProfile.Holding] {
        let total = SampleData.totalBalance
        guard total > 0 else { return [] }
        return SampleData.holdings.sorted { $0.value > $1.value }.prefix(3)
            .map { .init(symbol: $0.asset.id, share: $0.value / total) }
    }

    // MARK: Friends

    func accept(_ request: FriendRequest) {
        requests.removeAll { $0.id == request.id }
        if !friends.contains(where: { $0.id == request.id }) { friends.insert(request.profile, at: 0) }
    }

    func decline(_ request: FriendRequest) { requests.removeAll { $0.id == request.id } }

    func remove(_ friend: SocialProfile) { friends.removeAll { $0.id == friend.id } }

    func isFriend(_ handle: String) -> Bool { friends.contains { $0.handle == Self.normalized(handle) } }

    /// Sends a request; in the demo the other side accepts after ~2s.
    func sendRequest(to profile: SocialProfile) {
        pending.insert(profile.handle)
        Task {
            try? await Task.sleep(for: .seconds(2))
            pending.remove(profile.handle)
            if !friends.contains(where: { $0.id == profile.id }) { friends.insert(profile, at: 0) }
        }
    }

    /// Everyone on the board: you plus friends.
    func board(_ period: LeaderPeriod) -> [Ranked] {
        let all = [meWithReturns] + friends
        let now = all.sorted { $0.returnFor(period) > $1.returnFor(period) }
        let before = all.sorted { ($0.previousReturns[period] ?? 0) > ($1.previousReturns[period] ?? 0) }
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
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "https://updraft.app/u/", with: "")
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
