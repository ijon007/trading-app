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
    @FocusState private var focused: Bool
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
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0), value: step)
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: Space.md) {
            Button {
                Haptics.tap()
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(Theme.textPrimary).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .animation(.spring(duration: 0.5, bounce: 0), value: progress)
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.xs)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: Space.xs) {
            switch step {
            case .notifications:
                Button { enableNotifications() } label: {
                    Text("Turn on notifications").font(Typo.headline).frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                secondary("Not now") { answers.notifications = false; next() }
            case .email:
                primary(answers.email.isEmpty ? "Skip" : "Continue", enabled: emailValid)
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
            Text(title).font(Typo.headline).frame(maxWidth: .infinity).contentTransition(.opacity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(!enabled)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) { Haptics.tap(); action() }
            .font(Typo.callout.weight(.medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, Space.xs)
    }

    // MARK: Flow

    private var emailValid: Bool {
        let e = answers.email.trimmingCharacters(in: .whitespaces)
        return e.isEmpty || (e.contains("@") && e.split(separator: "@").last?.contains(".") == true)
    }

    private var isValid: Bool {
        switch step {
        case .name: !answers.firstName.isEmpty
        case .email: emailValid
        case .experience: answers.experience != nil
        case .goals: !answers.goals.isEmpty
        case .currency: true
        case .risk: answers.risk != nil
        case .notifications: true
        }
    }

    private func next() {
        guard isValid else { return }
        focused = false
        if let n = Step(rawValue: step.rawValue + 1) {
            forward = true
            step = n
        } else {
            onFinish()
        }
    }

    private func back() {
        focused = false
        if let p = Step(rawValue: step.rawValue - 1) {
            forward = false
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

    @ViewBuilder
    private func content(for step: Step) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                switch step {
                case .name:
                    header("What should we\ncall you?", "This is how you'll appear in Updraft.")
                    TextField("Your name", text: $answers.name)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .textContentType(.givenName)
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit(next)
                        .padding(.vertical, Space.sm)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        .onAppear { focused = true }
                case .email:
                    header("Your email", "Optional. For receipts and account recovery.")
                    TextField("name@example.com", text: $answers.email)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit(next)
                        .padding(.vertical, Space.sm)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        .onAppear { focused = true }
                    if !emailValid {
                        Text("That email doesn't look right.")
                            .font(Typo.callout).foregroundStyle(Theme.negative)
                            .transition(.opacity)
                    }
                case .experience:
                    header("How much crypto\nexperience do you have?", "We'll adjust explanations to fit.")
                    VStack(spacing: Space.sm) {
                        ForEach(Experience.allCases) { e in
                            OptionCard(symbol: e.symbol, title: e.title, subtitle: e.subtitle,
                                       selected: answers.experience == e) { answers.experience = e }
                        }
                    }
                case .goals:
                    header("What brings you\nto Updraft?", "Pick as many as you like.")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible(), spacing: Space.sm)],
                              spacing: Space.sm) {
                        ForEach(Goal.allCases) { g in
                            GoalChip(goal: g, selected: answers.goals.contains(g)) {
                                if answers.goals.contains(g) { answers.goals.remove(g) } else { answers.goals.insert(g) }
                            }
                        }
                    }
                case .currency:
                    header("Preferred currency", "Prices and balances will show in this currency.")
                    VStack(spacing: 0) {
                        ForEach(Currency.allCases) { c in
                            CurrencyRow(currency: c, selected: answers.currency == c) { answers.currency = c }
                            if c != Currency.allCases.last { Divider().overlay(Theme.hairline).padding(.leading, 56) }
                        }
                    }
                case .risk:
                    header("How do you feel\nabout risk?", "There's no wrong answer.")
                    VStack(spacing: Space.sm) {
                        ForEach(RiskLevel.allCases) { r in
                            OptionCard(symbol: r.symbol, title: r.title, subtitle: r.subtitle,
                                       selected: answers.risk == r) { answers.risk = r }
                        }
                    }
                case .notifications:
                    header("Stay in the loop", "Get price alerts and a heads-up when transfers land. You can change this anytime.")
                    NotificationPreview()
                        .padding(.top, Space.md)
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
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(Typo.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Pieces

/// Selectable card: icon, title, subtitle; outlined when selected.
private struct OptionCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { action() }
        } label: {
            HStack(spacing: Space.md) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 28)
                    .symbolEffect(.bounce, value: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(Space.md)
            .contentShape(.rect(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(selected ? Theme.textPrimary : Theme.hairline, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct GoalChip: View {
    let goal: Goal
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { action() }
        } label: {
            VStack(alignment: .leading, spacing: Space.md) {
                Image(systemName: goal.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce, value: selected)
                Text(goal.title)
                    .font(Typo.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? Theme.background : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
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
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: Space.md) {
                Text(currency.symbol)
                    .font(.system(size: currency.symbol.count > 1 ? 12 : 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.displayName).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text(currency.rawValue).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
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

/// A sample notification card to show what alerts look like.
private struct NotificationPreview: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.sm) {
            UpdraftMark(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Updraft").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("now").font(Typo.caption).foregroundStyle(Theme.textTertiary)
                }
                Text("Solana is up 4.3% today. Your SOL is now worth \((84 * 218.40).fiat).")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.md)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.lg))
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : -16)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.2).delay(0.25)) { shown = true }
        }
        .accessibilityHidden(true)
    }
}

/// Gentle press feedback for cards.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.25, bounce: 0), value: configuration.isPressed)
    }
}
