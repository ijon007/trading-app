import SwiftUI

struct ExploreView: View {
    enum Filter: String, CaseIterable { case trending = "Trending", top = "Top", gainers = "Gainers" }
    @State private var filter: Filter = .trending
    @State private var query = ""

    private var topGainers: [Asset] {
        SampleData.assets.filter { $0.change24h > 0 }.sorted { $0.change24h > $1.change24h }
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
                    Section {
                        gainersRow
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } header: {
                        sectionTitle("Top gainers")
                    }

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: Space.md, leading: Space.md, bottom: Space.xs, trailing: Space.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(assets) { asset in
                    AssetRow(asset: asset)
                        .contentShape(Rectangle())
                        .onTapGesture { Haptics.tap() }
                        .listRowInsets(rowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.hairline)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Explore")
            .searchable(text: $query, placement: .toolbar, prompt: "Search coins")
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
        ScrollView(.horizontal) {
            HStack(spacing: Space.sm) {
                ForEach(topGainers) { asset in
                    GainerCard(asset: asset)
                        .onTapGesture { Haptics.tap() }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

/// Compact liquid glass card for the top gainers carousel.
struct GainerCard: View {
    let asset: Asset
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                CoinIcon(symbol: asset.symbol, size: 28)
                Text(asset.symbol).font(Typo.headline).foregroundStyle(Theme.textPrimary)
            }
            Spacer(minLength: 0)
            Text(asset.price.fiat)
                .font(Typo.figure)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ChangePill(value: asset.change24h)
        }
        .padding(Space.md)
        .frame(width: 148, height: 136, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.lg))
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
