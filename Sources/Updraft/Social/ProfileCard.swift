import SwiftUI

/// Profile header: your avatar, name, @handle and bio, with Edit and Share.
struct ProfileCard: View {
    private var store: SocialStore { .shared }
    @State private var editing = false

    var body: some View {
        VStack(spacing: Space.sm) {
            SocialAvatar(profile: store.me, size: 84, photo: store.photo)
                .overlay(Circle().strokeBorder(Theme.hairline))
            VStack(spacing: 2) {
                Text(store.me.name).titleStyle().foregroundStyle(Theme.textPrimary)
                Text(store.me.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                if !store.me.bio.isEmpty {
                    Text(store.me.bio)
                        .font(Typo.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Space.xxs)
                }
            }
            HStack(spacing: Space.xs) {
                Button { Haptics.tap(); editing = true } label: { Text("Edit profile").frame(minWidth: 96) }
                ShareLink(item: store.profileLink, subject: Text("Add me on Updraft"),
                          message: Text("Add me on Updraft: \(store.me.atHandle)")) {
                    Label("Share", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                }
            }
            .glassButton()
            .controlSize(.small)
            .tint(Theme.textPrimary)
            .font(Typo.callout.weight(.medium))
            .padding(.top, Space.xxs)
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.3), value: store.me)
        .sheet(isPresented: $editing) { EditProfileSheet() }
    }
}
