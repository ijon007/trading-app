import UIKit

/// Aurum haptic conventions (follow these on every new screen):
/// - Selection (`.sensoryFeedback(.selection, trigger:)` / `select()`): tab switches,
///   segmented pickers, pickers, toggles.
/// - Light impact (`tap()`): buttons, quick actions, row taps, pull to refresh.
/// - Warning (`warning()`): before destructive confirmations (e.g. sign out).
/// - Success (`success()`): a completed action (e.g. confirmed sign out).
/// - Error (`error()`): a failed action.
/// - None: passive state changes such as empty search results.
/// Prefer native `.sensoryFeedback` when there's a value to trigger on;
/// use these helpers inside button actions.
@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
