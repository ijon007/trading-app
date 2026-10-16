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
        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

extension SocialStore {
    /// Your photo for your own avatar; others have none in the demo.
    func photo(for profile: SocialProfile) -> Data? { profile.id == me.id ? photo : nil }
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
