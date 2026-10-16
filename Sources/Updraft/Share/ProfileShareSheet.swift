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
            footer
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
        }
    }

    private var footer: some View {
        HStack(spacing: Space.xxs) {
            UpdraftLogoShape().frame(width: 12, height: 16)
            Text("Updraft").font(Typo.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(Theme.textTertiary)
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
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(list.prefix(5), id: \.asset.id) { h in
                let share = h.value / total
                HStack(spacing: Space.sm) {
                    CoinIcon(symbol: h.asset.symbol, size: side * 0.085)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        HStack {
                            Text(h.asset.symbol).font(Typo.callout.weight(.medium)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(share.formatted(.percent.precision(.fractionLength(0))))
                                .font(Typo.callout).monospacedDigit().foregroundStyle(Theme.textSecondary)
                        }
                        GeometryReader { geo in
                            Capsule().fill(Theme.hairline)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Theme.textPrimary).frame(width: geo.size.width * share)
                                }
                        }
                        .frame(height: 4)
                    }
                }
                .frame(maxHeight: .infinity) // rows share the height evenly
            }
            if list.isEmpty {
                Text("No public holdings").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
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
