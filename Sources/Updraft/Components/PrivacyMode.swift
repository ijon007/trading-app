import SwiftUI
import CoreMotion

/// Privacy mode: masks every money amount app-wide. Persisted in UserDefaults,
/// so every `@AppStorage(PrivacyMode.storageKey)` reader stays in sync.
/// Ways in: pull down on Home, the eye button by the balance, or turning the phone face down.
@MainActor
enum PrivacyMode {
    static let storageKey = "privacy.hideAmounts"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: storageKey) }

    /// Flips the mode with a selection haptic (Haptics.swift: toggles use selection).
    static func toggle() { set(!isOn) }

    static func set(_ on: Bool) {
        guard on != isOn else { return }
        Haptics.select()
        UserDefaults.standard.set(on, forKey: storageKey)
    }
}

extension View {
    /// Blurs this money amount while privacy mode is on. Apply to each amount view.
    func privateAmount() -> some View { modifier(PrivateAmount()) }

    /// Home: pulling the list down past a threshold toggles privacy mode,
    /// with an eye glyph that fades in as you pull.
    func privacyPullToggle() -> some View { modifier(PrivacyPullToggle()) }

    /// App-wide: turning the phone face down hides amounts (never reveals them).
    func privacyFlipToHide() -> some View { modifier(PrivacyFlipToHide()) }
}

private struct PrivateAmount: ViewModifier {
    @AppStorage(PrivacyMode.storageKey) private var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var height: CGFloat = 17

    func body(content: Content) -> some View {
        content
            // Blur scales with text size (~0.35x line height), so the big
            // header hides as fully as a caption.
            .blur(radius: hidden ? max(4, height * 0.35) : 0, opaque: false)
            .opacity(hidden ? 0.7 : 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .privacySensitive(hidden)
            .accessibilityHidden(hidden)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.35), value: hidden)
    }
}

private struct PrivacyPullToggle: ViewModifier {
    @AppStorage(PrivacyMode.storageKey) private var hidden = false
    @State private var pull: CGFloat = 0
    @State private var armed = true
    private let threshold: CGFloat = 90

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, new in
                pull = new
                if armed, new >= threshold {
                    armed = false
                    PrivacyMode.toggle()
                } else if new < 4 {
                    armed = true
                }
            }
            .overlay(alignment: .top) {
                let progress = min(pull / threshold, 1)
                Image(systemName: hidden ? "eye" : "eye.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(progress)
                    .scaleEffect(0.7 + 0.3 * progress)
                    .offset(y: pull / 2 - 12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

private struct PrivacyFlipToHide: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @State private var monitor = FlipMonitor()

    func body(content: Content) -> some View {
        content
            .onAppear { monitor.start() }
            .onChange(of: phase) { _, p in p == .active ? monitor.start() : monitor.stop() }
    }
}

/// Watches gravity; face down (screen to the floor) for ~0.5s hides amounts.
@MainActor
private final class FlipMonitor {
    private let motion = CMMotionManager()
    private var faceDownSince: Date?

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated { self?.handle(gravityZ: data.gravity.z) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        faceDownSince = nil
    }

    private func handle(gravityZ z: Double) {
        guard z > 0.9 else { faceDownSince = nil; return }
        if let since = faceDownSince {
            if Date().timeIntervalSince(since) > 0.5 { PrivacyMode.set(true) }
        } else {
            faceDownSince = Date()
        }
    }
}

/// Small eye toggle shown next to the Home balance label.
struct PrivacyEyeButton: View {
    @AppStorage(PrivacyMode.storageKey) private var hidden = false

    var body: some View {
        Button { PrivacyMode.toggle() } label: {
            Image(systemName: hidden ? "eye.slash" : "eye")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hidden ? "Show amounts" : "Hide amounts")
    }
}
