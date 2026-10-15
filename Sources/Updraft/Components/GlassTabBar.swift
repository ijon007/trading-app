import SwiftUI

/// One tab in `GlassTabBar`.
struct GlassTabItem<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let icon: Image
    var id: Value { value }

    init(_ value: Value, _ title: String, systemImage: String) {
        self.value = value; self.title = title; icon = Image(systemName: systemImage)
    }

    init(_ value: Value, _ title: String, image: Image) {
        self.value = value; self.title = title; icon = image
    }
}

/// Floating Liquid Glass tab bar with short capsule tabs. The selected tab sits in a
/// glass capsule that morphs between tabs with a spring.
struct GlassTabBar<Value: Hashable>: View {
    @Binding var selection: Value
    let items: [GlassTabItem<Value>]

    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabSize = CGSize(width: 68, height: 48)

    var body: some View {
        GlassEffectContainer(spacing: Space.xs) {
            HStack(spacing: Space.xxs) {
                ForEach(items) { item in
                    tabButton(item)
                }
            }
            .padding(Space.xxs)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.bottom, Space.xs)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ item: GlassTabItem<Value>) -> some View {
        let selected = item.value == selection
        return Button {
            guard !selected else { return }
            Haptics.tap()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.2)) {
                selection = item.value
            }
        } label: {
            item.icon
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                .frame(width: tabSize.width, height: tabSize.height)
                .contentShape(Capsule())
                .background {
                    if selected {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.tint(Theme.textPrimary.opacity(0.08)).interactive(), in: .capsule)
                            .glassEffectID("selection", in: glass)
                            .matchedGeometryEffect(id: "selection", in: glass)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

extension View {
    /// A page in a custom-tab ZStack: kept alive (state preserved), shown only when selected.
    func glassTabPage(_ isSelected: Bool) -> some View {
        opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }
}
