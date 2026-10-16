import SwiftUI
import UIKit

/// Round avatar: a photo, or a neutral person silhouette.
struct SocialAvatar: View {
    var photo: Data? = nil
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.surfaceHi)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46))
                    .foregroundStyle(Theme.textTertiary)
                    .offset(y: size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // clipShape only clips drawing: a scaledToFill photo still hit-tests
        // at its full overflowing size. Limit the tap area to the circle.
        .contentShape(.circle)
        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

extension SocialStore {
    /// Your photo for your own avatar; others have none in the demo.
    func photo(for profile: SocialProfile) -> Data? { profile.id == me.id ? photo : nil }
}

/// Small circular copy of your photo for the tab bar (rendered original, not tinted).
enum ProfileTabIcon {
    @MainActor private static var cache: (Int, UIImage)?

    @MainActor static func image(_ photo: Data?) -> UIImage? {
        guard let photo, let source = UIImage(data: photo) else { return nil }
        if let cache, cache.0 == photo.hashValue { return cache.1 }
        let side: CGFloat = 28
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            UIBezierPath(ovalIn: rect).addClip()
            let scale = side / min(source.size.width, source.size.height)
            let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }.withRenderingMode(.alwaysOriginal)
        cache = (photo.hashValue, image)
        return image
    }
}

/// Return % tinted up/down. Percentages stay visible in privacy mode.
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

/// Signed dollar P&L (+$46,537.92), tinted up/down, hidden in privacy mode.
struct PnLText: View {
    let value: Double
    var font: Font = Typo.figure

    var body: some View {
        Text((value >= 0 ? "+" : "-") + abs(value).fiat)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(value >= 0 ? Theme.positive : Theme.negative)
            .contentTransition(.numericText(value: value))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .privateAmount()
    }
}

/// Up to three overlapping coin icons, plus a dark "N+" circle for the rest.
struct CoinStack: View {
    let symbols: [String]
    var total: Int? = nil
    var size: CGFloat = 22

    private var extra: Int { max((total ?? symbols.count) - min(symbols.count, 3), 0) }

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(symbols.prefix(3).enumerated()), id: \.element) { i, symbol in
                CoinIcon(symbol: symbol, size: size)
                    .background(Circle().stroke(Theme.background, lineWidth: 2))
                    .zIndex(Double(3 - i))
            }
            if extra > 0 {
                Text("\(extra)+")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .minimumScaleFactor(0.6)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(white: 0.14)))
                    .background(Circle().stroke(Theme.background, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Holds \(symbols.prefix(3).joined(separator: ", "))\(extra > 0 ? " and \(extra) more" : "")")
    }
}

/// Wide profile banner, like X: your image, or a soft gradient seeded by id.
struct ProfileBanner: View {
    var image: Data? = nil
    let seed: String
    var height: CGFloat = 120

    var body: some View {
        Group {
            if let image, let ui = UIImage(data: image) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(.rect(cornerRadius: Radius.lg))
        // A scaledToFill photo hit-tests beyond its clip (a portrait banner
        // ran far down, over Share and Followers). Decorative: no hit testing.
        .contentShape(.rect)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let hue = Double(h % 360) / 360
        return [Color(hue: hue, saturation: 0.32, brightness: 0.78),
                Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.42, brightness: 0.52)]
    }
}

/// Follow / Following toggle.
struct FollowButton: View {
    let id: String
    var store: SocialStore { .shared }

    var body: some View {
        let following = store.isFollowing(id)
        Button {
            following ? Haptics.select() : Haptics.success()
            withAnimation(.snappy(duration: 0.25)) { store.toggleFollow(id) }
        } label: {
            Text(following ? "Following" : "Follow")
                .font(Typo.callout.weight(.medium))
                .frame(minWidth: 76)
                .contentTransition(.interpolate)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 6)
        .foregroundStyle(following ? Theme.textPrimary : Theme.background)
        .background(following ? Color.clear : Theme.textPrimary, in: .capsule)
        .overlay(Capsule().strokeBorder(following ? Theme.hairline : .clear))
        .animation(.snappy(duration: 0.25), value: following)
        .accessibilityLabel(following ? "Following. Double tap to unfollow." : "Follow")
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

/// Person row: avatar, name, @handle, then a trailing view.
struct PersonRow<Trailing: View>: View {
    let profile: SocialProfile
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.sm) {
            SocialAvatar(photo: SocialStore.shared.photo(for: profile), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(profile.atHandle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Space.xs)
            trailing
        }
        .contentShape(Rectangle())
    }
}
