import SwiftUI

/// Preview and share a P&L card for a held coin.
struct PnLShareSheet: View {
    let asset: Asset
    let position: Position

    @AppStorage(PrivacyMode.storageKey) private var privacyOn = false
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.displayScale) private var displayScale
    @State private var timeframe: Timeframe = .day
    @State private var style: Appearance = .dark
    @State private var hideAmounts = false
    @State private var image: Image?

    private var summary: PnLSummary { PnLSummary(asset: asset, position: position, timeframe: timeframe) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    card
                        .environment(\.colorScheme, style.scheme)
                        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
                        .animation(.smooth(duration: 0.3), value: style)
                        .animation(.smooth(duration: 0.3), value: hideAmounts)
                        .padding(.top, Space.md)

                    VStack(spacing: Space.md) {
                        Picker("Timeframe", selection: $timeframe) {
                            ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Style", selection: $style) {
                            ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Hide amounts, show % only", isOn: $hideAmounts)
                            .font(Typo.callout)
                            .foregroundStyle(Theme.textPrimary)
                            .tint(Theme.toggleTint)
                    }
                    .padding(.horizontal, Space.md)
                }
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Share P&L")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { shareButton }
            .sensoryFeedback(.selection, trigger: timeframe)
            .sensoryFeedback(.selection, trigger: style)
            .sensoryFeedback(.selection, trigger: hideAmounts)
        }
        .onAppear {
            hideAmounts = privacyOn
            style = Appearance(systemScheme)
        }
        .task(id: renderKey) { render() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var card: PnLCard { PnLCard(asset: asset, summary: summary, hideAmounts: hideAmounts) }

    private var renderKey: String { "\(timeframe.rawValue)|\(style.rawValue)|\(hideAmounts)" }

    private func render() {
        let renderer = ImageRenderer(content:
            card.padding(Space.lg)
                .background(Theme.background)
                .environment(\.colorScheme, style.scheme))
        renderer.scale = max(displayScale, 3)
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }

    @ViewBuilder private var shareButton: some View {
        Group {
            if let image {
                ShareLink(item: image,
                          preview: SharePreview("\(asset.name) P&L", image: image)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(Typo.headline)
                        .frame(maxWidth: .infinity)
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .glassProminentButton()
        .controlSize(.large)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
    }
}
