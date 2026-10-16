import SwiftUI

/// Profile header, left-aligned: photo, name, @handle, bio, follower counts,
/// Edit profile. Share sits top-right.
struct ProfileHeader: View {
    private var store: SocialStore { .shared }
    @State private var editing = false
    @State private var list: PeopleList.Kind?

    var body: some View {
        let me = store.meWithStats
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top) {
                SocialAvatar(photo: store.photo, size: 84)
                Spacer()
                ShareLink(item: store.profileLink, message: Text("Follow me on Updraft: \(me.atHandle)")) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(me.name).titleStyle().foregroundStyle(Theme.textPrimary)
                Text(me.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                if !me.bio.isEmpty {
                    Text(me.bio).font(Typo.body).foregroundStyle(Theme.textPrimary).padding(.top, Space.xs)
                }
            }
            HStack(spacing: Space.md) {
                count(me.followerCount, "Followers") { list = .followers }
                count(me.followingCount, "Following") { list = .following }
            }
            Button { Haptics.tap(); editing = true } label: {
                Label("Edit profile", systemImage: "person.crop.circle")
                    .font(Typo.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .glassButton()
            .tint(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: store.me)
        .sheet(isPresented: $editing) { EditProfileSheet() }
        .sheet(item: $list) { PeopleList(kind: $0) }
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
