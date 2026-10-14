import SwiftUI

// MARK: - Settings page (mock: nothing is enforced except the real Face ID toggle)

enum PasscodeTimeout: Int, CaseIterable, Identifiable {
    case immediately = 0, oneMinute = 1, fiveMinutes = 5, fifteenMinutes = 15, oneHour = 60
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "After 1 minute"
        case .fiveMinutes: "After 5 minutes"
        case .fifteenMinutes: "After 15 minutes"
        case .oneHour: "After 1 hour"
        }
    }
}

struct PasscodeView: View {
    @AppStorage("passcodeTimeout") private var timeout = PasscodeTimeout.immediately.rawValue
    @AppStorage("passcodeForTrades") private var forTrades = true
    @AppStorage("passcodeForWithdrawals") private var forWithdrawals = true
    @State private var changing = false
    @State private var changedTick = 0
    @State private var showChanged = false

    var body: some View {
        List {
            Section {
                VStack(spacing: Space.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 72, height: 72)
                        .background(Theme.surfaceHi, in: Circle())
                    Text("Passcode is on").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text("Your 6-digit passcode protects Updraft and confirms sensitive actions.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    Haptics.tap(); changing = true
                } label: {
                    HStack {
                        Label("Change passcode", systemImage: "key")
                        Spacer()
                        if showChanged {
                            Label("Updated", systemImage: "checkmark.circle.fill")
                                .font(Typo.caption).foregroundStyle(Theme.positive)
                                .transition(.opacity)
                        }
                    }
                }
            }

            Section {
                Picker(selection: $timeout) {
                    ForEach(PasscodeTimeout.allCases) { Text($0.title).tag($0.rawValue) }
                } label: { Label("Require passcode", systemImage: "timer") }
            } footer: {
                Text("How long Updraft can stay in the background before asking again.")
            }

            Section("Ask for passcode when") {
                Toggle(isOn: $forTrades) { Label("Placing trades", systemImage: "arrow.left.arrow.right") }
                Toggle(isOn: $forWithdrawals) { Label("Withdrawing funds", systemImage: "arrow.up.right") }
            }
            .tint(Theme.toggleTint)

            Section {
                FaceIDToggle()
                TestFaceIDButton()
            } header: {
                Text("Biometrics")
            } footer: {
                Text("Use Face ID instead of typing your passcode. Your passcode is always available as a fallback.")
            }
        }
        .tint(Theme.textPrimary)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth, value: showChanged)
        .sensoryFeedback(.selection, trigger: timeout)
        .sensoryFeedback(.selection, trigger: forTrades)
        .sensoryFeedback(.selection, trigger: forWithdrawals)
        .fullScreenCover(isPresented: $changing) {
            ChangePasscodeFlow {
                showChanged = true
                Task { try? await Task.sleep(for: .seconds(3)); showChanged = false }
            }
        }
    }
}

// MARK: - Change flow

private struct ChangePasscodeFlow: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    enum Stage: Int { case current, new, confirm, done }

    /// Mock current passcode.
    private let currentCode = "123456"
    @State private var stage: Stage = .current
    @State private var entry = ""
    @State private var newCode = ""
    @State private var message: String?
    @State private var shakes: CGFloat = 0
    @State private var attempts = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.xl) {
                Spacer(minLength: Space.md)
                if stage == .done {
                    doneView.transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: Space.sm) {
                        Text(title).titleStyle().foregroundStyle(Theme.textPrimary)
                            .contentTransition(.opacity)
                        Text(message ?? subtitle)
                            .font(Typo.callout)
                            .foregroundStyle(message == nil ? Theme.textSecondary : Theme.negative)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                    }
                    .id(stage)
                    .transition(.push(from: .trailing))
                    dots.modifier(Shake(shakes: shakes))
                    Spacer()
                    Keypad(onDigit: digit, onDelete: delete)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .toolbar {
                if stage != .done {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { Haptics.tap(); dismiss() }
                    }
                }
            }
        }
    }

    private var title: String {
        switch stage {
        case .current: "Enter current passcode"
        case .new: "Create new passcode"
        case .confirm: "Confirm new passcode"
        case .done: ""
        }
    }

    private var subtitle: String {
        switch stage {
        case .current: "Demo passcode: 123456"
        case .new: "Avoid repeating or sequential digits."
        case .confirm: "Enter it once more."
        case .done: ""
        }
    }

    private var dots: some View {
        HStack(spacing: Space.md) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i < entry.count ? Theme.textPrimary : .clear)
                    .stroke(message == nil ? Theme.textPrimary : Theme.negative, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .scaleEffect(i == entry.count - 1 ? 1.15 : 1)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: entry)
    }

    private var doneView: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: stage)
            VStack(spacing: Space.xs) {
                Text("Passcode changed").titleStyle().foregroundStyle(Theme.textPrimary)
                Text("Use your new passcode next time you unlock Updraft.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Haptics.tap(); onDone(); dismiss()
            } label: {
                Text("Done").font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
            }
            .glassProminentButton()
            .controlSize(.large)
        }
    }

    private func digit(_ d: Int) {
        guard entry.count < 6 else { return }
        if message != nil { withAnimation(.smooth) { message = nil } }
        entry.append(String(d))
        if entry.count == 6 {
            Task { try? await Task.sleep(for: .milliseconds(150)); evaluate() }
        }
    }

    private func delete() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func evaluate() {
        switch stage {
        case .current:
            if entry == currentCode { advance(to: .new) }
            else {
                attempts += 1
                fail(attempts >= 3 ? "Wrong passcode. Hint: it's 123456." : "Wrong passcode. Try again.")
            }
        case .new:
            if Set(entry).count == 1 || "0123456789".contains(entry) || "9876543210".contains(entry) {
                fail("That passcode is too easy to guess.")
            } else if entry == currentCode {
                fail("Choose a passcode different from your current one.")
            } else {
                newCode = entry; advance(to: .confirm)
            }
        case .confirm:
            if entry == newCode {
                Haptics.success()
                withAnimation(.spring(response: 0.4, dampingFraction: 1)) { stage = .done }
            } else {
                newCode = ""
                fail("Passcodes didn't match. Start again.")
                withAnimation(.smooth) { stage = .new }
                message = "Passcodes didn't match. Create it again."
            }
        case .done: break
        }
    }

    private func advance(to s: Stage) {
        Haptics.soft()
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) {
            entry = ""; message = nil; stage = s
        }
    }

    private func fail(_ m: String) {
        Haptics.error()
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        withAnimation(.smooth) { message = m; entry = "" }
    }
}

// MARK: - Keypad

struct Keypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    private let rows: [[Int?]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [nil, 0, -1]]

    var body: some View {
        VStack(spacing: Space.md) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: Space.lg) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        key(rows[r][c])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func key(_ value: Int?) -> some View {
        switch value {
        case .none:
            Color.clear.frame(width: 78, height: 78)
        case .some(-1):
            Button { Haptics.tap(); onDelete() } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 78, height: 78)
                    .contentShape(Circle())
            }
            .buttonStyle(KeyStyle(filled: false))
            .accessibilityLabel("Delete")
        case .some(let d):
            Button { Haptics.tap(); onDigit(d) } label: {
                Text("\(d)").font(.system(size: 32, weight: .regular)).monospacedDigit()
                .frame(width: 78, height: 78)
            }
            .buttonStyle(KeyStyle(filled: true))
        }
    }
}

private struct KeyStyle: ButtonStyle {
    let filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .background(Circle().fill(filled ? (configuration.isPressed ? Theme.hairline : Theme.surfaceHi) : .clear))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview { NavigationStack { PasscodeView() } }
