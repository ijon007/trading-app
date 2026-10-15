import SwiftUI

/// A small capsule shown only while live prices can't be reached.
struct MarketStatusBanner: View {
    private var market: MarketStore { .shared }

    var body: some View {
        if market.status == .offline {
            HStack(spacing: Space.xs) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12, weight: .medium))
                Text(market.hasLoaded ? "Offline · showing last prices" : "Offline · can't load prices")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, Space.xs)
            .transition(.opacity.combined(with: .offset(y: 6)))
            .accessibilityLabel("Offline. Prices may be out of date.")
        }
    }
}

extension View {
    /// Placeholder look until the first real prices arrive: redacted with a
    /// slow, subtle breathing shimmer (static under Reduce Motion).
    func marketLoading(_ loading: Bool) -> some View {
        modifier(MarketLoading(loading: loading))
    }
}

private struct MarketLoading: ViewModifier {
    let loading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: loading ? .placeholder : [])
            .opacity(loading && dim ? 0.55 : 1)
            .animation(.easeOut(duration: 0.25), value: loading)
            .onChange(of: loading, initial: true) { _, isLoading in
                guard isLoading, !reduceMotion else { dim = false; return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

/// Quiet stand-in for a chart while its history loads.
struct ChartLoadingPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md)
            .fill(Theme.hairline.opacity(0.5))
            .padding(.horizontal, Space.md)
            .marketLoading(true)
            .accessibilityLabel("Loading chart")
    }
}
