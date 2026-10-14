import Foundation

/// Display currency with a fixed sample rate from USD. Stored under "currency".
enum Currency: String, CaseIterable, Identifiable, Sendable {
    case usd = "USD", eur = "EUR", gbp = "GBP", jpy = "JPY", chf = "CHF", pln = "PLN"
    var id: String { rawValue }

    static let storageKey = "currency"
    static var current: Currency {
        Currency(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .usd
    }

    var symbol: String {
        switch self {
        case .usd: "$"
        case .eur: "€"
        case .gbp: "£"
        case .jpy: "¥"
        case .chf: "CHF"
        case .pln: "zł"
        }
    }

    /// Units of this currency per 1 USD (sample rates).
    var rate: Double {
        switch self {
        case .usd: 1
        case .eur: 0.92
        case .gbp: 0.79
        case .jpy: 149.5
        case .chf: 0.88
        case .pln: 3.98
        }
    }

    var fractionDigits: Int { self == .jpy ? 0 : 2 }

    /// Formats a USD amount in this currency with its symbol placed correctly.
    func format(_ usd: Double, compact: Bool = false) -> String {
        let value = usd * rate
        let number = compact
            ? value.formatted(.number.notation(.compactName).precision(.fractionLength(0...2)))
            : value.formatted(.number.precision(.fractionLength(fractionDigits)))
        switch self {
        case .chf: return "CHF " + number
        case .pln: return number + " zł"
        default: return symbol + number
        }
    }
}
