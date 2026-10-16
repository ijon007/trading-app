import SwiftUI

struct ExploreView: View {
    enum Filter: String, CaseIterable { case trending = "Trending", top = "Top", gainers = "Gainers" }
    @AppStorage("explore.filter") private var filter: Filter = .trending
    @State private var query = ""
    @State private var selected: Asset?
    /// True from opening a coin until its sheet has fully closed.
    @State private var sheetUp = false
    /// Read so the screen redraws in the new currency.
    @AppStorage(Currency.storageKey) private var currency = Currency.usd.rawValue

    /// Biggest 24h movers up. On a red day nothing is positive, which emptied
    /// the marquee; it now always shows the best performers.
    private var topGainers: [Asset] {
        Array(SampleData.assets.sorted { $0.change24h > $1.change24h }.prefix(8))
    }

    private var gainersTitle: String {
        topGainers.contains { $0.change24h > 0 } ? "Top gainers" : "Top movers"
    }

    private var assets: [Asset] {
        var list = SampleData.assets
        switch filter {
        case .trending: list.sort { abs($0.change24h) > abs($1.change24h) }
        case .top: list.sort { $0.marketCap > $1.marketCap }
        case .gainers: list = topGainers
        }
        guard !query.isEmpty else { return list }
        return SampleData.assets.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.symbol.localizedCaseInsensitiveContains(query)
        }
    }

    private let rowInsets = EdgeInsets(top: Space.row, leading: Space.md, bottom: Space.row, trailing: Space.md)

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    // Plain row, not a Section header, so it scrolls away instead of pinning.
                    sectionTitle(gainersTitle)
                        .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.md, bottom: 0, trailing: Space.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    gainersRow
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: Space.xxs, leading: Space.md, bottom: Space.xs, trailing: Space.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(assets) { asset in
                    AssetRow(asset: asset)
                        .contentShape(Rectangle())
                        .onTapGesture { Haptics.tap(); selected = asset }
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.hairline)
                }
            }
            .listStyle(.plain)
            .marketLoading(!MarketStore.shared.hasLoaded)
            .safeAreaInset(edge: .bottom) { MarketStatusBanner() }
            .animation(.easeOut(duration: 0.25), value: MarketStore.shared.status)
            .environment(\.defaultMinListRowHeight, 0)
            .id(currency) // rows hold plain values; rebuild them on currency change
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Space.lg, for: .scrollContent) // clear of the floating tab bar
            // Even rhythm: search → Top gainers (8) → cards (12, also the shadow room)
            // → filter (16) → list. No extra top margin or section spacing.
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(.compact)
            .sheet(item: $selected, onDismiss: { sheetUp = false }) { CoinDetailSheet(asset: $0) }
            .onChange(of: selected) { _, new in if new != nil { sheetUp = true } }
            .background(Theme.background)
            .navigationTitle("Explore")
            .toolbarTitleDisplayMode(.large)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search coins")
            .scrollDismissesKeyboard(.immediately)
            // Tap on empty space ends search editing; rows and buttons still get their taps.
            .simultaneousGesture(TapGesture().onEnded { Keyboard.dismiss() })
            .sensoryFeedback(.selection, trigger: filter)
            .animation(.spring(response: 0.35, dampingFraction: 1), value: filter)
            .overlay {
                if assets.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Typo.headline).foregroundStyle(Theme.textPrimary)
    }

    private var gainersRow: some View {
        GainersMarquee(assets: topGainers, isCovered: sheetUp) { selected = $0 }
    }
}

/// Slow, seamless auto-scrolling row of gainer cards. Pauses while touched;
/// falls back to a manual scroll when Reduce Motion is on.
struct GainersMarquee: View {
    let assets: [Asset]
    /// A sheet is over the marquee: stop the per-frame timeline so it can't
    /// steal frames from the sheet's own animation.
    var isCovered = false
    var onSelect: (Asset) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var pausedTotal: TimeInterval = 0
    @State private var pauseStart: Date?
    /// Exact width of one set of cards plus the trailing gap to the next set.
    @State private var period: CGFloat = 0

    private let speed: CGFloat = 22 // pt per second

    var body: some View {
        if reduceMotion || assets.isEmpty {
            ScrollView(.horizontal) {
                cards.padding(.horizontal, Space.md)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(.vertical, Space.sm)
        } else {
            TimelineView(.animation(paused: pauseStart != nil || period == 0 || isCovered)) { context in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { copy in
                        cards
                            .padding(.trailing, Space.sm)
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                                if copy == 0 { period = width }
                            }
                            .accessibilityHidden(copy > 0)
                    }
                }
                .fixedSize()
                .offset(x: -offset(at: context.date))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Room above and below for the glass shadow; no clipping, so it fades out naturally.
            .padding(.vertical, Space.sm)
            .frame(height: GainerCard.height + Space.sm * 2)
            .contentShape(.rect)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if pauseStart == nil { pauseStart = .now } }
                    .onEnded { _ in resume() }
            )
            .onChange(of: isCovered) { _, covered in
                if covered { if pauseStart == nil { pauseStart = .now } } else { resume() }
            }
        }
    }

    private func resume() {
        if let p = pauseStart { pausedTotal += Date.now.timeIntervalSince(p) }
        pauseStart = nil
    }

    private var cards: some View {
        HStack(spacing: Space.sm) {
            ForEach(assets) { asset in
                GainerCard(asset: asset).onTapGesture { Haptics.tap(); onSelect(asset) }
            }
        }
    }

    /// Continuous offset wrapped modulo one set's width, so set 2 lands exactly where set 1 began.
    private func offset(at date: Date) -> CGFloat {
        guard period > 0 else { return 0 }
        let now = pauseStart ?? date
        let elapsed = max(0, now.timeIntervalSince(start) - pausedTotal)
        return (CGFloat(elapsed) * speed).truncatingRemainder(dividingBy: period)
    }
}

/// Top gainers card. The gain is the hero: identity on top, the 24h change
/// large in green or red, the sparkline for shape, and the price as quiet context.
struct GainerCard: View {
    static let width: CGFloat = 172
    static let height: CGFloat = 148
    let asset: Asset

    var body: some View {
        let tint = asset.change24h >= 0 ? Theme.positive : Theme.negative
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                CoinIcon(symbol: asset.symbol, size: 22)
                Text(asset.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
                Text(asset.name)
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(asset.change24h.percent)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .tracking(-0.4)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, Space.sm)
            ZStack {
                SparklineArea(values: asset.sparkline)
                    .fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                Sparkline(values: asset.sparkline)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 26)
            .padding(.vertical, Space.xs)
            Spacer(minLength: 0)
            Text(asset.price.fiat)
                .font(Typo.figure)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
    }
}

struct AssetRow: View {
    let asset: Asset
    var body: some View {
        HStack(spacing: Space.sm) {
            CoinIcon(symbol: asset.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(asset.symbol).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.price.fiat).font(Typo.figure).foregroundStyle(Theme.textPrimary)
                ChangeText(value: asset.change24h)
            }
        }
    }
}
