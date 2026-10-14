import SwiftUI

struct ExploreView: View {
    enum Filter: String, CaseIterable { case trending = "Trending", top = "Top", gainers = "Gainers" }
    @State private var filter: Filter = .trending
    @State private var query = ""

    private var assets: [Asset] {
        var list = SampleData.assets
        switch filter {
        case .trending: list.sort { abs($0.change24h) > abs($1.change24h) }
        case .top: list.sort { $0.marketCap > $1.marketCap }
        case .gainers: list = list.filter { $0.change24h > 0 }.sorted { $0.change24h > $1.change24h }
        }
        guard !query.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.symbol.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    ForEach(assets) { AssetRow(asset: $0) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Explore")
            .searchable(text: $query, prompt: "Search assets")
            .onChange(of: filter) { Haptics.select() }
            .overlay {
                if assets.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
    }
}

struct AssetRow: View {
    let asset: Asset
    var body: some View {
        HStack(spacing: Space.sm) {
            CoinIcon(symbol: asset.symbol)
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
        .padding(.vertical, Space.xxs)
    }
}
