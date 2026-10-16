import SwiftUI
import Charts
import Photos

/// Share your profile as an image: swipe between Portfolio, Top holdings and
/// Top mover cards, then share, copy or save the one on screen.
struct ProfileShareSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case portfolio = "Portfolio", holdings = "Top holdings", mover = "Top mover"
        var id: String { rawValue }
    }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale
    @AppStorage(PrivacyMode.storageKey) private var privacyOn = false
    @State private var page: Kind = .portfolio
    @State private var rendered: UIImage?
    @State private var feedback: String?
    @State private var height: CGFloat = 520
    /// Card side: screen width minus the standard 16pt margins.
    private var side: CGFloat { UIScreen.main.bounds.width - 2 * Space.md }

    var body: some View {
        VStack(spacing: Space.md) {
            // Card title lives here, not on the card; follows the swipe.
            Text(page.rawValue)
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
                .animation(.snappy, value: page)
                .padding(.top, Space.lg)

            // Edge to edge so pages don't clip the card; each page insets the
            // card 16pt and leaves room below for its shadow.
            TabView(selection: $page) {
                ForEach(Kind.allCases) { kind in
                    ShareCard(kind: kind, hideAmounts: privacyOn, side: side)
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                        .padding(.horizontal, Space.md)
                        .padding(.top, Space.xs)
                        .padding(.bottom, Space.lg)
                        .tag(kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: side + Space.xs + Space.lg)
            .padding(.horizontal, -Space.md)

            HStack(spacing: Space.xs) {
                ForEach(Kind.allCases) { kind in
                    Capsule()
                        .fill(kind == page ? Theme.textPrimary : Theme.textTertiary.opacity(0.5))
                        .frame(width: kind == page ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: page)

            actions
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
        .fixedSize(horizontal: false, vertical: true)
        // Drawer as tall as title + card + dots + buttons.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0.rounded() }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .sensoryFeedback(.selection, trigger: page)
        .task(id: "\(page.rawValue)|\(privacyOn)|\(scheme == .dark)") { render() }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
    }

    private var actions: some View {
        HStack(spacing: Space.lg) {
            if let rendered {
                let image = Image(uiImage: rendered)
                ShareLink(item: image, preview: SharePreview("My Updraft \(page.rawValue.lowercased())", image: image)) {
                    action("Share", "square.and.arrow.up")
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            } else {
                action("Share", "square.and.arrow.up").opacity(0.4)
            }
            Button { copy() } label: { action(feedback == "Copied" ? "Copied" : "Copy", feedback == "Copied" ? "checkmark" : "doc.on.doc") }
            Button { save() } label: {
                switch feedback {
                case "Saved": action("Saved", "checkmark")
                case "No access": action("No access", "exclamationmark.triangle")
                default: action("Save", "arrow.down.to.line")
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(rendered == nil)
    }

    private func action(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive(), in: .circle)
            Text(title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                .contentTransition(.opacity)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(width: 64) // fixed width so the group stays centered as labels change
        .animation(.snappy, value: title)
    }

    private func render() {
        let renderer = ImageRenderer(content:
            ShareCard(kind: page, hideAmounts: privacyOn, side: side, export: true)
                .environment(\.colorScheme, scheme))
        renderer.scale = max(displayScale, 3)
        rendered = renderer.uiImage
    }

    private func copy() {
        guard let rendered else { return }
        UIPasteboard.general.image = rendered
        flash("Copied")
    }

    /// Asks for add-only Photos access; says so when it's denied instead of faking "Saved".
    private func save() {
        guard let rendered else { return }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                flash("No access", success: false)
                return
            }
            do {
                try await Self.addToPhotos(rendered)
                flash("Saved")
            } catch {
                flash("No access", success: false)
            }
        }
    }

    /// Nonisolated on purpose: Photos runs the change block on its own queue.
    /// Written inline in this @MainActor view, the closure inherited MainActor
    /// isolation and Swift 6's runtime check trapped (dispatch_assert_queue_fail).
    nonisolated private static func addToPhotos(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private func flash(_ text: String, success: Bool = true) {
        if success { Haptics.success() } else { Haptics.error() }
        feedback = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if feedback == text { feedback = nil }
        }
    }
}

/// One branded share card. Fixed size so the image is consistent.
struct ShareCard: View {
    let kind: ProfileShareSheet.Kind
    var hideAmounts = false
    /// Square side in points.
    var side: CGFloat = 343
    /// Export: fill the whole square, no rounded corners or border.
    var export = false
    private var store: SocialStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            // Body flexes to fill the square; branding pinned to the bottom.
            Group {
                switch kind {
                case .portfolio: portfolio
                case .holdings: holdings
                case .mover: mover
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(side * 0.065)
        .frame(width: side, height: side, alignment: .topLeading)
        .background(Theme.surface, in: .rect(cornerRadius: export ? 0 : Radius.xl))
        .overlay {
            if !export { RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Theme.hairline, lineWidth: 1) }
        }
    }

    private var header: some View {
        HStack(spacing: Space.xs) {
            SocialAvatar(photo: store.photo, size: side * 0.11)
            VStack(alignment: .leading, spacing: 0) {
                Text(store.me.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(store.me.atHandle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            // Watermark, trailing in the header row.
            // ~1.5x the old caption size, scaled to the card so the export matches.
            HStack(spacing: side * 0.016) {
                UpdraftLogoShape().frame(width: side * 0.052, height: side * 0.07)
                Text("Updraft")
                    .font(.system(size: side * 0.05, weight: .semibold))
                    .tracking(-side * 0.0008)
            }
            .foregroundStyle(Theme.textSecondary)
        }
    }


    private var publicHoldings: [Holding] { store.publicHoldings.filter { $0.value > 0 } }

    // MARK: Portfolio

    private var portfolio: some View {
        let points = SampleData.balanceSeries(.day, holdings: store.publicHoldings).map(\.price)
        let total = publicHoldings.reduce(0) { $0 + $1.value }
        let change = store.myReturns()[.day] ?? 0
        let pnl = total - total / (1 + change / 100)
        let tint = change >= 0 ? Theme.positive : Theme.negative
        return VStack(alignment: .leading, spacing: Space.sm) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(hideAmounts ? change.percent : (pnl >= 0 ? "+" : "−") + abs(pnl).fiat)
                    .numeral().foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                Text(hideAmounts ? "Today" : "\(change.percent) today")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            MiniArea(values: points, tint: tint).frame(maxHeight: .infinity)
            if !hideAmounts {
                LabeledContent("Balance") { Text(total.fiat).foregroundStyle(Theme.textPrimary) }
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Top holdings

    private var holdings: some View {
        let list = publicHoldings.sorted { $0.value > $1.value }
        let total = max(list.reduce(0) { $0 + $1.value }, 1)
        let top = Array(list.prefix(5))
        let rest = max(1 - top.reduce(0) { $0 + $1.value } / total, 0)
        return VStack(alignment: .leading, spacing: side * 0.04) {
            if let lead = top.first {
                // Hero: allocation ring with the top coin, and its share set large.
                HStack(spacing: side * 0.06) {
                    AllocationRing(slices: top.map { (Self.brand($0.asset.symbol), $0.value / total) } + (rest > 0.005 ? [(Theme.hairline, rest)] : []),
                                   lineWidth: side * 0.05) {
                        CoinIcon(symbol: lead.asset.symbol, size: side * 0.14)
                    }
                    .frame(width: side * 0.34, height: side * 0.34)
                    VStack(alignment: .leading, spacing: side * 0.008) {
                        Text("Top holding")
                            .font(.system(size: side * 0.034, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(pct(lead.value / total))
                            .font(.system(size: side * 0.135, weight: .semibold).monospacedDigit())
                            .tracking(-side * 0.004)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        HStack(spacing: side * 0.015) {
                            Text(lead.asset.name).foregroundStyle(Theme.textPrimary)
                            change(lead.asset.change24h)
                        }
                        .font(.system(size: side * 0.04, weight: .medium))
                    }
                }
                // The rest: quiet rows sharing the remaining height evenly.
                VStack(spacing: 0) {
                    ForEach(top.dropFirst(), id: \.asset.id) { h in
                        HStack(spacing: side * 0.03) {
                            Capsule().fill(Self.brand(h.asset.symbol))
                                .frame(width: side * 0.012, height: side * 0.06)
                            CoinIcon(symbol: h.asset.symbol, size: side * 0.07)
                            Text(h.asset.name)
                                .font(.system(size: side * 0.042, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            change(h.asset.change24h)
                                .font(.system(size: side * 0.036, weight: .medium))
                                .frame(minWidth: side * 0.16, alignment: .trailing)
                            Text(pct(h.value / total))
                                .font(.system(size: side * 0.042, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                                .frame(minWidth: side * 0.12, alignment: .trailing)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                Text("No public holdings").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func pct(_ v: Double) -> String { v.formatted(.percent.precision(.fractionLength(0))) }

    private func change(_ v: Double) -> some View {
        Text(v.percent).monospacedDigit().foregroundStyle(v >= 0 ? Theme.positive : Theme.negative)
    }

    /// Recognisable brand hues for the ring; neutral greys for the rest.
    static func brand(_ symbol: String) -> Color {
        switch symbol.uppercased() {
        case "BTC", "WBTC": Color(hex: 0xF7931A)
        case "ETH": Color(hex: 0x627EEA)
        case "SOL": Color(hex: 0x9945FF)
        case "USDC": Color(hex: 0x2775CA)
        case "USDT": Color(hex: 0x26A17B)
        case "XRP": Color(hex: 0x6E7681)
        case "DOGE": Color(hex: 0xC2A633)
        case "ADA": Color(hex: 0x0033AD)
        case "LINK": Color(hex: 0x2A5ADA)
        case "AVAX": Color(hex: 0xE84142)
        case "DOT": Color(hex: 0xE6007A)
        case "LTC": Color(hex: 0x345D9D)
        case "UNI": Color(hex: 0xFF007A)
        case "PEPE": Color(hex: 0x3D9B3A)
        case "SHIB": Color(hex: 0xE0362C)
        case "ARB": Color(hex: 0x28A0F0)
        default: Theme.textSecondary
        }
    }

    // MARK: Top mover

    private var mover: some View {
        let best = publicHoldings.max { $0.asset.change24h < $1.asset.change24h }
        return VStack(alignment: .leading, spacing: Space.sm) {
            if let best {
                let up = best.asset.change24h >= 0
                let tint = up ? Theme.positive : Theme.negative
                HStack(spacing: Space.sm) {
                    CoinIcon(symbol: best.asset.symbol, size: side * 0.12)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(best.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                        Text(best.asset.symbol).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(best.asset.change24h.percent).numeral().foregroundStyle(tint)
                    Text("Best performer today").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                MiniArea(values: best.asset.series(.day).map(\.price), tint: tint).frame(maxHeight: .infinity)
            } else {
                Text("No public holdings").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Line + soft gradient area, same look as the app's charts.
private struct MiniArea: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        let lo = values.min() ?? 0, hi = max(values.max() ?? 1, lo + 0.0001)
        let pad = (hi - lo) * 0.08
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("i", i), yStart: .value("b", lo - pad), yEnd: .value("v", v))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("i", i), y: .value("v", v))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(tint)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartPlotStyle { $0.padding(.zero) }
    }
}

/// Donut of allocation slices with small gaps and a centre view.
private struct AllocationRing<Center: View>: View {
    let slices: [(Color, Double)]
    let lineWidth: CGFloat
    @ViewBuilder let center: Center

    var body: some View {
        ZStack {
            Chart(Array(slices.enumerated()), id: \.offset) { _, slice in
                SectorMark(angle: .value("Share", slice.1), innerRadius: .ratio(0.7), angularInset: 1.2)
                    .cornerRadius(lineWidth * 0.25)
                    .foregroundStyle(slice.0)
            }
            .chartLegend(.hidden)
            center
        }
        .accessibilityHidden(true)
    }
}
