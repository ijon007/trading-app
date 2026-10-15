import SwiftUI

// MARK: - Editing rules

/// Pure editing rules for keypad-driven amount strings (e.g. "120.5").
/// Shared by Buy, Sell, Send and any other amount entry.
enum AmountInput {
    enum Key: Hashable { case digit(Int), decimal, delete }

    /// Applies a key to `text`. Returns `text` unchanged when the key is rejected
    /// (too many decimals, second separator, too many digits).
    static func apply(_ key: Key, to text: String, maxFractionDigits: Int, maxIntegerDigits: Int = 9) -> String {
        switch key {
        case .delete:
            return text.count <= 1 ? "0" : String(text.dropLast())
        case .decimal:
            guard maxFractionDigits > 0, !text.contains(".") else { return text }
            return text + "."
        case .digit(let d):
            if let dot = text.firstIndex(of: ".") {
                guard text[text.index(after: dot)...].count < maxFractionDigits else { return text }
                return text + String(d)
            }
            if text == "0" { return String(d) }
            guard text.count < maxIntegerDigits else { return text }
            return text + String(d)
        }
    }

    /// Numeric value of an amount string.
    static func value(_ text: String) -> Double { Double(text) ?? 0 }

    /// Amount string for a value, truncated (never rounded up) to `maxFractionDigits`.
    static func text(for value: Double, maxFractionDigits: Int) -> String {
        guard value > 0, value.isFinite else { return "0" }
        let scale = pow(10, Double(maxFractionDigits))
        let truncated = (value * scale).rounded(.down) / scale
        return truncated.formatted(
            .number.precision(.fractionLength(0...maxFractionDigits)).grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX")))
    }

    /// Adds thousands grouping to an amount string while keeping a trailing "." or zeros as typed.
    static func grouped(_ text: String) -> String {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let int = Int(parts.first ?? "0") ?? 0
        var out = int.formatted(.number.locale(Locale(identifier: "en_US")))
        if parts.count > 1 { out += "." + parts[1] }
        return out
    }
}

// MARK: - Big number

/// Large centered amount with an optional tappable secondary line (e.g. live conversion
/// with a swap control). Shakes when `shake` changes.
struct AmountDisplay: View {
    /// Fully formatted primary amount, e.g. "$120.5" or "0.0021 BTC".
    let amount: String
    /// Numeric value, drives the rolling digit transition.
    let value: Double
    var secondary: String? = nil
    var isError: Bool = false
    var shake: Int = 0
    /// When set, the secondary line becomes a swap button (fiat ↔ coin).
    var onSwap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Space.sm) {
            Text(amount)
                .heroNumeral()
                .foregroundStyle(isError ? Theme.negative : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: value))
                .animation(.snappy(duration: 0.18), value: amount)
                .animation(.smooth(duration: 0.2), value: isError)
                .keyframeAnimator(initialValue: CGFloat(0), trigger: shake) { view, x in
                    view.offset(x: x)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-Space.sm, duration: 0.05)
                        LinearKeyframe(Space.xs, duration: 0.07)
                        LinearKeyframe(-Space.xxs, duration: 0.07)
                        SpringKeyframe(0, duration: 0.2)
                    }
                }
                .padding(.horizontal, Space.md)
                .accessibilityLabel(amount)

            if let secondary {
                if let onSwap {
                    Button {
                        Haptics.select()
                        onSwap()
                    } label: {
                        HStack(spacing: Space.xxs) {
                            Text(secondary).font(Typo.figure).contentTransition(.numericText())
                            Image(systemName: "arrow.up.arrow.down").font(Typo.caption)
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Switches the amount unit")
                } else {
                    Text(secondary).font(Typo.figure).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Quick amount chips

struct AmountChip: Identifiable {
    let id: String
    let title: String
    var isSelected: Bool = false
    let action: () -> Void
}

/// Row of equal-width quick amount chips (presets or percentages).
struct AmountChips: View {
    let chips: [AmountChip]

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(chips) { chip in
                Button {
                    Haptics.select()
                    chip.action()
                } label: {
                    Text(chip.title)
                        .font(Typo.figure)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.xs)
                        .foregroundStyle(chip.isSelected ? Theme.background : Theme.textPrimary)
                        .background(chip.isSelected ? Theme.accent : Theme.surfaceHi, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
            }
        }
        .animation(.snappy(duration: 0.2), value: chips.map(\.isSelected))
    }
}

// MARK: - Keypad

/// Custom number pad bound to an amount string. Long-press delete clears.
struct AmountKeypad: View {
    @Binding var text: String
    var maxFractionDigits: Int = 2
    var maxIntegerDigits: Int = 9
    /// Called after an accepted key changes the text.
    var onChange: () -> Void = {}
    /// Called when a key is rejected (e.g. too many decimals).
    var onReject: () -> Void = {}

    private let rows: [[AmountInput.Key]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimal, .digit(0), .delete],
    ]

    var body: some View {
        Grid(horizontalSpacing: Space.xs, verticalSpacing: Space.xxs) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r], id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: AmountInput.Key) -> some View {
        Button { press(key) } label: {
            label(for: key)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Space.xxl + Space.xs)
                .contentShape(.rect)
        }
        .buttonStyle(KeypadKeyStyle())
        .disabled(key == .decimal && maxFractionDigits == 0)
        .opacity(key == .decimal && maxFractionDigits == 0 ? 0 : 1)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            guard key == .delete, text != "0" else { return }
            text = "0"
            Haptics.medium()
            onChange()
        })
        .accessibilityLabel(accessibilityName(key))
    }

    @ViewBuilder private func label(for key: AmountInput.Key) -> some View {
        switch key {
        case .digit(let d): Text(String(d)).font(Typo.title.monospacedDigit())
        case .decimal: Text(".").font(Typo.title)
        case .delete: Image(systemName: "delete.left").font(Typo.headline)
        }
    }

    private func press(_ key: AmountInput.Key) {
        let next = AmountInput.apply(key, to: text, maxFractionDigits: maxFractionDigits, maxIntegerDigits: maxIntegerDigits)
        guard next != text else {
            if !(key == .delete && text == "0") { Haptics.error(); onReject() }
            return
        }
        Haptics.tap()
        text = next
        onChange()
    }

    private func accessibilityName(_ key: AmountInput.Key) -> String {
        switch key {
        case .digit(let d): String(d)
        case .decimal: "Decimal point"
        case .delete: "Delete"
        }
    }
}

/// Instant press feedback: a soft surface fills in under the key.
private struct KeypadKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Theme.surfaceHi)
                    .opacity(configuration.isPressed ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
