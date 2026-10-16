import SwiftUI
import UIKit

/// Round avatar for a person: photo (yours), emoji or initial, on their color.
struct SocialAvatar: View {
    let profile: SocialProfile
    var size: CGFloat = 40
    /// Your photo, when this avatar is you.
    var photo: Data? = nil

    var body: some View {
        let tint = AccountPalette.color(profile.color)
        ZStack {
            Circle().fill(tint?.opacity(0.18) ?? Theme.surfaceHi)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let emoji = profile.emoji {
                Text(emoji).font(.system(size: size * 0.48))
            } else {
                Text(profile.initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint ?? Theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Return % with an up/down tint; percentages stay visible in privacy mode.
struct ReturnText: View {
    let value: Double
    var font: Font = Typo.figure

    var body: some View {
        Text(value.percent)
            .font(font)
            .foregroundStyle(value >= 0 ? Theme.positive : Theme.negative)
            .contentTransition(.numericText(value: value))
    }
}

/// Up/down arrow for leaderboard rank changes.
struct RankChange: View {
    let change: Int

    var body: some View {
        Group {
            if change > 0 {
                Label("\(change)", systemImage: "arrowtriangle.up.fill").foregroundStyle(Theme.positive)
            } else if change < 0 {
                Label("\(-change)", systemImage: "arrowtriangle.down.fill").foregroundStyle(Theme.negative)
            } else {
                Image(systemName: "minus").foregroundStyle(Theme.textTertiary)
            }
        }
        .labelStyle(CompactLabel())
        .font(.system(size: 11, weight: .semibold))
        .frame(width: 30)
        .accessibilityLabel(change == 0 ? "No change" : change > 0 ? "Up \(change)" : "Down \(-change)")
    }

    private struct CompactLabel: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 2) { configuration.icon.font(.system(size: 7)); configuration.title }
        }
    }
}
