import SwiftUI

struct ProfileView: View {
    @AppStorage("appearance") private var appearance: Appearance?
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("currency") private var currency = "USD"
    @AppStorage("faceID") private var faceID = true
    @AppStorage("notifications") private var notifications = true
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileHeader().listRowBackground(Color.clear)
                }
                Section("Account") {
                    row("Personal info", "person") { PersonalInfoView() }
                    row("Verification", "checkmark.seal") { VerificationView() }
                    row("Payment methods", "creditcard") { PaymentMethodsView() }
                }
                Section("Security") {
                    FaceIDToggle()
                    row("Passcode", "lock") { PasscodeView() }
                    row("Two-factor authentication", "key") { TwoFactorView() }
                }
                Section("Appearance") {
                    AppearancePicker(selection: Binding(
                        get: { appearance ?? Appearance(colorScheme) },
                        set: { appearance = $0 }
                    ))
                }
                Section("Preferences") {
                    Picker(selection: $currency) {
                        ForEach(Currency.allCases) { c in Text("\(c.symbol)  \(c.rawValue)").tag(c.rawValue) }
                    } label: { Label("Currency", systemImage: "dollarsign.circle") }
                    Toggle(isOn: $notifications) { Label("Notifications", systemImage: "bell") }
                        .tint(Theme.toggleTint)
                }
                Section("Support") {
                    row("Help", "questionmark.circle")
                    row("Legal", "doc.text")
                }
                Section {
                    Button("Sign out", role: .destructive) { Haptics.warning(); confirmSignOut = true }
                        .frame(maxWidth: .infinity)
                }
            }
            .tint(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Space.lg, for: .scrollContent) // clear of the floating tab bar
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: faceID)
            .sensoryFeedback(.selection, trigger: notifications)
            .sensoryFeedback(.selection, trigger: currency)
            .confirmationDialog("Sign out of Updraft?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Haptics.success() }
            }
        }
    }

    private func row(_ title: String, _ icon: String) -> some View {
        NavigationLink {
            Text(title).titleStyle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .navigationTitle(title)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func row<Destination: View>(_ title: String, _ icon: String,
                                        @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) { Label(title, systemImage: icon) }
    }
}
