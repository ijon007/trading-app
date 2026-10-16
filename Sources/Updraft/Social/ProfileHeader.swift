import SwiftUI
import os

let profileLog = Logger(subsystem: "com.ijon007.Updraft", category: "ProfileHeader")

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
                        .allowsHitTesting(false)
                }
            HStack(alignment: .top) {
                Spacer()
                Button { open(.share) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .offset(y: -1) // optical centering: the arrow sits low
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.borderless)
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
                count(me.followerCount, "Followers") { open(.followers) }
                count(me.followingCount, "Following") { open(.following) }
            }
            // Borderless + glass background instead of the glass button style:
            // in a List row, only borderless buttons get their own taps.
            Button { open(.edit) } label: {
                Label("Edit profile", systemImage: "pencil.line")
                    .font(Typo.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: store.me)
    }

    private func open(_ s: Sheet) {
        profileLog.notice("UPD tap \(s.rawValue, privacy: .public)")
        Haptics.tap()
        sheet = s
    }

    private func count(_ n: Int, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            HStack(spacing: 4) {
                Text(n.formatted(.number.notation(.compactName)))
                    .font(Typo.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(n)))
                Text(label).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
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
            .onAppear { profileLog.notice("UPD appear people \(kind.rawValue, privacy: .public)") }
            .onDisappear { profileLog.notice("UPD disappear people") }
            .navigationTitle(kind.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { PersonProfileSheet(profile: $0) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
