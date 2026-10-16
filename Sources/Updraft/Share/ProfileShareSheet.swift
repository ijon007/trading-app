import SwiftUI
import Charts

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

    var body: some View {
        VStack(spacing: Space.md) {
            Text("Share").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                .padding(.top, Space.lg)

            TabView(selection: $page) {
                ForEach(Kind.allCases) { kind in
                    ShareCard(kind: kind, hideAmounts: privacyOn)
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                        .tag(kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: ShareCard.size.height + Space.lg)

            HStack(spacing: Space.xs) {
                ForEach(Kind.allCases) { kind in
                    Capsule()
                        .fill(kind == page ? Theme.textPrimary : Theme.textTertiary.opacity(0.5))
                        .frame(width: kind == page ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: page)

            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.md)
        .background(Theme.background)
        .sensoryFeedback(.selection, trigger: page)
        .task(id: "\(page.rawValue)|\(privacyOn)|\(scheme == .dark)") { render() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var actions: some View {
        HStack(spacing: Space.sm) {
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
            Button { save() } label: { action(feedback == "Saved" ? "Saved" : "Save", feedback == "Saved" ? "checkmark" : "arrow.down.to.line") }
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
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: title)
    }

    private func render() {
        let renderer = ImageRenderer(content:
            ShareCard(kind: page, hideAmounts: privacyOn)
                .padding(Space.lg)
                .background(Theme.background)
                .environment(\.colorScheme, scheme))
        renderer.scale = max(displayScale, 3)
        rendered = renderer.uiImage
    }

    private func copy() {
        guard let rendered else { return }
        UIPasteboard.general.image = rendered
        flash("Copied")
    }

    private func save() {
        guard let rendered else { return }
        UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
        flash("Saved")
    }

    private func flash(_ text: String) {
        Haptics.success()
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
    static let size = CGSize(width: 300, height: 380)
    private var store: SocialStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            switch kind {
            case .portfolio: portfolio
            case .holdings: holdings
            case .mover: mover
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(Space.lg)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: Space.xs) {
            SocialAvatar(photo: store.photo, size: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(store.me.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(kind.rawValue).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: Space.xxs) {
                UpdraftLogoShape().frame(width: 12, height: 16)
                Text("Updraft").font(Typo.caption)
            }
            .foregroundStyle(Theme.textTertiary)
        }
    }

    private var footer: some View {
        Text("updraft.app/u/\(store.me.handle)")
            .font(Typo.caption)
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
        return VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(hideAmounts ? change.percent : (pnl >= 0 ? "+" : "−") + abs(pnl).fiat)
                    .numeral().foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                Text(hideAmounts ? "Today" : "\(change.percent) today")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            MiniArea(values: points, tint: tint).frame(height: 120)
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
        return VStack(alignment: .leading, spacing: Space.sm) {
            ForEach(list.prefix(5), id: \.asset.id) { h in
                let share = h.value / total
                HStack(spacing: Space.sm) {
                    CoinIcon(symbol: h.asset.symbol, size: 28)
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
            }
            if list.isEmpty {
                Text("No public holdings").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Top mover

    private var mover: some View {
        let best = publicHoldings.max { $0.asset.change24h < $1.asset.change24h }
        return VStack(alignment: .leading, spacing: Space.md) {
            if let best {
                let up = best.asset.change24h >= 0
                let tint = up ? Theme.positive : Theme.negative
                HStack(spacing: Space.sm) {
                    CoinIcon(symbol: best.asset.symbol, size: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(best.asset.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                        Text(best.asset.symbol).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(best.asset.change24h.percent).numeral().foregroundStyle(tint)
                    Text("Best performer today").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                MiniArea(values: best.asset.series(.day).map(\.price), tint: tint).frame(height: 90)
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
