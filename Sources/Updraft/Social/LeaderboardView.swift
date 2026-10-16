import SwiftUI

/// Friends ranked by return % over 1D/1W/1M/All. Podium for the top 3,
/// then the rest; your rank stays pinned at the bottom.
struct LeaderboardView: View {
    @State private var period: LeaderPeriod = .day
    @State private var raised = false
    @State private var selected: SocialProfile?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: SocialStore { .shared }

    private var board: [SocialStore.Ranked] { store.board(period) }

    var body: some View {
        let board = self.board
        ScrollView {
            VStack(spacing: Space.lg) {
                Picker("Period", selection: $period) {
                    ForEach(LeaderPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                podium(Array(board.prefix(3)))

                LazyVStack(spacing: 0) {
                    ForEach(board.dropFirst(3)) { entry in
                        row(entry)
                        if entry.id != board.last?.id { Divider().overlay(Theme.hairline) }
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
            .animation(.spring(duration: 0.45, bounce: 0.15), value: board.map(\.id))
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if let me = board.first(where: \.isMe) { pinned(me) }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: period)
        .onChange(of: period) { replay() }
        .onAppear { replay() }
        .sheet(item: $selected) { FriendProfileSheet(profile: $0) }
    }

    /// Podium bars rise again on appear and when the period changes.
    private func replay() {
        raised = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.3)) { raised = true }
    }

    // MARK: Podium

    private func podium(_ top: [SocialStore.Ranked]) -> some View {
        // Visual order: 2nd, 1st, 3rd.
        let order = [1, 0, 2].compactMap { top.indices.contains($0) ? top[$0] : nil }
        return HStack(alignment: .bottom, spacing: Space.sm) {
            ForEach(Array(order.enumerated()), id: \.element.id) { i, entry in
                podiumColumn(entry, height: [96, 128, 76][entry.rank - 1], delay: Double(i) * 0.06)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.md)
    }

    private func podiumColumn(_ entry: SocialStore.Ranked, height: CGFloat, delay: Double) -> some View {
        VStack(spacing: Space.xs) {
            SocialAvatar(profile: entry.profile, size: entry.rank == 1 ? 60 : 48,
                         photo: entry.isMe ? store.photo : nil)
                .overlay(Circle().strokeBorder(entry.isMe ? Theme.accent : Theme.hairline, lineWidth: entry.isMe ? 2 : 1).padding(-3))
                .overlay(alignment: .top) {
                    if entry.rank == 1 {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .offset(y: -20)
                            .symbolEffect(.bounce, value: raised)
                    }
                }
            Text(entry.isMe ? "You" : entry.profile.name.split(separator: " ").first.map(String.init) ?? "")
                .font(Typo.callout.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            ReturnText(value: entry.profile.returnFor(period))
                .animation(.snappy, value: period)
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: Radius.md, topTrailingRadius: Radius.md)
                    .fill(Theme.surface)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: Radius.md, topTrailingRadius: Radius.md)
                        .strokeBorder(Theme.hairline))
                Text("\(entry.rank)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Space.sm)
            }
            .frame(height: raised ? height : 8)
            .animation((reduceMotion ? Animation.easeOut(duration: 0.2) : Animation.spring(duration: 0.6, bounce: 0.3)).delay(delay), value: raised)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !entry.isMe { Haptics.tap(); selected = entry.profile } }
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
            RankChange(change: entry.change)
            SocialAvatar(profile: entry.profile, size: 36, photo: entry.isMe ? store.photo : nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isMe ? "You" : entry.profile.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(entry.profile.atHandle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ReturnText(value: entry.profile.returnFor(period))
        }
        .padding(.vertical, Space.row)
        .padding(.horizontal, entry.isMe ? Space.sm : 0)
        .background(entry.isMe ? Theme.surface : .clear, in: .rect(cornerRadius: Radius.md))
        .contentShape(Rectangle())
        .onTapGesture { if !entry.isMe { Haptics.tap(); selected = entry.profile } }
    }

    private func pinned(_ me: SocialStore.Ranked) -> some View {
        HStack(spacing: Space.sm) {
            Text("#\(me.rank)")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: Double(me.rank)))
            RankChange(change: me.change)
            SocialAvatar(profile: me.profile, size: 32, photo: store.photo)
            Text("You").font(Typo.headline).foregroundStyle(Theme.textPrimary)
            Spacer()
            ReturnText(value: me.profile.returnFor(period), font: Typo.headline)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
        .animation(.snappy, value: me.rank)
        .animation(.snappy, value: period)
    }
}
