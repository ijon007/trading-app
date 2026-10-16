import SwiftUI

/// You and the people you follow, ranked by return % over 1D/1W/1M/All.
/// Podium for the top 3, then rows; your row is outlined.
struct LeaderboardContent: View {
    let select: (SocialProfile) -> Void
    @State private var period: LeaderPeriod = .day
    @State private var raised = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: SocialStore { .shared }

    private var rise: Animation { reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.25) }

    var body: some View {
        let board = store.board(period)
        VStack(spacing: Space.lg) {
            HStack(spacing: Space.xxs) {
                ForEach(LeaderPeriod.allCases) { p in
                    Button { period = p } label: {
                        Text(p.rawValue)
                            .font(Typo.callout.weight(.medium))
                            .foregroundStyle(period == p ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 6)
                            .background {
                                if period == p { Capsule().fill(Theme.textPrimary).matchedGeometryEffect(id: "period", in: ns) }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .animation(.snappy(duration: 0.3), value: period)

            if board.count > 1 {
                podium(Array(board.prefix(3)))
            }

            LazyVStack(spacing: Space.xxs) {
                ForEach(board.dropFirst(min(3, board.count))) { row($0) }
            }
            .animation(.spring(duration: 0.45, bounce: 0.15), value: board.map(\.id))

            if !store.hasPublicAccounts {
                Label("Your accounts are private, so you're not on the board.", systemImage: "lock")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sensoryFeedback(.selection, trigger: period)
        .onChange(of: period) { replay() }
        .onAppear { replay() }
    }

    @Namespace private var ns

    private func replay() {
        raised = false
        withAnimation(rise) { raised = true }
    }

    // MARK: Podium

    /// Fixed slots: #2 left (medium), #1 center (tallest), #3 right (shortest).
    private func podium(_ top: [SocialStore.Ranked]) -> some View {
        HStack(alignment: .bottom, spacing: Space.sm) {
            ForEach([1, 0, 2], id: \.self) { index in
                if top.indices.contains(index) {
                    let entry = top[index]
                    column(entry, place: index).id(entry.id)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
        .padding(.top, Space.xl)
    }

    /// place: 0 = first, 1 = second, 2 = third (by position, so ties still fit the podium).
    private func column(_ entry: SocialStore.Ranked, place: Int) -> some View {
        let height: CGFloat = [124, 96, 72][place]
        let avatar: CGFloat = [64, 52, 46][place]
        let delay = [0.1, 0.0, 0.18][place] // 2nd, then 1st, then 3rd
        return VStack(spacing: Space.xs) {
            SocialAvatar(photo: store.photo(for: entry.profile), size: avatar)
                .overlay {
                    if entry.isMe { Circle().strokeBorder(Theme.accent, lineWidth: 2).padding(-4) }
                }
                .overlay(alignment: .top) {
                    if place == 0 {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .offset(y: -22)
                            .symbolEffect(.bounce, value: raised)
                    }
                }
            Text(entry.isMe ? "You" : entry.profile.name.split(separator: " ").first.map(String.init) ?? "")
                .font(Typo.callout.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            PnLText(value: entry.profile.pnlFor(period), font: Typo.caption.weight(.medium))
                .animation(.snappy, value: period)
            UnevenRoundedRectangle(topLeadingRadius: Radius.md, topTrailingRadius: Radius.md)
                .fill(Theme.surface)
                .overlay(alignment: .top) {
                    Text("\(entry.rank)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, Space.sm)
                        .opacity(raised ? 1 : 0)
                }
                .frame(height: raised ? height : 6)
                .animation(rise.delay(delay), value: raised)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !entry.isMe { select(entry.profile) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.isMe ? "you" : entry.profile.name), \(entry.profile.pnlFor(period).fiat)")
    }

    // MARK: Rows

    private func row(_ entry: SocialStore.Ranked) -> some View {
        HStack(spacing: Space.sm) {
            Text("\(entry.rank)")
                .font(Typo.figure)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 22, alignment: .leading)
                .contentTransition(.numericText(value: Double(entry.rank)))
            SocialAvatar(photo: store.photo(for: entry.profile), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isMe ? "You" : entry.profile.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(entry.profile.atHandle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            RankChange(change: entry.change)
            VStack(alignment: .trailing, spacing: Space.xxs) {
                PnLText(value: entry.profile.pnlFor(period), font: Typo.headline)
                if !entry.profile.hidesHoldings, !entry.profile.topHoldings.isEmpty {
                    CoinStack(symbols: entry.profile.topHoldings.map(\.symbol), total: entry.profile.holdingCount)
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, Space.sm)
        .padding(.horizontal, Space.sm)
        .overlay {
            if entry.isMe { RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Theme.hairline) }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !entry.isMe { select(entry.profile) } }
    }
}
