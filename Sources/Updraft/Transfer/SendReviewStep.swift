import SwiftUI

/// Second step of Send: summary, confirm, then a success state.
struct SendReviewStep: View {
    let draft: SendDraft
    let onFinish: () -> Void

    private enum Phase { case review, sending, sent }
    @State private var phase: Phase = .review

    var body: some View {
        ZStack {
            if phase == .sent {
                success.transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                summary.transition(.opacity)
            }
        }
        .animation(.snappy, value: phase)
        .navigationTitle(phase == .sent ? "" : "Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase != .review)
        .interactiveDismissDisabled(phase == .sending)
        .safeAreaInset(edge: .bottom) { bottomButton }
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.xs) {
                    CoinIcon(symbol: draft.asset.symbol, size: 44)
                    Text("\(draft.amount.units) \(draft.asset.symbol)")
                        .numeral()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(draft.value.fiat).font(Typo.figure).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, Space.md)

                VStack(spacing: 0) {
                    row("To", short(draft.address), mono: true)
                    row("Network", draft.network)
                    row("Network fee", "~" + draft.fee.fiat)
                    row("Total", (draft.value + draft.fee).fiat, divider: false, strong: true)
                }
                .transferCard()

                Text("Crypto transfers can't be reversed. Check the address before you send.")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private var success: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: phase == .sent)
            Text("Sent").titleStyle().foregroundStyle(Theme.textPrimary)
            Text("\(draft.amount.units) \(draft.asset.symbol) is on its way to \(short(draft.address)).")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomButton: some View {
        Button {
            switch phase {
            case .review: confirm()
            case .sending: break
            case .sent: Haptics.tap(); onFinish()
            }
        } label: {
            ZStack {
                if phase == .sending {
                    ProgressView().tint(Theme.background)
                } else {
                    Text(phase == .sent ? "Done" : "Send \(draft.asset.symbol)").font(Typo.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(phase == .sending)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }

    private func confirm() {
        Haptics.medium()
        phase = .sending
        Task {
            try? await Task.sleep(for: .seconds(1.1)) // sample network round trip
            Haptics.success()
            phase = .sent
        }
    }

    private func short(_ address: String) -> String {
        address.count > 16 ? "\(address.prefix(8))…\(address.suffix(6))" : address
    }

    private func row(_ title: String, _ value: String, mono: Bool = false, divider: Bool = true, strong: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value)
                    .font(mono ? .system(size: 15, weight: .medium, design: .monospaced) : strong ? Typo.headline : Typo.figure)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.vertical, Space.row)
            if divider { Divider().overlay(Theme.hairline) }
        }
    }
}
