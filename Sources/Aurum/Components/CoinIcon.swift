import SwiftUI
import UIKit

/// Coin mark: bundled CC0 icon (spothq/cryptocurrency-icons), falling back to a monogram circle.
struct CoinIcon: View {
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        if let image = UIImage(named: "coin-\(symbol.lowercased())", in: .module, with: nil) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(Theme.surfaceHi, in: Circle())
        }
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

/// Subtle tinted capsule for a percent change.
struct ChangePill: View {
    let value: Double
    var body: some View {
        let tint = value >= 0 ? Theme.positive : Theme.negative
        HStack(spacing: 3) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
            Text(value.percent).font(Typo.figure)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}
