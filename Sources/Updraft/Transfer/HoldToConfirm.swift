import SwiftUI

/// Press and hold to confirm: a fill sweeps across while held, releasing early
/// rolls it back. Haptic on press and on completion.
struct HoldToConfirm: View {
    let title: String
    var duration: Double = 1.2
    let onConfirm: () -> Void

    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var completed = false

    var body: some View {
        ZStack {
            Capsule().fill(Theme.surfaceHi)
            GeometryReader { geo in
                Capsule()
                    .fill(Theme.textPrimary)
                    .frame(width: max(geo.size.height, geo.size.width * progress))
                    .opacity(progress > 0 ? 1 : 0)
            }
            label.foregroundStyle(Theme.textPrimary)
            label.foregroundStyle(Theme.background)
                .mask(alignment: .leading) {
                    GeometryReader { geo in Rectangle().frame(width: geo.size.width * progress) }
                }
        }
        .frame(height: 54)
        .scaleEffect(pressing ? 0.98 : 1)
        .animation(.snappy(duration: 0.2), value: pressing)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
            completed = true
            Haptics.medium()
            onConfirm()
            // Ready again if the screen stays (e.g. a failed check).
            Task {
                try? await Task.sleep(for: .seconds(1))
                completed = false
                pressing = false
                withAnimation(.smooth(duration: 0.3)) { progress = 0 }
            }
        } onPressingChanged: { down in
            guard !completed else { return }
            pressing = down
            if down {
                Haptics.soft()
                withAnimation(.linear(duration: duration)) { progress = 1 }
            } else {
                withAnimation(.smooth(duration: 0.3)) { progress = 0 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { completed = true; onConfirm() }
    }

    private var label: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "hand.tap")
            Text(title)
        }
        .font(Typo.headline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
