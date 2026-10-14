import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

struct ProfileView: View {
    @AppStorage("appearance") private var appearance: Appearance = .system
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
                    row("Passcode", "lock")
                    row("Two-factor authentication", "key")
                }
                Section("Preferences") {
                    Picker(selection: $currency) {
                        ForEach(["USD", "EUR", "GBP", "CHF"], id: \.self) { Text($0) }
                    } label: { Label("Currency", systemImage: "dollarsign.circle") }
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
                    } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                    Toggle(isOn: $notifications) { Label("Notifications", systemImage: "bell") }
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
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: faceID)
            .sensoryFeedback(.selection, trigger: notifications)
            .sensoryFeedback(.selection, trigger: currency)
            .sensoryFeedback(.selection, trigger: appearance)
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
