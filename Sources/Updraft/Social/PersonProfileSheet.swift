import SwiftUI

/// Someone's profile: follow, returns per period, rank, and top holdings
/// (unless they hide them). Only percentages, never amounts.
struct PersonProfileSheet: View {
    let profile: SocialProfile
    @State private var period: LeaderPeriod = .day
    @State private var scrub: Int?
    private var store: SocialStore { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(alignment: .top) {
                    SocialAvatar(size: 72)
                    Spacer()
                    if profile.id != store.me.id { FollowButton(id: profile.id) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).titleStyle().foregroundStyle(Theme.textPrimary)
                    Text(profile.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    if !profile.bio.isEmpty {
                        Text(profile.bio).font(Typo.body).foregroundStyle(Theme.textPrimary).padding(.top, Space.xs)
                    }
                    HStack(spacing: Space.md) {
                        count(profile.followerCount + (store.isFollowing(profile.id) ? 1 : 0), "Followers")
                        count(profile.followingCount, "Following")
                    }
                    .padding(.top, Space.xs)
                }
                .staggered(0)

                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        PnLText(value: profile.pnlFor(period), font: Typo.numeral)
                            .animation(.snappy, value: period)
                        ReturnText(value: profile.returnFor(period), font: Typo.caption)
                            .animation(.snappy, value: period)
                        Spacer()
                        if let rank = store.board(period).first(where: { $0.id == profile.id })?.rank {
                            Text("#\(rank) in your board")
                                .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                                .contentTransition(.numericText(value: Double(rank)))
                                .animation(.snappy, value: rank)
                        }
                    }
                    chart
                    Picker("Period", selection: $period) {
                        ForEach(LeaderPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .staggered(1)

                holdings.staggered(2)
            }
            .padding(Space.md)
            .padding(.top, Space.sm)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .sensoryFeedback(.selection, trigger: period)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Account value line (same chart as Home), tinted by the period's return.
    private var chart: some View {
        let points = store.service.series(for: profile, period: period)
        return ScrubbableChart(points: points, tint: profile.returnFor(period) >= 0 ? Theme.positive : Theme.negative,
                               selectedIndex: $scrub)
            .frame(height: 140)
            .padding(.horizontal, -Space.md) // edge to edge, like Home
            .id(period)
            .transition(.opacity)
            .animation(.smooth(duration: 0.3), value: period)
    }

    private func count(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(n.formatted(.number.notation(.compactName))).font(Typo.callout.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: Double(n)))
            Text(label).font(Typo.callout).foregroundStyle(Theme.textSecondary)
        }
        .animation(.snappy, value: n)
    }

    private var holdings: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Top holdings").font(Typo.headline).foregroundStyle(Theme.textPrimary)
            if profile.hidesHoldings || profile.topHoldings.isEmpty {
                Label("Holdings are private.", systemImage: "lock")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(profile.topHoldings, id: \.symbol) { h in
                    HStack(spacing: Space.sm) {
                        CoinIcon(symbol: h.symbol, size: 28)
                        Text(h.symbol).font(Typo.body).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        ShareBar(share: h.share)
                        Text(h.share.formatted(.percent.precision(.fractionLength(0))))
                            .font(Typo.figure).foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
    }
}

/// Thin portfolio-share bar that grows in on appear.
private struct ShareBar: View {
    let share: Double
    @State private var shown = false

    var body: some View {
        Capsule().fill(Theme.hairline)
            .frame(width: 80, height: 4)
            .overlay(alignment: .leading) {
                Capsule().fill(Theme.textPrimary).frame(width: 80 * (shown ? share : 0), height: 4)
            }
            .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.1).delay(0.15)) { shown = true } }
    }
}
