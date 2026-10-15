import SwiftUI

/// Reusable confirmation summary: a header (amount, asset) above a card of
/// label/value rows and an emphasized total. Used by Buy and Sell; works for Send too.
/// One label/value line in a `TradeReview`.
struct TradeReviewRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = Theme.textPrimary
}

struct TradeReview<Header: View>: View {
    typealias Row = TradeReviewRow

    let rows: [Row]
    var total: Row? = nil
    @ViewBuilder var header: Header

    var body: some View {
        VStack(spacing: Space.lg) {
            header
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    rowView(row)
                    if i < rows.count - 1 || total != nil { Divider().overlay(Theme.hairline) }
                }
                if let total {
                    rowView(total, emphasized: true)
                }
            }
            .padding(.horizontal, Space.md)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    private func rowView(_ row: Row, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text(row.title)
                .font(emphasized ? Typo.headline : Typo.callout)
                .foregroundStyle(emphasized ? Theme.textPrimary : Theme.textSecondary)
            Spacer(minLength: Space.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.value)
                    .font(emphasized ? Typo.headline.monospacedDigit() : Typo.figure)
                    .foregroundStyle(row.tint)
                    .multilineTextAlignment(.trailing)
                if let detail = row.detail {
                    Text(detail).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, Space.row + 2)
        .accessibilityElement(children: .combine)
    }
}

extension TradeReview where Header == EmptyView {
    init(rows: [Row], total: Row? = nil) {
        self.init(rows: rows, total: total) { EmptyView() }
    }
}

/// Centered result state for a completed (or failed) transaction.
struct TradeResultView: View {
    let title: String
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = Theme.positive
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: Space.xs) {
                Text(title).titleStyle().foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(Typo.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .padding(.horizontal, Space.lg)
        .onAppear { withAnimation(.spring(duration: 0.45, bounce: 0.35)) { appeared = true } }
        .accessibilityElement(children: .combine)
    }
}
