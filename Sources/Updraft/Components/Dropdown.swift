import SwiftUI

/// One choice in a `Dropdown`.
struct DropdownOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
}

/// Icon tile + title + subtitle row, styled like the Profile option rows.
/// Shared by the dropdown field, its panel and any static "picker-looking" row.
struct OptionRowLabel<Accessory: View>: View {
    var caption: String? = nil
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: Space.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(Typo.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: Space.xl + Space.xs, height: Space.xl + Space.xs)
                    .background(Theme.surfaceHi, in: .rect(cornerRadius: Radius.sm))
            }
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                if let caption {
                    Text(caption).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                }
                Text(title).font(Typo.body).foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            accessory
        }
        .contentShape(.rect)
    }
}

extension OptionRowLabel where Accessory == EmptyView {
    init(caption: String? = nil, title: String, subtitle: String? = nil, icon: String? = nil) {
        self.init(caption: caption, title: title, subtitle: subtitle, icon: icon) { EmptyView() }
    }
}

// MARK: - Field

/// Tappable row showing the current choice. Pair it with `.dropdownPanel(...)` on a
/// container view; the panel floats below this field and closes on an outside tap.
struct Dropdown<ID: Hashable>: View {
    var caption: String? = nil
    let options: [DropdownOption<ID>]
    @Binding var selection: ID?
    @Binding var isOpen: Bool
    var placeholder: String = "Choose"

    private var current: DropdownOption<ID>? { options.first { $0.id == selection } }

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(Dropdown.spring) { isOpen.toggle() }
        } label: {
            OptionRowLabel(caption: caption, title: current?.title ?? placeholder,
                           subtitle: current?.subtitle, icon: current?.icon) {
                Image(systemName: "chevron.down")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(Space.sm)
            .surfaceCard(radius: Radius.md)
        }
        .buttonStyle(.plain)
        .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { $0 }
        .accessibilityValue(current?.title ?? placeholder)
        .accessibilityHint(isOpen ? "Collapses the list" : "Shows the options")
    }

    static var spring: Animation { .spring(duration: 0.35, bounce: 0.18) }
}

struct DropdownAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Panel

extension View {
    /// Floating option panel for the `Dropdown` inside this view. Tapping outside closes it.
    func dropdownPanel<ID: Hashable>(isOpen: Binding<Bool>, options: [DropdownOption<ID>],
                                     selection: Binding<ID?>) -> some View {
        overlayPreferenceValue(DropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if isOpen.wrappedValue, let anchor {
                    let field = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { withAnimation(Dropdown<ID>.spring) { isOpen.wrappedValue = false } }
                        DropdownPanel(options: options, selection: selection, isOpen: isOpen)
                            .frame(width: field.width)
                            .offset(x: field.minX, y: field.maxY + Space.xs)
                            .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }
}

private struct DropdownPanel<ID: Hashable>: View {
    let options: [DropdownOption<ID>]
    @Binding var selection: ID?
    @Binding var isOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    Haptics.select()
                    withAnimation(Dropdown<ID>.spring) {
                        selection = option.id
                        isOpen = false
                    }
                } label: {
                    OptionRowLabel(title: option.title, subtitle: option.subtitle, icon: option.icon) {
                        Image(systemName: "checkmark")
                            .font(Typo.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .opacity(option.id == selection ? 1 : 0)
                    }
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                }
                .buttonStyle(DropdownRowStyle())
                .accessibilityAddTraits(option.id == selection ? .isSelected : [])
            }
        }
        .padding(Space.xxs)
        // Floats over content, so it's the one place glass is right here.
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct DropdownRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.surfaceHi.opacity(configuration.isPressed ? 1 : 0),
                        in: .rect(cornerRadius: Radius.md))
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
