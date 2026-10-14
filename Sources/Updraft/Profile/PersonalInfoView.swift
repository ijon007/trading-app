import SwiftUI

/// Mock personal details. UI only — no backend.
struct PersonalInfo: Equatable {
    var firstName = "Jon"
    var lastName = "Doe"
    var email = "jon@updraft.app"
    var phone = "+33 6 12 34 56 78"
    var birthDate = Calendar.current.date(from: DateComponents(year: 1995, month: 6, day: 14)) ?? .now
    var street = "12 Rue de Rivoli"
    var city = "Paris"
    var postalCode = "75001"
    var country = "France"

    enum Field: Hashable { case firstName, lastName, email, phone, street, city, postalCode }

    static let countries = ["France", "Germany", "Italy", "Spain", "United Kingdom", "United States"]

    /// The validation message for a field, or nil when it's valid.
    func error(for field: Field) -> String? {
        func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
        switch field {
        case .firstName: return trimmed(firstName).isEmpty ? "Enter your first name" : nil
        case .lastName: return trimmed(lastName).isEmpty ? "Enter your last name" : nil
        case .email:
            let e = trimmed(email)
            let at = e.firstIndex(of: "@")
            let ok = at.map { e[e.index(after: $0)...].contains(".") && $0 != e.startIndex } ?? false
            return ok && !e.contains(" ") ? nil : "Enter a valid email address"
        case .phone:
            let digits = phone.filter(\.isNumber).count
            return (8...15).contains(digits) ? nil : "Enter a valid phone number"
        case .street: return trimmed(street).isEmpty ? "Enter your street address" : nil
        case .city: return trimmed(city).isEmpty ? "Enter your city" : nil
        case .postalCode: return trimmed(postalCode).count >= 3 ? nil : "Enter a valid postal code"
        }
    }

    var isAdult: Bool {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
        return age >= 18
    }

    var isValid: Bool {
        [Field.firstName, .lastName, .email, .phone, .street, .city, .postalCode].allSatisfy { error(for: $0) == nil } && isAdult
    }
}

struct PersonalInfoView: View {
    @State private var saved = PersonalInfo()
    @State private var draft = PersonalInfo()
    @State private var touched: Set<PersonalInfo.Field> = []
    @State private var showErrors = false
    @State private var savedTick = 0
    @State private var justSaved = false
    @FocusState private var focus: PersonalInfo.Field?

    private var isDirty: Bool { draft != saved }

    var body: some View {
        Form {
            Section {
                field("First name", text: $draft.firstName, field: .firstName, content: .givenName)
                field("Last name", text: $draft.lastName, field: .lastName, content: .familyName)
                DatePicker("Date of birth", selection: $draft.birthDate,
                           in: ...Date.now, displayedComponents: .date)
            } header: {
                Text("Legal name")
            } footer: {
                if !draft.isAdult {
                    errorText("You must be at least 18 to use Updraft")
                } else {
                    Text("Must match your government ID. Changing it may require re-verification.")
                }
            }

            Section("Contact") {
                field("Email", text: $draft.email, field: .email, content: .emailAddress,
                      keyboard: .emailAddress, icon: "envelope")
                field("Phone", text: $draft.phone, field: .phone, content: .telephoneNumber,
                      keyboard: .phonePad, icon: "phone")
            }

            Section("Address") {
                field("Street", text: $draft.street, field: .street, content: .fullStreetAddress)
                field("City", text: $draft.city, field: .city, content: .addressCity)
                field("Postal code", text: $draft.postalCode, field: .postalCode, content: .postalCode,
                      keyboard: .numbersAndPunctuation)
                Picker("Country", selection: $draft.country) {
                    ForEach(PersonalInfo.countries, id: \.self) { Text($0).tag($0) }
                }
            }

            if isDirty {
                Section {
                    Button("Discard changes", role: .destructive) {
                        Haptics.tap()
                        withAnimation(.smooth) { draft = saved; touched = []; showErrors = false }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .navigationTitle("Personal info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if justSaved { Image(systemName: "checkmark") } else { Text("Save") }
                }
                .disabled(!isDirty && !justSaved)
                .contentTransition(.symbolEffect(.replace))
            }
        }
        .sensoryFeedback(.selection, trigger: draft.country)
        .sensoryFeedback(.success, trigger: savedTick)
        .onSubmit(advanceFocus)
        .animation(.smooth(duration: 0.25), value: isDirty)
        .animation(.smooth(duration: 0.25), value: touched)
        .animation(.smooth(duration: 0.25), value: showErrors)
        .onChange(of: focus) { old, _ in if let old { touched.insert(old) } }
    }

    // MARK: - Rows

    @ViewBuilder
    private func field(_ title: String, text: Binding<String>, field: PersonalInfo.Field,
                       content: UITextContentType, keyboard: UIKeyboardType = .default,
                       icon: String? = nil) -> some View {
        let message = (showErrors || touched.contains(field)) ? draft.error(for: field) : nil
        VStack(alignment: .leading, spacing: Space.xxs) {
            LabeledContent {
                TextField(title, text: text)
                    .multilineTextAlignment(.trailing)
                    .textContentType(content)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
                    .submitLabel(field == .postalCode ? .done : .next)
                    .focused($focus, equals: field)
                    .foregroundStyle(message == nil ? Theme.textPrimary : Theme.negative)
            } label: {
                if let icon { Label(title, systemImage: icon) } else { Text(title) }
            }
            if let message {
                errorText(message).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func errorText(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(Typo.caption)
            .foregroundStyle(Theme.negative)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Actions

    private let order: [PersonalInfo.Field] = [.firstName, .lastName, .email, .phone, .street, .city, .postalCode]

    private func advanceFocus() {
        guard let f = focus, let i = order.firstIndex(of: f) else { return }
        focus = i + 1 < order.count ? order[i + 1] : nil
    }

    private func save() {
        guard isDirty else { return }
        focus = nil
        guard draft.isValid else {
            showErrors = true
            Haptics.error()
            return
        }
        saved = draft
        touched = []
        showErrors = false
        savedTick += 1
        withAnimation(.smooth) { justSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.smooth) { justSaved = false }
        }
    }
}

#Preview { NavigationStack { PersonalInfoView() } }
