import SwiftUI

/// Which transfer drawer is open from Home.
enum TransferKind: String, Identifiable {
    case send, receive
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

/// Asset picker row shared by Send and Receive.
struct AssetPickerRow: View {
    @Binding var holding: Holding
    var showBalance = true

    var body: some View {
        Menu {
            Picker("Asset", selection: $holding) {
                ForEach(SampleData.holdings) { h in
                    Text("\(h.asset.name) · \(h.amount.units) \(h.asset.symbol)").tag(h)
                }
            }
        } label: {
            HStack(spacing: Space.sm) {
                CoinIcon(symbol: holding.asset.symbol, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    if showBalance {
                        Text("Balance \(holding.amount.units) \(holding.asset.symbol)")
                            .font(Typo.figure).foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(holding.asset.symbol).font(Typo.figure).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Asset, \(holding.asset.name)")
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
