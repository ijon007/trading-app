import SwiftUI

/// Display & Brightness–style chooser: two phone previews, Light and Dark.
struct AppearancePicker: View {
    @Binding var selection: Appearance

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { option in
                let isSelected = selection == option
                Button {
                    guard !isSelected else { return }
                    selection = option
                } label: {
                    VStack(spacing: Space.xs) {
                        PhonePreview(dark: option == .dark, isSelected: isSelected)
                        Text(option.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, Space.xs)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Tiny phone mock in Aurum's palette: balance, change pill, actions and rows.
private struct PhonePreview: View {
    let dark: Bool
    let isSelected: Bool

    private let width: CGFloat = 62
    private let height: CGFloat = 112

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let bg = Color(hex: dark ? 0x0B0B0C : 0xF7F7F5)
        let ink = Color(hex: dark ? 0xF7F7F5 : 0x0B0B0C)
        let soft = Color(hex: dark ? 0x2A2A2C : 0xE2E2E0)
        let green = Color(hex: dark ? 0x5FB38A : 0x2F8F5B)

        ZStack(alignment: .top) {
            bg
            VStack(spacing: 5) {
                Capsule().fill(soft).frame(width: 18, height: 3).padding(.top, 7)
                Capsule().fill(ink).frame(width: 34, height: 7).padding(.top, 6)
                Capsule().fill(green.opacity(0.35)).frame(width: 16, height: 4)
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in Circle().fill(soft).frame(width: 9, height: 9) }
                }
                .padding(.vertical, 3)
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 4) {
                        Circle().fill(soft).frame(width: 7, height: 7)
                        Capsule().fill(soft).frame(width: 18, height: 3)
                        Spacer(minLength: 0)
                        Capsule().fill(ink.opacity(0.5)).frame(width: 10, height: 3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.textPrimary.opacity(0.12), lineWidth: 0.5))
        .padding(3)
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(isSelected ? Theme.textPrimary : .clear, lineWidth: 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 1), value: isSelected)
    }
}
