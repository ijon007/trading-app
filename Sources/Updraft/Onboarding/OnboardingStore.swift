import SwiftUI
import Observation

/// UserDefaults keys for onboarding answers.
enum OnboardingKeys {
    static let done = "onboarding.done"
    static let name = "onboarding.name"
    static let email = "onboarding.email"
    static let experience = "onboarding.experience"
    static let goals = "onboarding.goals"
    static let risk = "onboarding.risk"
    static let notifications = "onboarding.notifications"
}

enum Experience: String, CaseIterable, Identifiable {
    case beginner, intermediate, pro
    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .pro: "Pro"
        }
    }
    var subtitle: String {
        switch self {
        case .beginner: "New to crypto. Keep things simple."
        case .intermediate: "I've bought and held a few coins."
        case .pro: "I trade often and know the market."
        }
    }
    var symbol: String {
        switch self {
        case .beginner: "leaf"
        case .intermediate: "chart.bar"
        case .pro: "bolt"
        }
    }
}

enum Goal: String, CaseIterable, Identifiable {
    case longTerm, trading, saving, exploring
    var id: String { rawValue }
    var title: String {
        switch self {
        case .longTerm: "Long-term investing"
        case .trading: "Trading"
        case .saving: "Saving"
        case .exploring: "Exploring"
        }
    }
    var symbol: String {
        switch self {
        case .longTerm: "chart.line.uptrend.xyaxis"
        case .trading: "arrow.left.arrow.right"
        case .saving: "banknote"
        case .exploring: "sparkle.magnifyingglass"
        }
    }
}

enum RiskLevel: String, CaseIterable, Identifiable {
    case cautious, balanced, bold
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cautious: "Cautious"
        case .balanced: "Balanced"
        case .bold: "Bold"
        }
    }
    var subtitle: String {
        switch self {
        case .cautious: "Protect what I have. Small swings only."
        case .balanced: "Some ups and downs are fine."
        case .bold: "Big swings for bigger upside."
        }
    }
    var symbol: String {
        switch self {
        case .cautious: "shield"
        case .balanced: "scalemass"
        case .bold: "flame"
        }
    }
}

extension Currency {
    var displayName: String {
        switch self {
        case .usd: "US Dollar"
        case .eur: "Euro"
        case .gbp: "British Pound"
        case .jpy: "Japanese Yen"
        case .chf: "Swiss Franc"
        case .pln: "Polish Złoty"
        }
    }
}

/// Answers collected during onboarding; saved once at the end.
@Observable
final class OnboardingAnswers {
    var name = ""
    var email = ""
    var experience: Experience?
    var goals: Set<Goal> = []
    var currency: Currency = .current
    var risk: RiskLevel?
    var notifications = false

    var firstName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").first ?? ""
    }

    func save() {
        let d = UserDefaults.standard
        d.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: OnboardingKeys.name)
        d.set(email.trimmingCharacters(in: .whitespacesAndNewlines), forKey: OnboardingKeys.email)
        d.set(experience?.rawValue, forKey: OnboardingKeys.experience)
        d.set(goals.map(\.rawValue).sorted(), forKey: OnboardingKeys.goals)
        d.set(currency.rawValue, forKey: Currency.storageKey)
        d.set(risk?.rawValue, forKey: OnboardingKeys.risk)
        d.set(notifications, forKey: OnboardingKeys.notifications)
    }

    /// Clears answers and shows onboarding again (debug / replay).
    static func reset() {
        let d = UserDefaults.standard
        for key in [OnboardingKeys.name, OnboardingKeys.email, OnboardingKeys.experience,
                    OnboardingKeys.goals, OnboardingKeys.risk, OnboardingKeys.notifications] {
            d.removeObject(forKey: key)
        }
        d.set(false, forKey: OnboardingKeys.done)
    }
}
