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
                    Haptics.success()
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
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.background)
                .frame(width: 72, height: 72)
                .background(Theme.textPrimary, in: .circle)
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .symbolEffect(.bounce, value: shown)
                .padding(.bottom, Space.lg)
            Text("You're all set,\n\(answers.firstName).")
                .font(.system(size: 40, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(summary)
                .font(Typo.body)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.xs) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                }
            }
            .padding(.top, Space.md)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            Spacer()
            Button(action: onContinue) {
                Text("Go to Home").font(Typo.headline).frame(maxWidth: .infinity)
            }
            .glassProminentButton()
            .controlSize(.large)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.6, bounce: 0.25).delay(0.1)) { shown = true }
        }
    }

    private var summary: String {
        let goals = answers.goals.isEmpty ? "" : " Focused on " + Goal.allCases.filter(answers.goals.contains).map { $0.title.lowercased() }.joined(separator: ", ") + "."
        return "Your Updraft is ready, with prices in \(answers.currency.displayName.lowercased().capitalizedFirst).\(goals)"
    }

    private var chips: [String] {
        [answers.experience?.title, answers.risk?.title, answers.currency.rawValue].compactMap { $0 }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
