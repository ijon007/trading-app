import SwiftUI

/// Splash → Welcome → Get started → questions → You're all set → Home.
struct OnboardingView: View {
    enum Phase { case splash, welcome, getStarted, questions, done }

    @AppStorage(OnboardingKeys.done) private var hasOnboarded = false
    @State private var phase: Phase = .splash
    @State private var answers = OnboardingAnswers()
    @Namespace private var mark
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spring: Animation { reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.6, bounce: 0) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .splash:
                SplashView(namespace: mark)
                    .transition(.opacity)
            case .welcome:
                WelcomeView(namespace: mark) { go(.getStarted) }
                    .transition(.opacity)
            case .getStarted:
                GetStartedView(namespace: mark, onStart: { go(.questions) }, onSignIn: finishAsReturningUser)
                    .transition(.opacity)
            case .questions:
                OnboardingQuestions(answers: answers, onBackFromStart: { go(.getStarted) }) {
                    answers.save()
                    go(.done)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            case .done:
                AllSetView(answers: answers) {
                    Haptics.tap()
                    withAnimation(spring) { hasOnboarded = true }
                }
                .transition(.opacity)
            }
        }
        .task {
            // Brief launch moment, then the mark glides into the Welcome header.
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.5 : 1.2))
            if phase == .splash { go(.welcome) }
        }
    }

    private func go(_ next: Phase) {
        withAnimation(spring) { phase = next }
    }

    /// Sign-in isn't built yet: skip the questions and go straight in.
    private func finishAsReturningUser() {
        Haptics.success()
        withAnimation(spring) { hasOnboarded = true }
    }
}

/// Personalized wrap-up before Home.
private struct AllSetView: View {
    let answers: OnboardingAnswers
    let onContinue: () -> Void
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            UpdraftMark(size: 72)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.background)
                        .frame(width: 26, height: 26)
                        .background(Theme.positive, in: .circle)
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2.5))
                        .offset(x: 8, y: 8)
                        .scaleEffect(done || reduceMotion ? 1 : 0.5)
                        .opacity(done ? 1 : 0)
                }
                .padding(.bottom, Space.lg)
                .staggered(0)
            Text("You're all set,\n\(answers.firstName).")
                .font(OnboardType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .staggered(1)
            Text(summary)
                .font(OnboardType.body)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .padding(.top, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
                .staggered(2)
            HStack(spacing: Space.xs) {
                ForEach(Array(chips.enumerated()), id: \.offset) { i, chip in
                    Text(chip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        .staggered(3 + i)
                }
            }
            .padding(.top, Space.md)
            Spacer()
            Button(action: onContinue) {
                Text("Go to Home").font(.system(size: 17, weight: .medium)).frame(maxWidth: .infinity)
            }
            .glassProminentButton()
            .controlSize(.large)
            .staggered(6)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.3).delay(0.35)) { done = true }
        }
        .sensoryFeedback(.success, trigger: done) { _, new in new }
    }

    private var summary: String {
        let goals = Goal.allCases.filter(answers.goals.contains).map { $0.title.lowercased() }
        let focus = goals.isEmpty ? "" : " We'll keep the focus on " + ListFormatter.localizedString(byJoining: goals) + "."
        return "Prices will show in \(answers.currency.displayName.lowercased().capitalizedFirst).\(focus)"
    }

    private var chips: [String] {
        [answers.experience?.title, answers.risk.map { "\($0.title) risk" }, answers.currency.rawValue].compactMap { $0 }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
