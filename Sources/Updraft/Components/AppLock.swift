import SwiftUI

/// App lock: when Profile's Face ID setting is on, Updraft locks on launch and
/// whenever it goes to the background. Face ID first, passcode as the fallback.
struct AppLockModifier: ViewModifier {
    @AppStorage("faceID") private var faceID = false
    @AppStorage(OnboardingKeys.done) private var hasOnboarded = false
    @Environment(\.scenePhase) private var phase
    @State private var locked = UserDefaults.standard.bool(forKey: "faceID")

    func body(content: Content) -> some View {
        content
            .overlay {
                if locked && faceID && hasOnboarded {
                    LockScreen { withAnimation(.smooth(duration: 0.35)) { locked = false } }
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .animation(.smooth(duration: 0.35), value: locked)
            .onChange(of: phase) { _, p in
                if p == .background, faceID { locked = true }
            }
    }
}

extension View {
    func appLock() -> some View { modifier(AppLockModifier()) }
}

private struct LockScreen: View {
    let onUnlock: () -> Void

    /// Mock passcode, same as Profile's passcode screen.
    private let code = "123456"
    @Environment(\.scenePhase) private var phase
    @State private var usePasscode = false
    @State private var entry = ""
    @State private var message: String?
    @State private var shakes = 0
    @State private var authenticating = false

    var body: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            VStack(spacing: Space.md) {
                UpdraftMark(size: 56)
                Text(usePasscode ? "Enter passcode" : "Updraft is locked")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.opacity)
                Text(message ?? (usePasscode ? "Your 6-digit Updraft passcode." : "Unlock with Face ID to continue."))
                    .font(Typo.callout)
                    .foregroundStyle(message == nil ? Theme.textSecondary : Theme.negative)
                    .contentTransition(.opacity)
            }
            if usePasscode {
                dots
                    .phaseAnimator([0, 1], trigger: shakes) { v, p in v.offset(x: p == 1 ? 10 : 0) }
                    animation: { _ in .spring(duration: 0.12, bounce: 0.7) }
                Keypad(onDigit: digit, onDelete: { if !entry.isEmpty { entry.removeLast() } })
                    .transition(.opacity.combined(with: .offset(y: 16)))
            }
            Spacer()
            HStack(spacing: Space.lg) {
                if usePasscode {
                    Button("Use Face ID", systemImage: "faceid") { usePasscode = false; message = nil; faceID() }
                } else {
                    Button { faceID() } label: {
                        Label("Unlock with Face ID", systemImage: "faceid")
                            .font(Typo.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .glassProminentButton()
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, Space.lg)
            if !usePasscode {
                Button("Use passcode") { Haptics.tap(); usePasscode = true; message = nil }
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.bottom, Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: usePasscode)
        .animation(.smooth(duration: 0.2), value: message)
        .task { if phase == .active { faceID() } }
        .onChange(of: phase) { _, p in if p == .active, !usePasscode { faceID() } }
    }

    private var dots: some View {
        HStack(spacing: Space.md) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i < entry.count ? Theme.textPrimary : Color.clear)
                    .overlay(Circle().strokeBorder(Theme.textSecondary, lineWidth: 1.5))
                    .frame(width: 13, height: 13)
                    .scaleEffect(i < entry.count ? 1.1 : 1)
                    .animation(.snappy(duration: 0.15), value: entry.count)
            }
        }
    }

    private func digit(_ d: Int) {
        guard entry.count < 6 else { return }
        entry += String(d)
        message = nil
        guard entry.count == 6 else { return }
        if entry == code {
            Haptics.success()
            onUnlock()
        } else {
            Haptics.error()
            shakes += 1
            message = "Wrong passcode. Try again."
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                entry = ""
            }
        }
    }

    private func faceID() {
        guard !authenticating else { return }
        authenticating = true
        Task {
            let result = await Biometrics.authenticate(reason: "Unlock Updraft.")
            authenticating = false
            switch result {
            case .success: Haptics.success(); onUnlock()
            case .cancelled: break
            case .failed: message = "Face ID didn't work. Try again or use your passcode."
            }
        }
    }
}
