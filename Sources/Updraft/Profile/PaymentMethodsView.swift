import SwiftUI

// MARK: - Model (mock, no backend)

enum CardBrand: String {
    case visa, mastercard, amex, discover, unknown

    var title: String {
        switch self {
        case .visa: "Visa"
        case .mastercard: "Mastercard"
        case .amex: "Amex"
        case .discover: "Discover"
        case .unknown: "Card"
        }
    }
    var cvcLength: Int { self == .amex ? 4 : 3 }
    var numberLength: Int { self == .amex ? 15 : 16 }
    /// Digit group sizes used for display formatting.
    var groups: [Int] { self == .amex ? [4, 6, 5] : [4, 4, 4, 4] }

    static func detect(_ digits: String) -> CardBrand {
        if digits.hasPrefix("4") { return .visa }
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return .amex }
        if digits.hasPrefix("6011") || digits.hasPrefix("65") { return .discover }
        if let two = Int(digits.prefix(2)), (51...55).contains(two) { return .mastercard }
        if let four = Int(digits.prefix(4)), (2221...2720).contains(four) { return .mastercard }
        return .unknown
    }
}

struct PaymentMethod: Identifiable, Equatable {
    enum Kind: Equatable {
        case applePay
        case card(CardBrand, expiry: String)
        case bank(name: String)
    }
    let id = UUID()
    var kind: Kind
    var last4: String

    var title: String {
        switch kind {
        case .applePay: "Apple Pay"
        case .card(let brand, _): "\(brand.title) •••• \(last4)"
        case .bank(let name): "\(name) •••• \(last4)"
        }
    }
    var subtitle: String {
        switch kind {
        case .applePay: "Instant · No fees"
        case .card(_, let expiry): "Expires \(expiry) · Instant"
        case .bank: "Bank transfer · 1–2 business days"
        }
    }
    var icon: String {
        switch kind {
        case .applePay: "apple.logo"
        case .card: "creditcard"
        case .bank: "building.columns"
        }
    }
}

@Observable
final class PaymentStore {
    var methods: [PaymentMethod] = [
        PaymentMethod(kind: .applePay, last4: ""),
        PaymentMethod(kind: .card(.visa, expiry: "08/28"), last4: "4242"),
        PaymentMethod(kind: .bank(name: "BNP Paribas"), last4: "0189"),
    ]
    var defaultID: UUID?

    init() { defaultID = methods.dropFirst().first?.id }

    func add(_ m: PaymentMethod, makeDefault: Bool) {
        methods.append(m)
        if makeDefault || defaultID == nil { defaultID = m.id }
    }

    func remove(_ m: PaymentMethod) {
        methods.removeAll { $0.id == m.id }
        if defaultID == m.id { defaultID = methods.first?.id }
    }
}

// MARK: - List

struct PaymentMethodsView: View {
    @State private var store = PaymentStore()
    @State private var sheet: AddSheet?
    @State private var pendingRemoval: PaymentMethod?
    @State private var defaultTick = 0
    @State private var removedTick = 0

    enum AddSheet: String, Identifiable { case card, bank; var id: String { rawValue } }

    var body: some View {
        List {
            if store.methods.isEmpty {
                ContentUnavailableView("No payment methods",
                                       systemImage: "creditcard",
                                       description: Text("Add a card or bank account to buy crypto."))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(store.methods) { m in
                        row(m)
                    }
                } footer: {
                    Text("Your default method is used for buys and recurring purchases. Swipe a method for more options.")
                }
            }

            Section("Add") {
                Button { Haptics.tap(); sheet = .card } label: {
                    Label("Debit or credit card", systemImage: "creditcard")
                }
                Button { Haptics.tap(); sheet = .bank } label: {
                    Label("Bank account", systemImage: "building.columns")
                }
            }
        }
        .tint(Theme.textPrimary)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Payment methods")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth, value: store.methods)
        .animation(.smooth, value: store.defaultID)
        .sensoryFeedback(.selection, trigger: defaultTick)
        .sensoryFeedback(.success, trigger: removedTick)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .card: AddCardSheet { m, def in store.add(m, makeDefault: def) }
            case .bank: AddBankSheet { m, def in store.add(m, makeDefault: def) }
            }
        }
        .confirmationDialog("Remove \(pendingRemoval?.title ?? "")?",
                            isPresented: Binding(get: { pendingRemoval != nil },
                                                 set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let m = pendingRemoval { store.remove(m); removedTick += 1 }
                pendingRemoval = nil
            }
        } message: {
            Text("You can add it again at any time.")
        }
    }

    private func row(_ m: PaymentMethod) -> some View {
        let isDefault = store.defaultID == m.id
        return Menu {
            if !isDefault {
                Button { setDefault(m) } label: { Label("Set as default", systemImage: "star") }
            }
            Button(role: .destructive) { askRemove(m) } label: { Label("Remove", systemImage: "trash") }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: m.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceHi, in: .rect(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title).font(Typo.body).foregroundStyle(Theme.textPrimary)
                    Text(m.subtitle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isDefault {
                    Text("Default")
                        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Space.xs).padding(.vertical, Space.xxs)
                        .background(Theme.surfaceHi, in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, Space.xxs)
            .contentShape(.rect)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { askRemove(m) } label: { Label("Remove", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            if !isDefault {
                Button { setDefault(m) } label: { Label("Default", systemImage: "star.fill") }
                    .tint(Theme.textSecondary)
            }
        }
    }

    private func setDefault(_ m: PaymentMethod) {
        store.defaultID = m.id
        defaultTick += 1
    }

    private func askRemove(_ m: PaymentMethod) {
        Haptics.warning()
        pendingRemoval = m
    }
}

// MARK: - Shared form bits

@MainActor private func errorLabel(_ message: String) -> some View {
    Label(message, systemImage: "exclamationmark.circle.fill")
        .font(Typo.caption)
        .foregroundStyle(Theme.negative)
        .transition(.opacity.combined(with: .move(edge: .top)))
}

private struct SaveBar: View {
    let title: String
    let saving: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if saving { ProgressView().tint(Theme.background) } else { Text(title) }
            }
            .font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(saving)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}

// MARK: - Add card

private struct AddCardSheet: View {
    let onAdd: (PaymentMethod, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case number, expiry, cvc, name, zip }

    @State private var number = ""
    @State private var expiry = ""
    @State private var cvc = ""
    @State private var name = ""
    @State private var zip = ""
    @State private var makeDefault = false
    @State private var touched: Set<Field> = []
    @State private var showErrors = false
    @State private var saving = false
    @State private var errorTick = 0
    @FocusState private var focus: Field?

    private var digits: String { number.filter(\.isNumber) }
    private var brand: CardBrand { CardBrand.detect(digits) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardPreview(brand: brand, digits: digits, name: name, expiry: expiry)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    input("Card number", text: $number, field: .number, keyboard: .numberPad, content: .creditCardNumber)
                        .onChange(of: number) { _, v in
                            let f = Self.formatNumber(v)
                            if f != v { number = f }
                            if f.filter(\.isNumber).count == CardBrand.detect(f.filter(\.isNumber)).numberLength { focus = .expiry }
                        }
                    HStack(spacing: Space.md) {
                        input("MM/YY", text: $expiry, field: .expiry, keyboard: .numberPad, content: nil)
                            .onChange(of: expiry) { old, v in
                                let f = Self.formatExpiry(v, deleting: v.count < old.count)
                                if f != v { expiry = f }
                                if f.count == 5 { focus = .cvc }
                            }
                        Divider()
                        input("CVC", text: $cvc, field: .cvc, keyboard: .numberPad, content: nil)
                            .onChange(of: cvc) { _, v in
                                let f = String(v.filter(\.isNumber).prefix(brand.cvcLength))
                                if f != v { cvc = f }
                            }
                    }
                } footer: { errors([.number, .expiry, .cvc]) }

                Section {
                    input("Name on card", text: $name, field: .name, keyboard: .default, content: .name)
                    input("Billing postal code", text: $zip, field: .zip, keyboard: .numbersAndPunctuation, content: .postalCode)
                } footer: { errors([.name, .zip]) }

                Section {
                    Toggle("Set as default", isOn: $makeDefault).tint(Theme.toggleTint)
                } footer: {
                    Label("Card details are encrypted. Updraft never stores your full number.", systemImage: "lock.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("Add card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { Haptics.tap(); dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { SaveBar(title: "Add card", saving: saving, action: save) }
            .onChange(of: focus) { old, _ in if let old { touched.insert(old) } }
            .onSubmit { if focus == .name { focus = .zip } else { focus = nil } }
            .sensoryFeedback(.selection, trigger: makeDefault)
            .sensoryFeedback(.selection, trigger: brand)
            .sensoryFeedback(.error, trigger: errorTick)
            .animation(.smooth(duration: 0.25), value: touched)
            .animation(.smooth(duration: 0.25), value: showErrors)
            .onAppear { focus = .number }
        }
        .interactiveDismissDisabled(!digits.isEmpty)
    }

    private func input(_ title: String, text: Binding<String>, field: Field,
                       keyboard: UIKeyboardType, content: UITextContentType?) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textContentType(content)
            .autocorrectionDisabled()
            .textInputAutocapitalization(field == .name ? .words : .characters)
            .font(field == .number ? Typo.figure : Typo.body)
            .focused($focus, equals: field)
            .submitLabel(field == .zip ? .done : .next)
            .foregroundStyle(visibleError(field) == nil ? Theme.textPrimary : Theme.negative)
    }

    @ViewBuilder
    private func errors(_ fields: [Field]) -> some View {
        let messages = fields.compactMap(visibleError)
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: Space.xxs) {
                ForEach(messages, id: \.self) { errorLabel($0) }
            }
        }
    }

    private func visibleError(_ f: Field) -> String? {
        (showErrors || touched.contains(f)) ? error(f) : nil
    }

    private func error(_ f: Field) -> String? {
        switch f {
        case .number:
            if digits.count != brand.numberLength { return "Enter the full card number" }
            return Self.luhn(digits) ? nil : "This card number isn't valid"
        case .expiry:
            let parts = expiry.split(separator: "/")
            guard parts.count == 2, let m = Int(parts[0]), let y = Int(parts[1]), (1...12).contains(m), parts[1].count == 2
            else { return "Enter expiry as MM/YY" }
            let now = Calendar.current.dateComponents([.year, .month], from: .now)
            let cy = (now.year ?? 2000) % 100, cm = now.month ?? 1
            return (y > cy || (y == cy && m >= cm)) ? nil : "This card has expired"
        case .cvc: return cvc.count == brand.cvcLength ? nil : "Enter the \(brand.cvcLength)-digit security code"
        case .name: return name.trimmingCharacters(in: .whitespaces).count >= 2 ? nil : "Enter the name on the card"
        case .zip: return zip.trimmingCharacters(in: .whitespaces).count >= 3 ? nil : "Enter your billing postal code"
        }
    }

    private func save() {
        focus = nil
        let all: [Field] = [.number, .expiry, .cvc, .name, .zip]
        guard all.allSatisfy({ error($0) == nil }) else {
            showErrors = true; errorTick += 1
            focus = all.first { error($0) != nil }
            return
        }
        Haptics.tap()
        saving = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            onAdd(PaymentMethod(kind: .card(brand, expiry: expiry), last4: String(digits.suffix(4))), makeDefault)
            Haptics.success()
            dismiss()
        }
    }

    // MARK: Formatting

    static func formatNumber(_ raw: String) -> String {
        let d = String(raw.filter(\.isNumber))
        let b = CardBrand.detect(d)
        let digits = Array(d.prefix(b.numberLength))
        var out = "", i = 0
        for g in b.groups where i < digits.count {
            if !out.isEmpty { out += " " }
            out += String(digits[i..<min(i + g, digits.count)])
            i += g
        }
        return out
    }

    static func formatExpiry(_ raw: String, deleting: Bool) -> String {
        var d = String(raw.filter(\.isNumber).prefix(4))
        if d.count == 1, let first = d.first, first > "1" { d = "0" + d }
        if d.count > 2 { return String(d.prefix(2)) + "/" + String(d.dropFirst(2)) }
        if d.count == 2 && !deleting { return d + "/" }
        return d
    }

    static func luhn(_ digits: String) -> Bool {
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard var n = ch.wholeNumberValue else { return false }
            if i % 2 == 1 { n *= 2; if n > 9 { n -= 9 } }
            sum += n
        }
        return sum % 10 == 0
    }
}

private struct CardPreview: View {
    let brand: CardBrand
    let digits: String
    let name: String
    let expiry: String

    private var masked: String {
        let padded = Array(digits.padding(toLength: brand.numberLength, withPad: "•", startingAt: 0))
        var out = "", i = 0
        for g in brand.groups { if !out.isEmpty { out += "  " }; out += String(padded[i..<i + g]); i += g }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Image(systemName: "wave.3.right").font(.system(size: 16, weight: .medium))
                Spacer()
                Text(brand.title)
                    .font(Typo.headline)
                    .contentTransition(.opacity)
                    .id(brand)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            Spacer()
            Text(masked).font(Typo.figure).tracking(1)
                .contentTransition(.numericText())
            HStack {
                Text(name.isEmpty ? "Your name" : name).lineLimit(1)
                Spacer()
                Text(expiry.isEmpty ? "MM/YY" : expiry).monospacedDigit()
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.background.opacity(0.75))
        }
        .foregroundStyle(Theme.background)
        .padding(Space.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .background(Theme.accent, in: .rect(cornerRadius: Radius.lg))
        .padding(.vertical, Space.xs)
        .animation(.spring(response: 0.4, dampingFraction: 1), value: brand)
        .animation(.smooth(duration: 0.2), value: digits)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add bank account

private struct AddBankSheet: View {
    let onAdd: (PaymentMethod, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case holder, iban, bank }

    @State private var holder = "Jon Doe"
    @State private var iban = ""
    @State private var bank = ""
    @State private var makeDefault = false
    @State private var touched: Set<Field> = []
    @State private var showErrors = false
    @State private var saving = false
    @State private var errorTick = 0
    @FocusState private var focus: Field?

    private var compact: String { iban.filter { $0.isLetter || $0.isNumber }.uppercased() }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account holder", text: $holder)
                        .textContentType(.name).focused($focus, equals: .holder)
                    TextField("IBAN", text: $iban)
                        .font(Typo.figure)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .iban)
                        .foregroundStyle(visible(.iban) == nil ? Theme.textPrimary : Theme.negative)
                        .onChange(of: iban) { _, v in
                            let f = Self.formatIBAN(v)
                            if f != v { iban = f }
                            if bank.isEmpty, compact.hasPrefix("FR"), compact.count >= 9 { bank = "BNP Paribas" }
                        }
                    TextField("Bank name", text: $bank)
                        .textContentType(.organizationName).focused($focus, equals: .bank)
                } footer: {
                    let messages = [Field.holder, .iban, .bank].compactMap(visible)
                    if messages.isEmpty {
                        Text("The account must be in your name. Transfers usually arrive in 1–2 business days.")
                    } else {
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            ForEach(messages, id: \.self) { errorLabel($0) }
                        }
                    }
                }
                Section {
                    Toggle("Set as default", isOn: $makeDefault).tint(Theme.toggleTint)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("Add bank account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Haptics.tap(); dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { SaveBar(title: "Link account", saving: saving, action: save) }
            .onChange(of: focus) { old, _ in if let old { touched.insert(old) } }
            .onSubmit { focus = focus == .holder ? .iban : (focus == .iban ? .bank : nil) }
            .sensoryFeedback(.selection, trigger: makeDefault)
            .sensoryFeedback(.error, trigger: errorTick)
            .animation(.smooth(duration: 0.25), value: touched)
            .animation(.smooth(duration: 0.25), value: showErrors)
            .onAppear { focus = .iban }
        }
        .interactiveDismissDisabled(!compact.isEmpty)
    }

    private func visible(_ f: Field) -> String? { (showErrors || touched.contains(f)) ? error(f) : nil }

    private func error(_ f: Field) -> String? {
        switch f {
        case .holder: return holder.trimmingCharacters(in: .whitespaces).count >= 2 ? nil : "Enter the account holder's name"
        case .iban: return Self.validIBAN(compact) ? nil : "Enter a valid IBAN"
        case .bank: return bank.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter your bank's name" : nil
        }
    }

    private func save() {
        focus = nil
        let all: [Field] = [.holder, .iban, .bank]
        guard all.allSatisfy({ error($0) == nil }) else {
            showErrors = true; errorTick += 1
            focus = all.first { error($0) != nil }
            return
        }
        Haptics.tap()
        saving = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            onAdd(PaymentMethod(kind: .bank(name: bank.trimmingCharacters(in: .whitespaces)),
                                last4: String(compact.suffix(4))), makeDefault)
            Haptics.success()
            dismiss()
        }
    }

    static func formatIBAN(_ raw: String) -> String {
        let c = Array(raw.filter { $0.isLetter || $0.isNumber }.uppercased().prefix(34))
        return stride(from: 0, to: c.count, by: 4).map { String(c[$0..<min($0 + 4, c.count)]) }.joined(separator: " ")
    }

    /// ISO 13616 mod-97 check.
    static func validIBAN(_ s: String) -> Bool {
        guard (15...34).contains(s.count), s.prefix(2).allSatisfy(\.isLetter) else { return false }
        let rearranged = s.dropFirst(4) + s.prefix(4)
        var rem = 0
        for ch in rearranged {
            if let d = ch.wholeNumberValue { rem = (rem * 10 + d) % 97 }
            else if let a = ch.asciiValue, ch.isLetter { rem = (rem * 100 + Int(a) - 55) % 97 }
            else { return false }
        }
        return rem == 1
    }
}

#Preview { NavigationStack { PaymentMethodsView() } }
