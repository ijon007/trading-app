import SwiftUI

/// Social tab: search people, then Activity (people you follow) or Leaderboard.
struct SocialView: View {
    enum SocialSection: String, CaseIterable, Identifiable { case activity = "Activity", leaderboard = "Leaderboard"; var id: String { rawValue } }

    @AppStorage("social.section") private var section: SocialSection = .activity
    @State private var query = ""
    @State private var selected: SocialProfile?
    private var store: SocialStore { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    if query.isEmpty {
                        Picker("Section", selection: $section.animation(.smooth(duration: 0.3))) {
                            ForEach(SocialSection.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch section {
                        case .activity: ActivityFeed(select: open).transition(.opacity)
                        case .leaderboard: LeaderboardContent(select: open).transition(.opacity)
                        }
                    } else {
                        results.transition(.opacity)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.background)
            .navigationTitle("Social")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search name or @handle")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .animation(.smooth(duration: 0.25), value: query.isEmpty)
            .sensoryFeedback(.selection, trigger: section)
            .sheet(item: $selected) { PersonProfileSheet(profile: $0) }
        }
    }

    private func open(_ p: SocialProfile) {
        Haptics.tap()
        selected = p
    }

    @ViewBuilder
    private var results: some View {
        let found = store.search(query)
        if found.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, Space.xl)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(found) { p in
                    PersonRow(profile: p) { FollowButton(id: p.id) }
                        .padding(.vertical, Space.sm)
                        .onTapGesture { open(p) }
                    if p.id != found.last?.id { Divider().overlay(Theme.hairline) }
                }
            }
        }
    }
}

/// What people you follow did: buys, sells, big moves and new follows.
private struct ActivityFeed: View {
    let select: (SocialProfile) -> Void
    private var store: SocialStore { .shared }

    var body: some View {
        let feed = store.feed
        if feed.isEmpty {
            ContentUnavailableView("No activity yet", systemImage: "person.2",
                                   description: Text("Follow people to see their trades and moves here."))
                .padding(.top, Space.xl)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(feed.enumerated()), id: \.element.id) { i, item in
                    if let person = store.person(item.personID) {
                        row(item, person)
                            .staggered(min(i, 6))
                        if item.id != feed.last?.id { Divider().overlay(Theme.hairline).padding(.leading, 52) }
                    }
                }
            }
        }
    }

    private func row(_ item: ActivityItem, _ person: SocialProfile) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            SocialAvatar(size: 40)
            VStack(alignment: .leading, spacing: 3) {
                (Text(person.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                 + Text(" " + action(item)).font(Typo.body).foregroundStyle(Theme.textSecondary))
                    .lineLimit(2)
                Text(item.date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: Space.xs)
            trailing(item)
        }
        .padding(.vertical, Space.sm)
        .contentShape(Rectangle())
        .onTapGesture { select(person) }
        .accessibilityElement(children: .combine)
    }

    private func action(_ item: ActivityItem) -> String {
        switch item.kind {
        case .bought(let s): "bought \(s)"
        case .sold(let s): "sold \(s)"
        case .bigMove(let s, let p): "\(s) \(p >= 0 ? "jumped" : "dropped")"
        case .followed(let id): "followed \(store.person(id)?.name ?? "someone")"
        }
    }

    @ViewBuilder
    private func trailing(_ item: ActivityItem) -> some View {
        switch item.kind {
        case .bought(let s), .sold(let s):
            CoinIcon(symbol: s, size: 28)
        case .bigMove(let s, let p):
            HStack(spacing: Space.xs) {
                ReturnText(value: p)
                CoinIcon(symbol: s, size: 28)
            }
        case .followed:
            Image(systemName: "person.badge.plus")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
        }
    }
}
