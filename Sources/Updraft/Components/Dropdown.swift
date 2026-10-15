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
                // Bare glyph like the Verification rows: fixed width so titles align.
                Image(systemName: icon)
                    .font(Typo.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: Space.lg + Space.xxs)
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

/// Tappable glass row showing the current choice. On open its glass morphs into a
/// floating panel of options (iOS 26 glass morph); tapping outside closes it.
/// Raises itself above sibling views while open.
struct Dropdown<ID: Hashable>: View {
    var caption: String? = nil
    let options: [DropdownOption<ID>]
    @Binding var selection: ID?
    @Binding var isOpen: Bool
    var placeholder: String = "Choose"

    @Namespace private var glass
    @State private var rowHeight: CGFloat = 0

    private var current: DropdownOption<ID>? { options.first { $0.id == selection } }

    static var spring: Animation { .spring(duration: 0.4, bounce: 0.22) }

    var body: some View {
        GlassEffectContainer(spacing: Space.xs) {
            field
                .overlay(alignment: .top) {
                    if isOpen {
                        DropdownPanel(options: options, selection: $selection, isOpen: $isOpen)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.lg))
                            .glassEffectID("panel", in: glass)
                            .glassEffectTransition(.matchedGeometry)
                            .offset(y: rowHeight + Space.xs)
                    }
                }
        }
        // Outside-tap catcher: a large clear layer behind the field while open.
        .background {
            if isOpen {
                Color.clear
                    .frame(width: 4_000, height: 4_000)
                    .contentShape(.rect)
                    .onTapGesture { close() }
            }
        }
        .zIndex(isOpen ? 1 : 0)
    }

    private var field: some View {
        Button {
            Haptics.tap()
            withAnimation(Self.spring) { isOpen.toggle() }
        } label: {
            OptionRowLabel(caption: caption, title: current?.title ?? placeholder,
                           subtitle: current?.subtitle, icon: current?.icon) {
                Image(systemName: "chevron.down")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(Space.sm)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.lg))
        .glassEffectID("field", in: glass)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 }
        .accessibilityValue(current?.title ?? placeholder)
        .accessibilityHint(isOpen ? "Collapses the list" : "Shows the options")
    }

    private func close() {
        withAnimation(Self.spring) { isOpen = false }
    }
}

// MARK: - Panel

private struct DropdownPanel<ID: Hashable>: View {
    let options: [DropdownOption<ID>]
    @Binding var selection: ID?
    @Binding var isOpen: Bool
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
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
                // Springy staggered reveal, top to bottom.
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : -Space.xs)
                .scaleEffect(revealed ? 1 : 0.97, anchor: .top)
                .animation(.spring(duration: 0.4, bounce: 0.3).delay(0.05 + Double(index) * 0.045), value: revealed)
            }
        }
        .padding(Space.xxs)
        .onAppear { revealed = true }
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
