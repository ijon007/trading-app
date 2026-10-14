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
                    header.listRowBackground(Color.clear)
                }
                Section("Account") {
                    row("Personal info", "person")
                    row("Verification", "checkmark.seal")
                    row("Payment methods", "creditcard")
                }
                Section("Security") {
                    Toggle(isOn: $faceID) { Label("Face ID", systemImage: "faceid") }
                        .tint(Theme.toggleTint)
                    row("Passcode", "lock")
                    row("Two-factor authentication", "key")
                }
                Section("Appearance") {
                    AppearancePicker(selection: Binding(
                        get: { appearance ?? Appearance(colorScheme) },
                        set: { appearance = $0 }
                    ))
                }
                Section("Preferences") {
                    Picker(selection: $currency) {
                        ForEach(["USD", "EUR", "GBP", "CHF"], id: \.self) { Text($0) }
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
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: faceID)
            .sensoryFeedback(.selection, trigger: notifications)
            .sensoryFeedback(.selection, trigger: currency)
            .confirmationDialog("Sign out of Aurum?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Haptics.success() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Space.sm) {
            Text(String(SampleData.profile.name.prefix(1)))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 84, height: 84)
                .glassEffect(.regular, in: Circle())
            VStack(spacing: 2) {
                Text(SampleData.profile.name).titleStyle().foregroundStyle(Theme.textPrimary)
                Text(SampleData.profile.handle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
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
}
