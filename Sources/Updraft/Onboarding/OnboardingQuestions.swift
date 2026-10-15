import SwiftUI
import UserNotifications

/// One question per screen with a progress bar, back navigation and a
/// Continue button that unlocks once the answer is valid.
struct OnboardingQuestions: View {
    @Bindable var answers: OnboardingAnswers
    let onBackFromStart: () -> Void
    let onFinish: () -> Void

    enum Step: Int, CaseIterable { case name, email, experience, goals, currency, risk, notifications }

    @State private var step: Step = .name
    @State private var forward = true
    /// One focus value shared by all steps, so moving Name to Email hands
    /// focus straight over and the keyboard never drops.
    enum Field: Hashable { case name, email }
    @FocusState private var focused: Field?

    private func field(for step: Step) -> Field? {
        switch step {
        case .name: .name
        case .email: .email
        default: nil
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                content(for: step)
                    .id(step)
                    .transition(transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomBar
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0), value: step)
        // Steps manage the keyboard themselves; the app-wide tap-to-dismiss
        // would otherwise resign it when Continue is tapped.
        .onAppear { KeyboardDismissal.isEnabled = false }
        .onDisappear { KeyboardDismissal.isEnabled = true }
    }

    /// A short, directional slide: enters from the side you're heading to,
    /// leaves a little faster than it arrives.
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        let distance: CGFloat = 36
        return .asymmetric(
            insertion: .offset(x: forward ? distance : -distance).combined(with: .opacity),
            removal: .offset(x: forward ? -distance : distance).combined(with: .opacity)
                .animation(.easeOut(duration: 0.18))
        )
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: Space.sm) {
            Button {
                Haptics.tap()
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(Theme.textPrimary).frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(height: 3)
            .animation(.spring(duration: 0.5, bounce: 0), value: progress)
            Text("\(step.rawValue + 1)/\(Step.allCases.count)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.textTertiary)
                .contentTransition(.numericText(value: Double(step.rawValue)))
                .frame(width: 40)
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.xs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: Space.xxs) {
            switch step {
            case .notifications:
                Button { enableNotifications() } label: {
                    Text("Turn on notifications").font(.system(size: 17, weight: .medium)).frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                secondary("Not now") { answers.notifications = false; next() }
            case .email:
                primary(answers.email.isEmpty ? "Skip for now" : "Continue", enabled: emailValid)
            default:
                primary("Continue", enabled: isValid)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
        .animation(.snappy(duration: 0.2), value: isValid)
    }

    private func primary(_ title: String, enabled: Bool) -> some View {
        Button {
            Haptics.tap()
            next()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity)
                .contentTransition(.interpolate)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(!enabled)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) { Haptics.tap(); action() }
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, Space.sm)
    }

    // MARK: Flow

    private var emailValid: Bool {
        let e = answers.email.trimmingCharacters(in: .whitespaces)
        return e.isEmpty || Self.looksLikeEmail(e)
    }

    static func looksLikeEmail(_ e: String) -> Bool {
        let parts = e.split(separator: "@")
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    private var isValid: Bool {
        switch step {
        case .name: !answers.firstName.isEmpty
        case .email: emailValid
        case .experience: answers.experience != nil
        case .goals: !answers.goals.isEmpty
        case .currency, .notifications: true
        case .risk: answers.risk != nil
        }
    }

    private func next() {
        guard isValid else { return }
        if let n = Step(rawValue: step.rawValue + 1) {
            forward = true
            focused = field(for: n)
            step = n
        } else {
            onFinish()
        }
    }

    private func back() {
        if let p = Step(rawValue: step.rawValue - 1) {
            forward = false
            focused = field(for: p)
            step = p
        } else {
            onBackFromStart()
        }
    }

    private func enableNotifications() {
        Haptics.tap()
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            answers.notifications = granted
            next()
        }
    }

    // MARK: Screens

    private func content(for step: Step) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                switch step {
                case .name: nameStep
                case .email: emailStep
                case .experience: experienceStep
                case .goals: goalsStep
                case .currency: currencyStep
                case .risk: riskStep
                case .notifications: notificationsStep
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.selection, trigger: answers.experience)
        .sensoryFeedback(.selection, trigger: answers.goals)
        .sensoryFeedback(.selection, trigger: answers.currency)
        .sensoryFeedback(.selection, trigger: answers.risk)
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(OnboardType.title)
                .tracking(-0.6)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(OnboardType.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .staggered(0)
    }

    // Name: an avatar that takes your initial and a greeting that echoes as you type.
    @ViewBuilder private var nameStep: some View {
        let first = answers.firstName
        Text(first.isEmpty ? "?" : String(first.prefix(1)).uppercased())
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(first.isEmpty ? Theme.textTertiary : Theme.background)
            .frame(width: 64, height: 64)
            .background(first.isEmpty ? Theme.hairline : Theme.textPrimary, in: .circle)
            .contentTransition(.interpolate)
            .animation(.spring(duration: 0.3, bounce: 0), value: first.prefix(1))
            .staggered(0)
        header("What should we\ncall you?", "This is how you'll appear in Updraft.")
        VStack(alignment: .leading, spacing: Space.sm) {
            TextField("Your name", text: $answers.name)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($focused, equals: .name)
                .onSubmit(next)
                .padding(.vertical, Space.sm)
                .overlay(alignment: .bottom) { underline(active: focused == .name) }
                .onAppear { focused = .name }
            Text(first.isEmpty ? " " : "Nice to meet you, \(first).")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .opacity(first.isEmpty ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: first.isEmpty)
        }
        .staggered(1)
    }

    // Email: inline status that morphs to a check once it looks right.
    @ViewBuilder private var emailStep: some View {
        let e = answers.email.trimmingCharacters(in: .whitespaces)
        let ok = Self.looksLikeEmail(e)
        header("Your email", "Optional. Used for receipts and account recovery.")
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "envelope")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.textTertiary)
                TextField("name@example.com", text: $answers.email)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($focused, equals: .email)
                    .onSubmit(next)
                Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 18))
                    .foregroundStyle(ok ? Theme.positive : Theme.textTertiary.opacity(e.isEmpty ? 0 : 1))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, Space.sm)
            .overlay(alignment: .bottom) { underline(active: focused == .email) }
            .onAppear { focused = .email }
            Text(emailValid ? " " : "Add the full address, like name@example.com.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.negative)
                .opacity(emailValid ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: emailValid)
        }
        .staggered(1)
    }

    @ViewBuilder private var experienceStep: some View {
        header("How familiar are\nyou with crypto?", "We'll match explanations to your level.")
        VStack(spacing: Space.sm) {
            ForEach(Array(Experience.allCases.enumerated()), id: \.element) { i, e in
                OptionCard(symbol: e.symbol, title: e.title, subtitle: e.subtitle,
                           selected: answers.experience == e) { answers.experience = e }
                    .staggered(1 + i)
            }
        }
    }

    @ViewBuilder private var goalsStep: some View {
        header("What brings you\nto Updraft?", "Choose any that fit.")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible(), spacing: Space.sm)],
                  spacing: Space.sm) {
            ForEach(Array(Goal.allCases.enumerated()), id: \.element) { i, g in
                GoalTile(goal: g, selected: answers.goals.contains(g)) {
                    if answers.goals.contains(g) { answers.goals.remove(g) } else { answers.goals.insert(g) }
                }
                .staggered(1 + i)
            }
        }
        Text(answers.goals.isEmpty ? "Nothing selected yet" : "\(answers.goals.count) selected")
            .font(.system(size: 14, weight: .regular).monospacedDigit())
            .foregroundStyle(Theme.textTertiary)
            .contentTransition(.numericText(value: Double(answers.goals.count)))
            .animation(.snappy(duration: 0.2), value: answers.goals.count)
    }

    // Currency: a live preview of the balance in the chosen currency.
    @ViewBuilder private var currencyStep: some View {
        header("Preferred currency", "Prices and balances will show in this currency.")
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Your balance would read")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
            Text(answers.currency.format(SampleData.totalBalance))
                .font(.system(size: 30, weight: .medium).monospacedDigit())
                .tracking(-0.6)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35, bounce: 0), value: answers.currency)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
        .staggered(1)
        VStack(spacing: 0) {
            ForEach(Currency.allCases) { c in
                CurrencyRow(currency: c, selected: answers.currency == c) { answers.currency = c }
                if c != Currency.allCases.last { Divider().overlay(Theme.hairline).padding(.leading, 56) }
            }
        }
        .staggered(2)
    }

    // Risk: a preview line whose swings match the choice.
    @ViewBuilder private var riskStep: some View {
        header("How do you feel\nabout risk?", "There's no wrong answer. You can change it later.")
        RiskPreview(risk: answers.risk)
            .staggered(1)
        VStack(spacing: Space.sm) {
            ForEach(Array(RiskLevel.allCases.enumerated()), id: \.element) { i, r in
                OptionCard(symbol: r.symbol, title: r.title, subtitle: r.subtitle,
                           selected: answers.risk == r) { answers.risk = r }
                    .staggered(2 + i)
            }
        }
    }

    @ViewBuilder private var notificationsStep: some View {
        header("Stay in the loop", "Price moves and arriving transfers, only when they matter. Change it anytime.")
        VStack(spacing: Space.sm) {
            NotificationCard(title: "Solana is up 4.3% today",
                             message: "Your SOL is now worth \((84 * 218.40).fiat).", time: "now")
                .staggered(2)
            NotificationCard(title: "0.25 ETH received", message: "It's in your wallet and ready to use.", time: "9:41")
                .staggered(3)
                .scaleEffect(0.96)
                .opacity(0.7)
        }
        .padding(.top, Space.sm)
    }

    private func underline(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Theme.textPrimary : Theme.hairline)
            .frame(height: active ? 1.5 : 1)
            .animation(.easeOut(duration: 0.2), value: active)
    }
}

// MARK: - Pieces

/// Selectable card. Selection fills the radio and firms up the outline.
private struct OptionCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { action() }
        } label: {
            HStack(spacing: Space.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(selected ? Theme.background : Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(selected ? Theme.textPrimary : Theme.hairline.opacity(0.6), in: .circle)
                    .symbolEffect(.bounce, value: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(.system(size: 15, weight: .regular)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().strokeBorder(selected ? Theme.textPrimary : Theme.textTertiary, lineWidth: 1.5)
                    Circle().fill(Theme.textPrimary).padding(5).scaleEffect(selected ? 1 : 0.2).opacity(selected ? 1 : 0)
                }
                .frame(width: 22, height: 22)
            }
            .padding(Space.md)
            .background(Theme.textPrimary.opacity(selected ? 0.04 : 0), in: .rect(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(selected ? Theme.textPrimary : Theme.hairline, lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Goal tile: icon animates on select, tile inverts.
private struct GoalTile: View {
    let goal: Goal
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { action() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: goal.symbol)
                        .font(.system(size: 22, weight: .regular))
                        .symbolEffect(.bounce.up, value: selected)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 18, weight: .regular))
                        .contentTransition(.symbolEffect(.replace))
                        .opacity(selected ? 1 : 0.5)
                }
                Spacer(minLength: Space.lg)
                Text(goal.title)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? Theme.background : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(Space.md)
            .background(selected ? Theme.textPrimary : .clear, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(selected ? .clear : Theme.hairline, lineWidth: 1))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CurrencyRow: View {
    let currency: Currency
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0)) { action() }
        } label: {
            HStack(spacing: Space.md) {
                Text(currency.symbol)
                    .font(.system(size: currency.symbol.count > 1 ? 12 : 17, weight: .medium))
                    .foregroundStyle(selected ? Theme.background : Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(selected ? Theme.textPrimary : .clear, in: .circle)
                    .overlay(Circle().strokeBorder(selected ? .clear : Theme.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.displayName).font(.system(size: 17, weight: .regular)).foregroundStyle(Theme.textPrimary)
                    Text(currency.rawValue).font(.system(size: 13, weight: .regular)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(selected ? 1 : 0)
                    .scaleEffect(selected ? 1 : 0.6)
            }
            .padding(.vertical, Space.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A sample price line that gets calmer or wilder with the risk choice.
private struct RiskPreview: View {
    let risk: RiskLevel?

    private var amplitude: Double {
        switch risk {
        case .cautious: 0.25
        case .balanced, nil: 0.6
        case .bold: 1.0
        }
    }

    private var values: [Double] {
        (0..<48).map { i in
            let t = Double(i) / 47
            let wave = sin(t * 9) * 0.5 + sin(t * 23 + 1) * 0.35 + sin(t * 41 + 2) * 0.15
            return t * 1.2 + wave * amplitude * 1.6
        }
    }

    private var swing: String {
        switch risk {
        case .cautious: "±3%"
        case .balanced: "±10%"
        case .bold: "±25%"
        case nil: "—"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Typical monthly swing")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(swing)
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.interpolate)
            }
            ZStack {
                Sparkline(values: values)
                    .stroke(risk == nil ? Theme.textTertiary : Theme.textPrimary,
                            style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                    .id(risk)
                    .transition(.opacity)
            }
            .frame(height: 64)
        }
        .padding(Space.md)
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Theme.hairline, lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: risk)
        .accessibilityHidden(true)
    }
}

private struct NotificationCard: View {
    let title: String
    let message: String
    let time: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            UpdraftMark(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(time).font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
                }
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.md)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.lg))
        .accessibilityHidden(true)
    }
}

/// Gentle press feedback for cards.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.2, bounce: 0), value: configuration.isPressed)
    }
}
