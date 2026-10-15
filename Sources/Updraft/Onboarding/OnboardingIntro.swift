import SwiftUI

/// The Updraft mark: a rounded tile with an up-right arrow. Inverts with the theme.
struct UpdraftMark: View {
    var size: CGFloat = 88

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Theme.textPrimary)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(Theme.background)
            }
            .accessibilityHidden(true)
    }
}

/// Launch moment: mark and wordmark settle in, then hand off to Welcome.
struct SplashView: View {
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: Space.md) {
            UpdraftMark(size: 96)
                .matchedGeometryEffect(id: "mark", in: namespace)
                .scaleEffect(shown || reduceMotion ? 1 : 0.86)
            Text("Updraft")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)
                .matchedGeometryEffect(id: "wordmark", in: namespace)
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 6)
        }
        .opacity(shown ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0)) { shown = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Updraft")
    }
}

/// Three short pages explaining the app.
struct WelcomeView: View {
    let namespace: Namespace.ID
    let onContinue: () -> Void
    @State private var page = 0

    private let pages: [(title: String, body: String)] = [
        ("Your portfolio,\nat a glance", "Track every coin you own and see how it moves, day by day."),
        ("Buy, sell\nand swap", "Trade in a few taps with clear prices and no surprises."),
        ("Send and receive\nin seconds", "Move crypto to anyone with an address or a QR code."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xs) {
                UpdraftMark(size: 32)
                    .matchedGeometryEffect(id: "mark", in: namespace)
                Text("Updraft")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.textPrimary)
                    .matchedGeometryEffect(id: "wordmark", in: namespace)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)

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
                    Text(page < pages.count - 1 ? "Next" : "Continue")
                        .font(Typo.headline)
                        .contentTransition(.opacity)
                        .padding(.horizontal, Space.sm)
                }
                .glassProminentButton()
                .controlSize(.large)
                .animation(.snappy, value: page)
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
        VStack(alignment: .leading, spacing: Space.lg) {
            Spacer(minLength: 0)
            WelcomeVisual(index: index, isActive: isActive)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(Typo.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, Space.xl)
        }
        .padding(.horizontal, Space.lg)
    }
}

/// Small animated illustration per page, built from app pieces.
private struct WelcomeVisual: View {
    let index: Int
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        Group {
            switch index {
            case 0: portfolio
            case 1: trade
            default: transfer
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { drawn = 0; return }
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeOut(duration: 1.1).delay(0.15)) { drawn = 1 }
            }
        }
        .accessibilityHidden(true)
    }

    private var portfolio: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(SampleData.totalBalance.fiat)
                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Sparkline(values: SampleData.asset("SOL").sparkline)
                .trim(from: 0, to: drawn)
                .stroke(Theme.positive, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(height: 90)
            HStack(spacing: -8) {
                ForEach(["BTC", "ETH", "SOL", "LINK"], id: \.self) { CoinIcon(symbol: $0, size: 30) }
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var trade: some View {
        HStack(spacing: Space.lg) {
            ForEach(Array(["plus", "arrow.left.arrow.right", "minus"].enumerated()), id: \.offset) { i, symbol in
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 68, height: 68)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .scaleEffect(i == 1 ? 1.15 : 1)
                    .opacity(drawn > 0 ? 1 : 0)
                    .offset(y: drawn > 0 || reduceMotion ? 0 : 12)
                    .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0).delay(Double(i) * 0.08), value: drawn > 0)
            }
        }
    }

    private var transfer: some View {
        HStack(spacing: Space.md) {
            CoinIcon(symbol: "ETH", size: 54)
            Capsule()
                .fill(Theme.hairline)
                .frame(width: 90, height: 2)
                .overlay(alignment: .leading) {
                    Circle().fill(Theme.textPrimary).frame(width: 8, height: 8)
                        .offset(x: 82 * drawn)
                }
            Image(systemName: "qrcode")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 64, height: 64)
                .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Theme.hairline, lineWidth: 1))
        }
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
                    .fill(i == current ? Theme.textPrimary : Theme.textTertiary.opacity(0.5))
                    .frame(width: i == current ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0), value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// Entry point: create a profile or sign in.
struct GetStartedView: View {
    let namespace: Namespace.ID
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            UpdraftMark(size: 72)
                .matchedGeometryEffect(id: "mark", in: namespace)
                .padding(.bottom, Space.lg)
            Text("Invest with\na lighter touch.")
                .font(.system(size: 40, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Set up takes about a minute. We'll tailor Updraft to how you invest.")
                .font(Typo.body)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Space.sm)
            Spacer()
            VStack(spacing: Space.sm) {
                Button {
                    Haptics.tap()
                    onStart()
                } label: {
                    Text("Get started").font(Typo.headline).frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                Button("I already have an account") {
                    Haptics.tap()
                    onSignIn()
                }
                .font(Typo.callout.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, Space.xs)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }
}
