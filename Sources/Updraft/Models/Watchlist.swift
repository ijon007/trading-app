import Foundation
import Observation

/// Starred coin ids, persisted in UserDefaults (`watchlist.v1`) and observable
/// so Home and the coin sheet stay in sync.
@MainActor @Observable
final class Watchlist {
    static let shared = Watchlist()
    private static let key = "watchlist.v1"

    private(set) var ids: [String] {
        didSet { UserDefaults.standard.set(ids, forKey: Self.key) }
    }

    private init() { ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? [] }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if let i = ids.firstIndex(of: id) { ids.remove(at: i) } else { ids.append(id) }
    }

    /// Starred coins at live prices, in the order they were starred.
    var assets: [Asset] { ids.map { SampleData.asset($0) } }
}
