import SwiftUI
import UIKit

// MARK: - Model (mock)

enum TwoFactorMethod: String, Equatable {
    case app, sms
    var title: String { self == .app ? "Authenticator app" : "Text message" }
    var icon: String { self == .app ? "lock.app.dashed" : "message" }
}

@Observable
final class TwoFactorModel {
    var method: TwoFactorMethod?
    var phone = "+33 6 12 34 56 78"
    var backupCodes: [String] = TwoFactorModel.makeCodes()
    let setupKey = "JBSW Y3DP EHPK 3PXP"

    static func makeCodes() -> [String] {
        let chars = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return (0..<10).map { _ in
            let a = String((0..<4).map { _ in chars.randomElement()! })
            let b = String((0..<4).map { _ in chars.randomElement()! })
            return "\(a)-\(b)"
        }
    }
}

// MARK: - Page

struct TwoFactorView: View {
    @State private var model = TwoFactorModel()
    @State private var setup: TwoFactorMethod?
    @State private var confirmDisable = false
    @State private var disabledTick = 0

    var body: some View {
        List {
            Section {
                status.listRowBackground(Color.clear)
            }

            if let method = model.method {
                Section("Method") {
                    LabeledContent {
                        Text(method == .sms ? model.phone : "On").foregroundStyle(Theme.textSecondary)
                    } label: {
                        Label(method.title, systemImage: method.icon)
                    }
                    Button {
                        Haptics.tap(); setup = method == .app ? .sms : .app
                    } label: {
                        Label(method == .app ? "Switch to text message" : "Switch to authenticator app",
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Section {
                    NavigationLink {
                        BackupCodesView(model: model, inFlow: false, done: {})
                    } label: {
                        Label("Backup codes", systemImage: "list.number")
                    }
                } footer: {
                    Text("Use a backup code if you lose access to your phone. Each code works once.")
                }
                Section {
                    Button("Turn off two-factor authentication", role: .destructive) {
                        Haptics.warning(); confirmDisable = true
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Section {
                    option(.app, subtitle: "Recommended. Works offline with apps like 1Password or Google Authenticator.")
                    option(.sms, subtitle: "Get a code by text message to your phone.")
                } header: {
                    Text("Choose a method")
                }
            }
        }
        .tint(Theme.textPrimary)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Two-factor authentication")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth, value: model.method)
        .sensoryFeedback(.success, trigger: disabledTick)
        .sheet(item: Binding(get: { setup.map(SetupItem.init) }, set: { setup = $0?.method })) { item in
            TwoFactorSetupFlow(model: model, method: item.method)
        }
        .confirmationDialog("Turn off two-factor authentication?", isPresented: $confirmDisable,
                            titleVisibility: .visible) {
            Button("Turn off", role: .destructive) {
                model.method = nil
                model.backupCodes = TwoFactorModel.makeCodes()
                disabledTick += 1
            }
        } message: {
            Text("Your account will only be protected by your password. Withdrawals will be paused for 24 hours.")
        }
    }

    private struct SetupItem: Identifiable {
        let method: TwoFactorMethod
        var id: String { method.rawValue }
    }

    private var status: some View {
        let on = model.method != nil
        return VStack(spacing: Space.sm) {
            Image(systemName: on ? "checkmark.shield.fill" : "shield.slash")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(on ? Theme.positive : Theme.textPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 72, height: 72)
                .background(Theme.surfaceHi, in: Circle())
            Text(on ? "Two-factor is on" : "Two-factor is off")
                .font(Typo.headline).foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
            Text(on ? "You'll be asked for a code when you sign in or withdraw."
                    : "Add a second step at sign-in to keep your crypto safe, even if your password leaks.")
                .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func option(_ m: TwoFactorMethod, subtitle: String) -> some View {
        Button {
            Haptics.tap(); setup = m
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: m.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceHi, in: .rect(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title).font(Typo.body).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(.rect)
        }
    }
}

// MARK: - Setup flow

private struct TwoFactorSetupFlow: View {
    @Bindable var model: TwoFactorModel
    let method: TwoFactorMethod
    @Environment(\.dismiss) private var dismiss

    enum Stage: Int { case intro, code, backup }
    @State private var stage: Stage = .intro
    @State private var phone = ""
    @State private var copied = false
    @State private var sending = false
    @FocusState private var phoneFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .intro: method == .app ? AnyView(appIntro) : AnyView(smsIntro)
                case .code:
                    CodeStep(destination: method == .app ? "your authenticator app" : phone) {
                        Haptics.success()
                        let wasOn = model.method != nil
                        model.method = method
                        if method == .sms { model.phone = phone }
                        if wasOn { dismiss() } else { go(.backup) }
                    }
                case .backup:
                    BackupCodesView(model: model, inFlow: true) { dismiss() }
                }
            }
            .id(stage)
            .transition(.push(from: .trailing))
            .background(Theme.background)
            .navigationTitle(method.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if stage != .backup {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Haptics.tap(); dismiss() } }
                }
            }
        }
        .interactiveDismissDisabled(stage == .backup)
        .onAppear { phone = model.phone }
    }

    private func go(_ s: Stage) {
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { stage = s }
    }

    private var appIntro: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                Text("Scan this QR code with your authenticator app, or enter the setup key manually.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                QRPlaceholder()
                    .frame(width: 200, height: 200)
                    .padding(Space.md)
                    .background(.white, in: .rect(cornerRadius: Radius.md))
                VStack(spacing: Space.xs) {
                    Text("Setup key").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    Text(model.setupKey).font(Typo.figure).tracking(1).foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = model.setupKey.replacingOccurrences(of: " ", with: "")
                        Haptics.success()
                        withAnimation(.smooth) { copied = true }
                        Task { try? await Task.sleep(for: .seconds(2)); withAnimation(.smooth) { copied = false } }
                    } label: {
                        Label(copied ? "Copied" : "Copy key", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .glassButton()
                }
                .frame(maxWidth: .infinity)
                .padding(Space.md)
                .surfaceCard(radius: Radius.md)
            }
            .padding(Space.md)
        }
        .safeAreaInset(edge: .bottom) { primary("Next") { Haptics.tap(); go(.code) } }
    }

    private var smsIntro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("We'll text a 6-digit code to this number.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(Typo.body)
                    .focused($phoneFocused)
                    .padding(Space.md)
                    .surfaceCard(radius: Radius.md)
                if !phoneValid && !phone.isEmpty {
                    Label("Enter a valid phone number", systemImage: "exclamationmark.circle.fill")
                        .font(Typo.caption).foregroundStyle(Theme.negative)
                }
            }
            .padding(Space.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .safeAreaInset(edge: .bottom) {
            primary(sending ? "Sending…" : "Send code", enabled: phoneValid && !sending) {
                Haptics.tap(); phoneFocused = false; sending = true
                Task { try? await Task.sleep(for: .milliseconds(800)); sending = false; go(.code) }
            }
        }
    }

    private var phoneValid: Bool { (8...15).contains(phone.filter(\.isNumber).count) }

    private func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(!enabled)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}

/// Decorative QR-like pattern (placeholder, not scannable).
private struct QRPlaceholder: View {
    var body: some View {
        Canvas { ctx, size in
            let n = 25
            let cell = size.width / CGFloat(n)
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func finder(_ x: Int, _ y: Int) -> Bool? {
                for (fx, fy) in [(0, 0), (n - 7, 0), (0, n - 7)] where (fx..<fx + 7).contains(x) && (fy..<fy + 7).contains(y) {
                    let dx = x - fx, dy = y - fy
                    let ring = min(dx, dy, 6 - dx, 6 - dy)
                    return ring != 1
                }
                return nil
            }
            for y in 0..<n {
                for x in 0..<n {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let on = finder(x, y) ?? ((seed >> 33) & 1 == 1)
                    if on {
                        ctx.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)),
                                 with: .color(.black))
                    }
                }
            }
        }
        .accessibilityLabel("QR code")
    }
}

// MARK: - Code entry

private struct CodeStep: View {
    let destination: String
    let onVerified: () -> Void
    @State private var code = ""
    @State private var error: String?
    @State private var shakes: CGFloat = 0
    @State private var verifying = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.xs) {
                Text("Enter the 6-digit code").titleStyle().foregroundStyle(Theme.textPrimary)
                Text("From \(destination). Demo: any code except 000000.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .opacity(0.02)
                    .frame(width: 1, height: 1)
                HStack(spacing: Space.xs) {
                    ForEach(0..<6, id: \.self) { i in box(i) }
                }
                .contentShape(.rect)
                .onTapGesture { focused = true }
            }
            .modifier(Shake(shakes: shakes))
            Group {
                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(Typo.caption).foregroundStyle(Theme.negative)
                } else if verifying {
                    ProgressView()
                } else {
                    Button("Paste code") {
                        Haptics.tap()
                        if let s = UIPasteboard.general.string { code = s }
                    }
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 24)
            Spacer()
        }
        .padding(Space.md)
        .padding(.top, Space.lg)
        .onAppear { focused = true }
        .onChange(of: code) { _, v in
            let digits = String(v.filter(\.isNumber).prefix(6))
            if digits != v { code = digits; return }
            if error != nil && !digits.isEmpty { withAnimation(.smooth) { error = nil } }
            if digits.count == 6 { verify() }
        }
        .sensoryFeedback(.selection, trigger: code.count)
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(code)
        let active = focused && i == min(chars.count, 5)
        return Text(i < chars.count ? String(chars[i]) : "")
            .font(Typo.numeral).monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 46, height: 58)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm)
                    .strokeBorder(error != nil ? Theme.negative : (active ? Theme.accent : Theme.hairline),
                                  lineWidth: active || error != nil ? 1.5 : 1)
            }
            .animation(.smooth(duration: 0.15), value: active)
    }

    private func verify() {
        focused = false
        verifying = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            verifying = false
            if code == "000000" {
                Haptics.error()
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                withAnimation(.smooth) { error = "That code didn't work. Try again."; code = "" }
                focused = true
            } else {
                onVerified()
            }
        }
    }
}

// MARK: - Backup codes

private struct BackupCodesView: View {
    @Bindable var model: TwoFactorModel
    let inFlow: Bool
    let done: () -> Void
    @State private var copied = false
    @State private var saved = false
    @State private var confirmRegenerate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                if inFlow {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Save your backup codes").titleStyle().foregroundStyle(Theme.textPrimary)
                        Text("Two-factor is on. Keep these somewhere safe. Each code can be used once if you lose your phone.")
                            .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.sm) {
                    ForEach(model.backupCodes, id: \.self) { c in
                        Text(c).font(Typo.figure).foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Space.md)
                .surfaceCard(radius: Radius.md)
                .contentTransition(.opacity)
                .textSelection(.enabled)

                HStack(spacing: Space.sm) {
                    Button {
                        UIPasteboard.general.string = model.backupCodes.joined(separator: "\n")
                        Haptics.success()
                        withAnimation(.smooth) { copied = true; saved = true }
                        Task { try? await Task.sleep(for: .seconds(2)); withAnimation(.smooth) { copied = false } }
                    } label: {
                        Label(copied ? "Copied" : "Copy all", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .glassButton()
                    ShareLink(item: model.backupCodes.joined(separator: "\n")) {
                        Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .glassButton()
                    .simultaneousGesture(TapGesture().onEnded { saved = true })
                }
                .controlSize(.large)

                if !inFlow {
                    Button("Generate new codes") { Haptics.warning(); confirmRegenerate = true }
                        .font(Typo.callout).foregroundStyle(Theme.negative)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Space.md)
        }
        .background(Theme.background)
        .navigationTitle("Backup codes")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(inFlow)
        .safeAreaInset(edge: .bottom) {
            if inFlow {
                Button {
                    Haptics.tap(); done()
                } label: {
                    Text(saved ? "Done" : "I've saved them").font(Typo.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
                }
                .glassProminentButton()
                .controlSize(.large)
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.xs)
            }
        }
        .confirmationDialog("Generate new backup codes?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Generate new codes", role: .destructive) {
                withAnimation(.smooth) { model.backupCodes = TwoFactorModel.makeCodes() }
                Haptics.success()
            }
        } message: { Text("Your old codes will stop working.") }
    }
}

#Preview { NavigationStack { TwoFactorView() } }
