import SwiftUI

/// Placeholder coin mark: monogram in a soft circle.
struct CoinIcon: View {
    let symbol: String
    var size: CGFloat = 40
    var body: some View {
        Text(String(symbol.prefix(1)))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.surfaceHi, in: Circle())
    }
}

struct ChangeText: View {
    let value: Double
    var body: some View {
        Text(value.percent)
            .font(Typo.figure)
            .foregroundStyle(value >= 0 ? Theme.positive : Theme.negative)
    }
}
