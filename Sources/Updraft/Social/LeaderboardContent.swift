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

    private func podium(_ top: [SocialStore.Ranked]) -> some View {
        let order = [1, 0, 2].compactMap { top.indices.contains($0) ? top[$0] : nil } // 2nd, 1st, 3rd
        return HStack(alignment: .bottom, spacing: Space.sm) {
            ForEach(Array(order.enumerated()), id: \.element.id) { i, entry in
                column(entry, height: [92, 120, 72][entry.rank - 1], delay: Double(i) * 0.06)
            }
        }
        .padding(.top, Space.lg)
    }

    private func column(_ entry: SocialStore.Ranked, height: CGFloat, delay: Double) -> some View {
        VStack(spacing: Space.xs) {
            SocialAvatar(photo: store.photo(for: entry.profile), size: entry.rank == 1 ? 60 : 48)
                .overlay {
                    if entry.isMe { Circle().strokeBorder(Theme.accent, lineWidth: 2).padding(-4) }
                }
                .overlay(alignment: .top) {
                    if entry.rank == 1 {
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
            ReturnText(value: entry.profile.returnFor(period))
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
        .accessibilityLabel("Rank \(entry.rank), \(entry.isMe ? "you" : entry.profile.name), \(entry.profile.returnFor(period).percent)")
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
            ReturnText(value: entry.profile.returnFor(period))
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
