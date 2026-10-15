import SwiftUI
import Charts

// MARK: - Brand

/// The real Updraft app icon (bundled copy in Resources/Brand).
struct UpdraftMark: View {
    var size: CGFloat = 88

    private static let image = UIImage(named: "updraft-mark", in: .module, with: nil)

    var body: some View {
        Group {
            if let image = Self.image {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                Color(hex: 0x0B0B0C)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
        // Keeps the black tile defined on the dark background.
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

/// Shared type scale for onboarding: medium/semibold, never heavy.
enum OnboardType {
    static let display = Font.system(size: 34, weight: .semibold)
    static let title = Font.system(size: 30, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let wordmark = Font.system(size: 30, weight: .medium)
}

// MARK: - Motion helpers

/// Fades and lifts content in, staggered by index, whenever `active` turns on.
struct StaggeredAppear: ViewModifier {
    let index: Int
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    let animation: Animation = reduceMotion
                        ? .easeOut(duration: 0.2)
                        : .spring(duration: 0.5, bounce: 0).delay(0.05 + Double(index) * 0.06)
                    withAnimation(animation) { shown = true }
                } else {
                    shown = false
                }
            }
    }
}

extension View {
    func staggered(_ index: Int, active: Bool = true) -> some View {
        modifier(StaggeredAppear(index: index, active: active))
    }
}

// MARK: - Splash

/// Launch moment: the icon and wordmark settle in, then glide into Welcome.
struct SplashView: View {
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: Space.md) {
            UpdraftMark(size: 104)
                .matchedGeometryEffect(id: "mark", in: namespace)
                .scaleEffect(shown || reduceMotion ? 1 : 0.94)
                .opacity(shown ? 1 : 0)
            Text("Updraft")
                .font(OnboardType.wordmark)
                .tracking(-0.6)
                .foregroundStyle(Theme.textPrimary)
                .matchedGeometryEffect(id: "wordmark", in: namespace)
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 6)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0).delay(0.12), value: shown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.7, bounce: 0)) { shown = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Updraft")
    }
}

// MARK: - Welcome

/// Three pages, each a live miniature of the app.
struct WelcomeView: View {
    let namespace: Namespace.ID
    let onContinue: () -> Void
    @State private var page = 0

    private let pages: [(title: String, body: String)] = [
        ("Your whole portfolio,\nat a glance", "Every coin you own in one place, with clear charts for any timeframe."),
        ("Buy, sell and swap\nwithout the noise", "Simple trades with the price, fee and total up front."),
        ("Send and receive\nin seconds", "Share your address as a QR code or pay anyone with theirs."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xs) {
                UpdraftMark(size: 30)
                    .matchedGeometryEffect(id: "mark", in: namespace)
                Text("Updraft")
                    .font(.system(size: 19, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.textPrimary)
                    .matchedGeometryEffect(id: "wordmark", in: namespace)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    WelcomePage(index: i, isActive: page == i, title: pages[i].title, text: pages[i].body)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .sensoryFeedback(.selection, trigger: page)

            HStack {
                PageDots(count: pages.count, current: page)
                Spacer()
                Button {
                    Haptics.tap()
                    if page < pages.count - 1 {
                        withAnimation(.spring(duration: 0.4, bounce: 0)) { page += 1 }
                    } else {
                        onContinue()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(page < pages.count - 1 ? "Next" : "Continue")
                            .contentTransition(.interpolate)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, Space.xs)
                }
                .glassProminentButton()
                .controlSize(.large)
                .animation(.snappy(duration: 0.25), value: page)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.md)
        }
    }
}

private struct WelcomePage: View {
    let index: Int
    let isActive: Bool
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Space.md)
            Group {
                switch index {
                case 0: PortfolioVisual(active: isActive)
                case 1: TradeVisual(active: isActive)
                default: TransferVisual(active: isActive)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            Spacer(minLength: Space.md)
            Text(title)
                .font(OnboardType.title)
                .tracking(-0.6)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .staggered(0, active: isActive)
            Text(text)
                .font(OnboardType.body)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
                .staggered(1, active: isActive)
                .padding(.bottom, Space.xl)
        }
        .padding(.horizontal, Space.lg)
    }
}

/// Mini Home: balance counting up and a balance chart revealing left to right.
private struct PortfolioVisual: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value = SampleData.totalBalance * 0.86
    @State private var reveal: CGFloat = 0
    private let points = SampleData.balanceSeries(.month)

    var body: some View {
        let lo = points.map(\.price).min() ?? 0, hi = points.map(\.price).max() ?? 1
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Total balance")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            Text(value.fiat)
                .font(.system(size: 34, weight: .medium).monospacedDigit())
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: value))
            Chart(points) { p in
                AreaMark(x: .value("d", p.date), yStart: .value("b", lo), yEnd: .value("v", p.price))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Theme.positive.opacity(0.2), Theme.positive.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("d", p.date), y: .value("v", p.price))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(Theme.positive)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: lo...hi)
            .frame(height: 130)
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: reveal, anchor: .leading)
            }
            .padding(.top, Space.xs)
            HStack(spacing: -6) {
                ForEach(Array(["BTC", "ETH", "SOL", "LINK", "ADA"].enumerated()), id: \.offset) { i, s in
                    CoinIcon(symbol: s, size: 28)
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                        .staggered(2 + i, active: active)
                }
            }
            .padding(.top, Space.sm)
        }
        .padding(Space.lg)
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Theme.hairline, lineWidth: 1))
        .onChange(of: active, initial: true) { _, isActive in
            if isActive {
                if reduceMotion {
                    value = SampleData.totalBalance; reveal = 1
                } else {
                    withAnimation(.easeOut(duration: 1.0).delay(0.15)) { reveal = 1 }
                    withAnimation(.spring(duration: 0.9, bounce: 0).delay(0.2)) { value = SampleData.totalBalance }
                }
            } else {
                value = SampleData.totalBalance * 0.86; reveal = 0
            }
        }
        .accessibilityHidden(true)
    }
}

/// A short activity feed of trades sliding in.
private struct TradeVisual: View {
    let active: Bool

    private let rows: [(symbol: String, title: String, detail: String, icon: String)] = [
        ("BTC", "Bought Bitcoin", "0.012 BTC", "plus"),
        ("ETH", "Sold Ethereum", "0.40 ETH", "minus"),
        ("SOL", "Swapped to Solana", "12.5 SOL", "arrow.left.arrow.right"),
    ]

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: Space.sm) {
                    CoinIcon(symbol: row.symbol, size: 38)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: row.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.background)
                                .frame(width: 16, height: 16)
                                .background(Theme.textPrimary, in: .circle)
                                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 1.5))
                                .offset(x: 3, y: 3)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.textPrimary)
                        Text(row.detail).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.positive)
                        .symbolEffect(.bounce, value: active)
                }
                .padding(Space.md)
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
                .staggered(i * 2, active: active)
            }
        }
        .padding(.horizontal, Space.xs)
        .accessibilityHidden(true)
    }
}

/// A QR tile and a transfer that lands.
private struct TransferVisual: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sent = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "qrcode")
                .font(.system(size: 110, weight: .ultraLight))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 180, height: 180)
                .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Theme.hairline, lineWidth: 1))
                .overlay { UpdraftMark(size: 34) }
                .staggered(0, active: active)
            HStack(spacing: Space.xs) {
                Image(systemName: sent ? "checkmark.circle.fill" : "paperplane")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(sent ? Theme.positive : Theme.textPrimary)
                    .contentTransition(.symbolEffect(.replace))
                Text(sent ? "0.25 ETH received" : "Sending 0.25 ETH")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .staggered(1, active: active)
        }
        .onChange(of: active, initial: true) { _, isActive in
            sent = false
            guard isActive else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0).delay(1.1)) { sent = true }
        }
        .sensoryFeedback(.success, trigger: sent) { _, new in new }
        .accessibilityHidden(true)
    }
}

/// Capsule page indicator; the current page stretches.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.textPrimary : Theme.textTertiary.opacity(0.45))
                    .frame(width: i == current ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - Get started

struct GetStartedView: View {
    let namespace: Namespace.ID
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            UpdraftMark(size: 64)
                .matchedGeometryEffect(id: "mark", in: namespace)
                .padding(.bottom, Space.lg)
            Text("Invest with a\nlighter touch.")
                .font(OnboardType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .staggered(0)
            Text("Setup takes about a minute. We'll tailor Updraft to how you invest.")
                .font(OnboardType.body)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .padding(.top, Space.sm)
                .staggered(1)
            Spacer()
            VStack(spacing: Space.xs) {
                Button {
                    Haptics.tap()
                    onStart()
                } label: {
                    Text("Get started").font(.system(size: 17, weight: .medium)).frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                Button("I already have an account") {
                    Haptics.tap()
                    onSignIn()
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, Space.sm)
            }
            .staggered(2)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.xs)
    }
}
