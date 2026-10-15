import SwiftUI
import CoreImage.CIFilterBuiltins

/// Receive drawer: pick asset and network, show a scannable address.
struct ReceiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var holding = SampleData.holdings[0]
    @State private var network = SampleData.holdings[0].asset.networks[0]
    @State private var copied = false

    private var asset: Asset { holding.asset }
    private var address: String { asset.receiveAddress(on: network) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    VStack(spacing: Space.md) {
                        AssetPickerRow(holding: $holding, showBalance: false)
                        Divider().overlay(Theme.hairline)
                        NetworkRow(networks: asset.networks, network: $network)
                    }
                    .transferCard()

                    qrCode
                    addressBlock
                    warning
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onChange(of: holding) { network = holding.asset.networks[0] }
        .sensoryFeedback(.selection, trigger: holding)
        .sensoryFeedback(.selection, trigger: network)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var qrCode: some View {
        // QR stays black on white in both modes so any scanner reads it.
        QRCodeImage(text: address)
            .padding(Space.sm)
            .overlay {
                CoinIcon(symbol: asset.symbol, size: 34)
                    .padding(4)
                    .background(.white, in: .circle)
            }
            .frame(width: 216, height: 216)
            .background(.white, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
            .id(address)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.snappy, value: address)
            .accessibilityLabel("QR code for your \(asset.symbol) address")
    }

    private var addressBlock: some View {
        VStack(spacing: Space.md) {
            VStack(spacing: Space.xxs) {
                Text("Your \(asset.symbol) address")
                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                Text(address)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            HStack(spacing: Space.sm) {
                Button {
                    UIPasteboard.general.string = address
                    Haptics.success()
                    withAnimation(.snappy) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.snappy) { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
                ShareLink(item: address) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            }
            .controlSize(.large)
            .tint(Theme.textPrimary)
            .font(Typo.headline)
        }
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Only send \(asset.symbol) on the \(network) network to this address. Anything else may be lost for good.")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// Crisp QR code rendered with Core Image.
private struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
        }
    }

    private static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "H" // room for the coin logo in the middle
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
