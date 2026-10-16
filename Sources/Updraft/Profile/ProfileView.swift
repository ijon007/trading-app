import SwiftUI

struct ProfileView: View {
    @State private var headerSheet: ProfileHeader.Sheet?
    @AppStorage("appearance") private var appearance: Appearance?
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("currency") private var currency = "USD"
    @AppStorage("faceID") private var faceID = true
    @AppStorage("notifications") private var notifications = true
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            // ScrollView + grouped cards instead of a List: in a List row the
            // header's buttons were subject to row tap routing and Followers,
            // Following and Share never fired. Here they're ordinary buttons.
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ProfileHeader(sheet: $headerSheet)
                    group("Account") {
                        row("Personal info", "person") { PersonalInfoView() }
                        divider
                        row("Verification", "checkmark.seal") { VerificationView() }
                        divider
                        row("Payment methods", "creditcard") { PaymentMethodsView() }
                    }
                    group("Security") {
                        FaceIDToggle().padding(.vertical, Space.xs)
                        divider
                        row("Passcode", "lock") { PasscodeView() }
                        divider
                        row("Two-factor authentication", "key") { TwoFactorView() }
                    }
                    group("Appearance") {
                        AppearancePicker(selection: Binding(
                            get: { appearance ?? Appearance(colorScheme) },
                            set: { appearance = $0 }
                        ))
                        .padding(.vertical, Space.xs)
                    }
                    group("Preferences") {
                        HStack {
                            Label("Currency", systemImage: "dollarsign.circle")
                            Spacer()
                            Picker("Currency", selection: $currency) {
                                ForEach(Currency.allCases) { c in Text("\(c.symbol)  \(c.rawValue)").tag(c.rawValue) }
                            }
                            .labelsHidden()
                        }
                        .frame(minHeight: 44)
                        divider
                        Toggle(isOn: $notifications) { Label("Notifications", systemImage: "bell") }
                            .tint(Theme.toggleTint)
                            .frame(minHeight: 44)
                    }
                    group("Support") {
                        row("Help", "questionmark.circle")
                        divider
                        row("Legal", "doc.text")
                    }
                    group(nil) {
                        Button("Sign out", role: .destructive) { Haptics.warning(); confirmSignOut = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
            }
            .tint(Theme.textPrimary)
            .contentMargins(.bottom, Space.lg, for: .scrollContent) // clear of the floating tab bar
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: faceID)
            .sensoryFeedback(.selection, trigger: notifications)
            .sensoryFeedback(.selection, trigger: currency)
            .sheet(item: $headerSheet) { ProfileHeader.content($0) }
            .confirmationDialog("Sign out of Updraft?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Haptics.success() }
            }
        }
    }

    /// Inset-grouped look: small title above a rounded card.
    private func group(_ title: String?, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let title {
                Text(title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    .padding(.leading, Space.md)
            }
            VStack(spacing: 0) { content() }
                .padding(.horizontal, Space.md)
                .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
        }
    }

    private var divider: some View { Divider().overlay(Theme.hairline).padding(.leading, 36) }

    private func row(_ title: String, _ icon: String) -> some View {
        NavigationLink {
            Text(title).titleStyle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .navigationTitle(title)
        } label: {
            rowLabel(title, icon)
        }
        .buttonStyle(.plain)
    }

    private func row<Destination: View>(_ title: String, _ icon: String,
                                        @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) { rowLabel(title, icon) }
            .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
