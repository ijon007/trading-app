import SwiftUI

/// Which transfer drawer is open from Home.
enum TransferKind: String, Identifiable {
    case send, receive, swap
    var id: String { rawValue }
}

extension Asset {
    /// Networks this asset can move on (sample). First is the default.
    var networks: [String] {
        switch symbol {
        case "BTC": ["Bitcoin"]
        case "ETH": ["Ethereum", "Arbitrum", "Base"]
        case "LINK": ["Ethereum", "Arbitrum"]
        case "SOL": ["Solana"]
        case "ADA": ["Cardano"]
        default: [name]
        }
    }

    /// Sample deposit address for a network.
    func receiveAddress(on network: String) -> String {
        switch network {
        case "Bitcoin": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
        case "Solana": "7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV"
        case "Cardano": "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3jcu5d8ps7zex2k2xt3uqxgjq"
        default: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
        }
    }

    /// Estimated network fee in USD (sample).
    func networkFee(on network: String) -> Double {
        switch network {
        case "Bitcoin": 2.40
        case "Ethereum": 1.85
        case "Arbitrum": 0.08
        case "Base": 0.03
        case "Solana": 0.01
        case "Cardano": 0.17
        default: 0.25
        }
    }
}

extension Double {
    /// Crypto quantity, up to 6 decimals.
    var units: String { formatted(.number.precision(.fractionLength(0...6))) }
}

extension View {
    /// Group inside transfer drawers: no fill, so it sits on the sheet's own
    /// material in light and dark, outlined by a hairline (glass is kept for controls).
    func transferCard() -> some View {
        padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

extension SampleData {
    /// Every listed asset as a holding (amount 0 when not held), for "to" pickers.
    static var allAssetsAsHoldings: [Holding] {
        assets.map { a in holdings.first { $0.asset.id == a.id } ?? Holding(asset: a, amount: 0) }
    }
}

/// Coin selector row: logo, name and balance. Opens `CoinSelectorList`.
struct AssetPickerRow: View {
    @Binding var holding: Holding
    var showBalance = true
    var options: [Holding] = SampleData.holdings
    var title = "Select coin"
    @State private var isOpen = false

    var body: some View {
        Button {
            Haptics.tap()
            isOpen = true
        } label: {
            HStack(spacing: Space.sm) {
                CoinIcon(symbol: holding.asset.symbol, size: 36)
                    .id(holding.id)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(showBalance ? "Balance \(holding.amount.units) \(holding.asset.symbol)" : holding.asset.symbol)
                        .font(Typo.figure).foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                        .privateAmount()
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .animation(.snappy, value: holding)
            .animation(.snappy, value: isOpen)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coin, \(holding.asset.name)")
        .accessibilityHint("Opens the coin list")
        .sheet(isPresented: $isOpen) {
            CoinSelectorList(selection: $holding, options: options, title: title)
        }
    }
}

/// Custom coin list with logos, balances and a checkmark on the current pick.
struct CoinSelectorList: View {
    @Binding var selection: Holding
    let options: [Holding]
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(options) { h in
                        Button {
                            withAnimation(.snappy) { selection = h }
                            dismiss()
                        } label: {
                            row(h)
                        }
                        .buttonStyle(CoinRowStyle())
                        if h.id != options.last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 64)
                        }
                    }
                }
                .padding(.horizontal, Space.xs)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ h: Holding) -> some View {
        let isSelected = h.id == selection.id
        return HStack(spacing: Space.sm) {
            CoinIcon(symbol: h.asset.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(h.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Text(h.asset.symbol).font(Typo.figure).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if h.amount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(h.value.fiat).font(Typo.figure).foregroundStyle(Theme.textPrimary).privateAmount()
                    Text("\(h.amount.units) \(h.asset.symbol)").font(Typo.caption).foregroundStyle(Theme.textSecondary).privateAmount()
                }
            }
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .opacity(isSelected ? 1 : 0)
                .frame(width: 18)
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.row)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Soft highlight while a coin row is pressed.
private struct CoinRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.textPrimary.opacity(configuration.isPressed ? 0.06 : 0), in: .rect(cornerRadius: Radius.md))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Network picker row; static text when the asset has one network.
struct NetworkRow: View {
    let networks: [String]
    @Binding var network: String

    var body: some View {
        HStack {
            Text("Network").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            Spacer()
            if networks.count > 1 {
                Picker("Network", selection: $network) {
                    ForEach(networks, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.textPrimary)
            } else {
                Text(network).font(Typo.figure).foregroundStyle(Theme.textPrimary)
            }
        }
    }
}
