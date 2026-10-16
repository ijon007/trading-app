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
            .compactHeader("Social")
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
            // Grouped by day; whitespace instead of separators.
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groups(feed).enumerated()), id: \.element.title) { g, group in
                    Text(group.title)
                        .font(Typo.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, g == 0 ? Space.xs : Space.lg)
                        .padding(.bottom, Space.xs)
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                        if let person = store.person(item.personID) {
                            row(item, person).staggered(min(g * 3 + i, 6))
                        }
                    }
                }
            }
        }
    }

    private struct Group { let title: String; let items: [ActivityItem] }

    private func groups(_ feed: [ActivityItem]) -> [Group] {
        let cal = Calendar.current
        func title(_ d: Date) -> String {
            if cal.isDateInToday(d) { return "Today" }
            if cal.isDateInYesterday(d) { return "Yesterday" }
            return "Earlier"
        }
        var out: [Group] = []
        for item in feed {
            let t = title(item.date)
            if out.last?.title == t { out[out.count - 1] = Group(title: t, items: out[out.count - 1].items + [item]) }
            else { out.append(Group(title: t, items: [item])) }
        }
        return out
    }

    /// Who (name + time) / what (verb + coin) / how much: three short lines, easy to scan.
    private func row(_ item: ActivityItem, _ person: SocialProfile) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            SocialAvatar(photo: store.photo(for: person), size: 40)
                .overlay(alignment: .bottomTrailing) { badge(item).offset(x: 3, y: 3) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(person.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    Spacer(minLength: Space.xs)
                    Text(item.date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(Typo.caption).foregroundStyle(Theme.textTertiary)
                }
                what(item)
            }
        }
        .padding(.vertical, Space.sm)
        .contentShape(Rectangle())
        .onTapGesture { select(person) }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func what(_ item: ActivityItem) -> some View {
        switch item.kind {
        case .bought(let s), .sold(let s):
            let bought = if case .bought = item.kind { true } else { false }
            HStack(spacing: Space.xxs) {
                Text(bought ? "Bought" : "Sold").foregroundStyle(Theme.textSecondary)
                coin(s)
                Spacer(minLength: Space.xs)
                Text(item.amount.fiat).font(Typo.figure).foregroundStyle(Theme.textPrimary).privateAmount()
            }
            .font(Typo.body)
        case .bigMove(let s, let p):
            HStack(spacing: Space.xxs) {
                Text(p >= 0 ? "Holding up" : "Holding down").foregroundStyle(Theme.textSecondary)
                coin(s)
                Spacer(minLength: Space.xs)
                ReturnText(value: p)
            }
            .font(Typo.body)
        case .followed(let id):
            (Text("Followed ").foregroundStyle(Theme.textSecondary)
             + Text(store.person(id)?.name ?? "someone").foregroundStyle(Theme.textPrimary))
                .font(Typo.body)
        }
    }

    private func coin(_ symbol: String) -> some View {
        HStack(spacing: 4) {
            CoinIcon(symbol: symbol, size: 16)
            Text(symbol).fontWeight(.medium).foregroundStyle(Theme.textPrimary)
        }
    }

    /// Small symbol on the avatar naming the action at a glance.
    private func badge(_ item: ActivityItem) -> some View {
        let (symbol, tint): (String, Color) = switch item.kind {
        case .bought: ("plus", Theme.positive)
        case .sold: ("minus", Theme.negative)
        case .bigMove(_, let p): (p >= 0 ? "arrow.up" : "arrow.down", p >= 0 ? Theme.positive : Theme.negative)
        case .followed: ("person.fill", Theme.textSecondary)
        }
        return Image(systemName: symbol)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(tint))
            .background(Circle().stroke(Theme.background, lineWidth: 2))
    }
}
