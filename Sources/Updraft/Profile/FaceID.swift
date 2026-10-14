import SwiftUI
import LocalAuthentication

/// Real Face ID via LocalAuthentication.
enum Biometrics {
    enum Availability: Equatable { case available, notEnrolled, unavailable(String) }

    enum Outcome: Equatable { case success, cancelled, failed(String) }

    static var availability: Availability {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType == .faceID || context.biometryType == .opticID || context.biometryType == .touchID
                ? .available : .unavailable("Face ID isn't available on this device.")
        }
        if let code = error.map({ LAError.Code(rawValue: $0.code) }), code == .biometryNotEnrolled {
            return .notEnrolled
        }
        if let code = error.map({ LAError.Code(rawValue: $0.code) }), code == .biometryLockout {
            return .unavailable("Face ID is locked. Unlock your iPhone with its passcode to re-enable it.")
        }
        return .unavailable("Face ID isn't available on this device.")
    }

    static func authenticate(reason: String) async -> Outcome {
        await withCheckedContinuation { (cont: CheckedContinuation<Outcome, Never>) in
            let context = LAContext()
            context.localizedFallbackTitle = ""
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, error in
                if ok { cont.resume(returning: .success); return }
                let code = (error as? LAError)?.code
                switch code {
                case .userCancel, .systemCancel, .appCancel, .userFallback:
                    cont.resume(returning: .cancelled)
                default:
                    cont.resume(returning: .failed(error?.localizedDescription ?? "Face ID failed."))
                }
            }
        }
    }
}

/// Face ID toggle that only turns on after a successful real Face ID check.
struct FaceIDToggle: View {
    @AppStorage("faceID") private var faceID = false
    @State private var availability = Biometrics.availability
    @State private var busy = false
    @State private var alert: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
        Toggle(isOn: Binding(get: { faceID && availability == .available }, set: set)) {
            Label("Face ID", systemImage: "faceid")
        }
        .tint(Theme.toggleTint)
        .disabled(busy || availability != .available)
        // Explanation lives in its own row, only when Face ID can't be used.
        if let note {
            Text(note).font(Typo.caption).foregroundStyle(Theme.textSecondary)
        }
        }
        .onAppear { availability = Biometrics.availability }
        .onChange(of: scenePhase) { _, p in if p == .active { availability = Biometrics.availability } }
        .alert("Face ID", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private var note: String? {
        switch availability {
        case .available: nil
        case .notEnrolled: "Set up Face ID in Settings to use it here."
        case .unavailable(let m): m
        }
    }

    private func set(_ on: Bool) {
        guard on else { faceID = false; Haptics.select(); return }
        busy = true
        Task {
            let result = await Biometrics.authenticate(reason: "Turn on Face ID to unlock Updraft.")
            busy = false
            switch result {
            case .success: faceID = true; Haptics.success()
            case .cancelled: break
            case .failed(let m): Haptics.error(); alert = m
            }
            availability = Biometrics.availability
        }
    }
}

/// "Test Face ID" row: runs a real Face ID check and reports the result.
struct TestFaceIDButton: View {
    @State private var result: String?
    @State private var ok = false

    var body: some View {
        Button {
            Haptics.tap()
            Task {
                switch await Biometrics.authenticate(reason: "Test Face ID for Updraft.") {
                case .success: ok = true; result = "Face ID recognized you"; Haptics.success()
                case .cancelled: ok = false; result = "Cancelled"
                case .failed(let m): ok = false; result = m; Haptics.error()
                }
            }
        } label: {
            HStack {
                Label("Test Face ID", systemImage: "faceid")
                Spacer()
                if let result {
                    Label(result, systemImage: ok ? "checkmark.circle.fill" : "xmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(Typo.caption)
                        .foregroundStyle(ok ? Theme.positive : Theme.textSecondary)
                        .transition(.opacity)
                }
            }
        }
        .disabled(Biometrics.availability != .available)
        .animation(.smooth, value: result)
    }
}
