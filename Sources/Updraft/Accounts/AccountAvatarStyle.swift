import SwiftUI
import LocalAuthentication

/// Avatar colors for accounts. "mono" (or nil) keeps the black/white look.
enum AccountPalette {
    static let keys = ["mono", "blue", "green", "orange", "pink", "purple", "teal", "red"]

    static func color(_ key: String?) -> Color? {
        switch key {
        case "blue": Color(red: 0.25, green: 0.47, blue: 0.95)
        case "green": Color(red: 0.18, green: 0.62, blue: 0.40)
        case "orange": Color(red: 0.96, green: 0.55, blue: 0.18)
        case "pink": Color(red: 0.92, green: 0.33, blue: 0.56)
        case "purple": Color(red: 0.55, green: 0.38, blue: 0.90)
        case "teal": Color(red: 0.13, green: 0.62, blue: 0.68)
        case "red": Color(red: 0.86, green: 0.27, blue: 0.24)
        default: nil
        }
    }

}

/// Device owner check: Face ID, falling back to the device passcode.
enum DeviceAuth {
    static func verify(reason: String) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                cont.resume(returning: true) // no passcode set on the device: nothing to check against
                return
            }
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
}

/// 12 words in a 2-column grid, blurred until revealed. Shared by create and show-phrase.
struct PhraseGrid: View {
    let words: [String]
    @Binding var revealed: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.xs), GridItem(.flexible())], spacing: Space.xs) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                HStack(spacing: Space.xs) {
                    Text("\(i + 1)").font(Typo.caption).monospacedDigit()
                        .foregroundStyle(Theme.textTertiary).frame(width: 20, alignment: .trailing)
                    Text(word).font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.sm)
                .background(Theme.surface, in: .rect(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Theme.hairline))
            }
        }
        .blur(radius: revealed ? 0 : 10)
        .overlay {
            if !revealed {
                VStack(spacing: Space.xs) {
                    Image(systemName: "eye.slash").font(.system(size: 22, weight: .medium))
                    Text("Tap to reveal").font(Typo.headline)
                    Text("Make sure no one can see your screen.").font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.select()
            withAnimation(.smooth(duration: 0.3)) { revealed.toggle() }
        }
        .privacySensitive()
        .accessibilityLabel(revealed ? words.joined(separator: " ") : "Hidden recovery phrase. Double tap to reveal.")
    }
}

/// Small capsule tag: Default, Watch-only.
struct AccountBadge: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Theme.surfaceHi, in: .capsule)
        .fixedSize()
    }
}
