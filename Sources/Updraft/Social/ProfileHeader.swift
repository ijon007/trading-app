import SwiftUI

/// Profile header, left-aligned: photo, name, @handle, bio, follower counts,
/// Edit profile. Share sits top-right.
struct ProfileHeader: View {
    /// Sheets this header opens, presented by the owning screen with one
    /// `.sheet(item:)` so the header's buttons only set state.
    enum Sheet: String, Identifiable {
        case edit, followers, following, share
        var id: String { rawValue }
    }

    @Binding var sheet: Sheet?
    private var store: SocialStore { .shared }

    /// The view for a header sheet; the owner calls this from its `.sheet(item:)`.
    @ViewBuilder static func content(_ sheet: Sheet) -> some View {
        switch sheet {
        case .edit: EditProfileSheet()
        case .followers: PeopleList(kind: .followers)
        case .following: PeopleList(kind: .following)
        case .share: ProfileShareSheet()
        }
    }

    var body: some View {
        let me = store.meWithStats
        VStack(alignment: .leading, spacing: Space.md) {
            // Banner with the avatar overlapping its bottom edge; Share sits to the right.
            ProfileBanner(image: store.banner, seed: me.id + me.handle)
                .overlay(alignment: .bottomLeading) {
                    SocialAvatar(photo: store.photo, size: 84)
                        .background(Circle().stroke(Theme.background, lineWidth: 4))
                        .offset(x: Space.md, y: 42)
                }
                .zIndex(1)
            HStack(alignment: .top) {
                Spacer()
                Button { Haptics.tap(); sheet = .share } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .offset(y: -1) // optical centering: the arrow sits low
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share profile")
            }
            .frame(height: 36)
            .padding(.top, -Space.xs)
            VStack(alignment: .leading, spacing: 2) {
                Text(me.name).titleStyle().foregroundStyle(Theme.textPrimary)
                Text(me.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                if !me.bio.isEmpty {
                    Text(me.bio).font(Typo.body).foregroundStyle(Theme.textPrimary).padding(.top, Space.xs)
                }
            }
            HStack(spacing: Space.md) {
                count(me.followerCount, "Followers") { sheet = .followers }
                count(me.followingCount, "Following") { sheet = .following }
            }
            Button { Haptics.tap(); sheet = .edit } label: {
                Label("Edit profile", systemImage: "pencil.line")
                    .font(Typo.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .glassButton()
            .tint(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: store.me)
    }

    private func count(_ n: Int, _ label: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 4) {
                Text(n.formatted(.number.notation(.compactName)))
                    .font(Typo.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(n)))
                Text(label).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: n)
    }
}

/// Followers or following, with Follow buttons; tap for a profile.
struct PeopleList: View {
    enum Kind: String, Identifiable { case followers = "Followers", following = "Following"; var id: String { rawValue } }
    let kind: Kind
    @State private var selected: SocialProfile?
    private var store: SocialStore { .shared }

    var body: some View {
        let people = kind == .followers ? store.followerPeople : store.followingPeople
        NavigationStack {
            List(people) { p in
                PersonRow(profile: p) { FollowButton(id: p.id) }
                    .onTapGesture { Haptics.tap(); selected = p }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .overlay {
                if people.isEmpty {
                    ContentUnavailableView(kind == .followers ? "No followers yet" : "Not following anyone",
                                           systemImage: "person.2")
                }
            }
            .navigationTitle(kind.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { PersonProfileSheet(profile: $0) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
