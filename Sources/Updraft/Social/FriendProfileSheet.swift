import SwiftUI

/// A friend's profile: returns per period and top holdings (unless they hide them).
/// Only percentages are shown, never amounts.
struct FriendProfileSheet: View {
    let profile: SocialProfile
    @Environment(\.dismiss) private var dismiss
    @State private var period: LeaderPeriod = .day
    @State private var confirmRemove = false
    private var store: SocialStore { .shared }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.xs) {
                    SocialAvatar(profile: profile, size: 72)
                    Text(profile.name).titleStyle().foregroundStyle(Theme.textPrimary)
                    Text(profile.atHandle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    if !profile.bio.isEmpty {
                        Text(profile.bio).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .staggered(0)

                VStack(spacing: Space.sm) {
                    ReturnText(value: profile.returnFor(period), font: Typo.numeral)
                        .animation(.snappy, value: period)
                    Picker("Period", selection: $period) {
                        ForEach(LeaderPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let rank = store.board(period).first(where: { $0.id == profile.id })?.rank {
                        Text("#\(rank) among your friends")
                            .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            .contentTransition(.numericText(value: Double(rank)))
                            .animation(.snappy, value: rank)
                    }
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

    @ViewBuilder
    private var holdings: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Top holdings").font(Typo.headline).foregroundStyle(Theme.textPrimary)
            if profile.hidesHoldings || profile.topHoldings.isEmpty {
                Label("\(profile.name.split(separator: " ").first.map(String.init) ?? "They") keeps holdings private.",
                      systemImage: "lock")
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
