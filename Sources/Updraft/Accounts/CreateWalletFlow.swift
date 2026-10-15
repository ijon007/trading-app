import SwiftUI
import UIKit

/// Create wallet: intro → back up the recovery phrase → confirm 3 words → done.
/// Keys come from `Wallet.service` (a mock for now).
struct CreateWalletFlow: View {
    let name: String
    let symbol: String
    let onDone: (Account) -> Void

    private enum Step: Int { case intro, backup, confirm, done }

    @State private var step: Step = .intro
    @State private var phrase: [String] = []
    @State private var revealed = false
    @State private var copyWarning = false
    @State private var copied = false
    /// Confirm step: three random positions, asked in order.
    @State private var quiz: [Int] = []
    @State private var quizIndex = 0
    @State private var options: [String] = []
    @State private var wrong: String?
    @State private var account: Account?

    var body: some View {
        ZStack {
            switch step {
            case .intro: intro.transition(stepTransition)
            case .backup: backup.transition(stepTransition)
            case .confirm: confirm.transition(stepTransition)
            case .done: done.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.35), value: step)
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step == .done)
        .safeAreaInset(edge: .bottom) { bottomButton }
        .alert("Copy recovery phrase?", isPresented: $copyWarning) {
            Button("Copy anyway", role: .destructive) { copyPhrase() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Other apps can read your clipboard. Writing the words down is safer. The copy clears after a minute.")
        }
    }

    private var title: String {
        switch step {
        case .intro: "New wallet"
        case .backup: "Recovery phrase"
        case .confirm: "Confirm phrase"
        case .done: ""
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(x: 24)),
                    removal: .opacity.combined(with: .offset(x: -24)))
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 60, height: 60)
                    .background(Theme.surface, in: .circle)
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .staggered(0)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Your keys, your wallet").titleStyle().foregroundStyle(Theme.textPrimary)
                    Text("\(name) gets its own recovery phrase. Here's what to know first.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                .staggered(1)
                VStack(alignment: .leading, spacing: Space.md) {
                    point("list.number", "You'll get 12 words", "Together they are the master key to this wallet.")
                    point("arrow.counterclockwise", "It's the only way back in", "Lose your phone and these words restore everything.")
                    point("hand.raised", "Never share them", "Updraft will never ask for your recovery phrase.")
                }
                .staggered(2)
            }
            .padding(Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private func point(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                Text(detail).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Backup

    private var backup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Write these words down in order and keep them offline.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)

                PhraseGrid(words: phrase, revealed: $revealed)

                HStack {
                    Button {
                        Haptics.warning()
                        copyWarning = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .glassButton()
                    .controlSize(.small)
                    .tint(Theme.textPrimary)
                    .font(Typo.caption)
                    .disabled(!revealed)
                    Spacer()
                    if revealed {
                        Button("Hide") { Haptics.select(); withAnimation(.smooth(duration: 0.3)) { revealed = false } }
                            .font(Typo.callout)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Label("Anyone with these words can take everything in this wallet.", systemImage: "exclamationmark.triangle")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Space.xs)
            }
            .padding(Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private func copyPhrase() {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: phrase.joined(separator: " ")]],
                                      options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(60)])
        Haptics.success()
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { copied = false }
        }
    }

    // MARK: Confirm

    private var confirm: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.xxs) {
                ForEach(0..<quiz.count, id: \.self) { i in
                    Capsule()
                        .fill(i < quizIndex ? Theme.positive : i == quizIndex ? Theme.textPrimary : Theme.hairline)
                        .frame(height: 4)
                }
            }
            .animation(.smooth, value: quizIndex)

            if quizIndex < quiz.count {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Word #\(quiz[quizIndex] + 1)")
                        .titleStyle()
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText(value: Double(quiz[quizIndex])))
                    Text("Pick the word at this position in your phrase.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.xs), GridItem(.flexible())], spacing: Space.xs) {
                    ForEach(options, id: \.self) { word in
                        Button { pick(word) } label: {
                            Text(word)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(wrong == word ? Theme.negative : Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.md)
                                .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(wrong == word ? Theme.negative : Theme.hairline))
                        }
                        .buttonStyle(.plain)
                        .phaseAnimator([0, 1], trigger: wrong == word) { view, p in
                            view.offset(x: wrong == word && p == 1 ? 6 : 0)
                        } animation: { _ in .spring(duration: 0.15, bounce: 0.6) }
                    }
                }
                .id(quizIndex)
                .transition(.opacity)
            }
            Spacer()
        }
        .padding(Space.md)
        .animation(.smooth(duration: 0.3), value: quizIndex)
    }

    private func startQuiz() {
        quiz = Array(phrase.indices.shuffled().prefix(3)).sorted()
        quizIndex = 0
        makeOptions()
    }

    private func makeOptions() {
        guard quizIndex < quiz.count else { return }
        let answer = phrase[quiz[quizIndex]]
        var pool = Set(phrase).subtracting([answer])
        while pool.count < 3 { pool.insert(MockWalletService.words.randomElement() ?? "zoo") }
        options = ([answer] + Array(pool.shuffled().prefix(3))).shuffled()
        wrong = nil
    }

    private func pick(_ word: String) {
        guard quizIndex < quiz.count else { return }
        if word == phrase[quiz[quizIndex]] {
            Haptics.select()
            quizIndex += 1
            if quizIndex == quiz.count { finish() } else { makeOptions() }
        } else {
            Haptics.error()
            wrong = word
        }
    }

    private func finish() {
        let created = Account(id: UUID().uuidString, name: name, symbol: symbol, holdings: [],
                              address: Wallet.service.address(forPhrase: phrase))
        account = created
        Wallet.service.storePhrase(phrase, for: created.id)
        Haptics.success()
        step = .done
    }

    // MARK: Done

    private var done: some View {
        VStack(spacing: Space.md) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: step == .done)
            Text("Wallet created").titleStyle().foregroundStyle(Theme.textPrimary)
            Text("\(name) is backed up and ready.")
                .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            if let address = account?.address {
                Text(Account.shortAddress(address))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background(Theme.surface, in: .capsule)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Space.md)
    }

    // MARK: Bottom button

    @ViewBuilder
    private var bottomButton: some View {
        switch step {
        case .intro:
            primary("Create recovery phrase") {
                phrase = Wallet.service.generatePhrase()
                revealed = false
                step = .backup
            }
        case .backup:
            primary("I've written it down", enabled: revealed) {
                startQuiz()
                step = .confirm
            }
        case .confirm:
            EmptyView()
        case .done:
            primary("Done") { if let account { onDone(account) } }
        }
    }

    private func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title).font(Typo.headline).frame(maxWidth: .infinity)
        }
        .glassProminentButton()
        .controlSize(.large)
        .disabled(!enabled)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
    }
}
