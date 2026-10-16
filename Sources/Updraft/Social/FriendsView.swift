import SwiftUI

/// Friends: requests to accept, add by @handle or link, and your friends with today's return.
struct FriendsView: View {
    private var store: SocialStore { .shared }
    @State private var query = ""
    @State private var found: SocialProfile?
    @State private var searching = false
    @State private var notFound = false
    @State private var showingQR = false
    @State private var selected: SocialProfile?
    @FocusState private var searchFocused: Bool

    var body: some View {
        List {
            Section {
                addField
                if let found { resultRow(found).transition(.opacity.combined(with: .move(edge: .top))) }
                if notFound {
                    Text("No one with that handle.").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            } footer: {
                HStack(spacing: Space.md) {
                    ShareLink(item: store.profileLink, message: Text("Add me on Updraft: \(store.me.atHandle)")) {
                        Label("Share my link", systemImage: "link")
                    }
                    Button { Haptics.tap(); showingQR = true } label: { Label("My QR", systemImage: "qrcode") }
                }
                .font(Typo.caption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, Space.xxs)
            }

            if !store.requests.isEmpty {
                Section("Requests") {
                    ForEach(store.requests) { request in
                        requestRow(request).transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }

            Section(store.friends.isEmpty ? "" : "Friends · \(store.friends.count)") {
                if store.friends.isEmpty {
                    Text("Add friends to compare returns.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                ForEach(store.friends) { friend in
                    Button { Haptics.tap(); selected = friend } label: { friendRow(friend) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                Haptics.warning()
                                withAnimation(.snappy) { store.remove(friend) }
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: store.friends)
        .animation(.snappy, value: store.requests)
        .animation(.snappy, value: found)
        .sheet(item: $selected) { FriendProfileSheet(profile: $0) }
        .sheet(isPresented: $showingQR) { MyQRSheet() }
    }

    // MARK: Add

    private var addField: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "at").foregroundStyle(Theme.textTertiary)
            TextField("Add by handle", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit(search)
                .onChange(of: query) { found = nil; notFound = false }
            if searching {
                ProgressView().controlSize(.small)
            } else if !query.isEmpty {
                Button("Find") { search() }
                    .font(Typo.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .font(Typo.body)
    }

    private func search() {
        let h = SocialStore.normalized(query)
        guard SocialStore.isValidHandle(h) else { Haptics.error(); notFound = true; return }
        searching = true
        Task {
            let result = await store.service.lookup(handle: h)
            searching = false
            if let result, result.handle != store.me.handle { found = result } else { notFound = true; Haptics.error() }
        }
    }

    private func resultRow(_ p: SocialProfile) -> some View {
        HStack(spacing: Space.sm) {
            SocialAvatar(profile: p, size: 40)
            nameStack(p)
            Spacer()
            if store.isFriend(p.handle) {
                Text("Friends").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            } else if store.pending.contains(p.handle) {
                Label("Sent", systemImage: "clock").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            } else {
                Button { Haptics.success(); store.sendRequest(to: p) } label: { Text("Add") }
                    .glassProminentButton()
                    .controlSize(.small)
            }
        }
        .animation(.snappy, value: store.pending)
    }

    // MARK: Rows

    private func requestRow(_ r: FriendRequest) -> some View {
        HStack(spacing: Space.sm) {
            SocialAvatar(profile: r.profile, size: 40)
            nameStack(r.profile)
            Spacer()
            Button { Haptics.tap(); withAnimation(.snappy) { store.decline(r) } } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(Theme.textSecondary)
            .accessibilityLabel("Decline \(r.profile.name)")
            Button { Haptics.success(); withAnimation(.snappy) { store.accept(r) } } label: {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
            }
            .glassProminentButton()
            .buttonBorderShape(.circle)
            .accessibilityLabel("Accept \(r.profile.name)")
        }
    }

    private func friendRow(_ p: SocialProfile) -> some View {
        HStack(spacing: Space.sm) {
            SocialAvatar(profile: p, size: 40)
            nameStack(p)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                ReturnText(value: p.returnFor(.day))
                Text("today").font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private func nameStack(_ p: SocialProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
            Text(p.atHandle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
        }
    }
}

/// Your profile QR for a friend to scan.
struct MyQRSheet: View {
    private var store: SocialStore { .shared }

    var body: some View {
        VStack(spacing: Space.md) {
            SocialAvatar(profile: store.me, size: 56, photo: store.photo)
            VStack(spacing: 2) {
                Text(store.me.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(store.me.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            QRCodeImage(text: store.profileLink.absoluteString)
                .frame(width: 200, height: 200)
                .padding(Space.sm)
                .background(Color.white, in: .rect(cornerRadius: Radius.md))
            ShareLink(item: store.profileLink) { Label("Share link", systemImage: "square.and.arrow.up") }
                .glassButton()
                .tint(Theme.textPrimary)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .background(Theme.background)
    }
}
