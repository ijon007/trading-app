import SwiftUI

// MARK: - Model (mock state, no backend)

enum VerificationStatus: Equatable {
    case notStarted, inProgress, inReview, verified

    var title: String {
        switch self {
        case .notStarted: "Not verified"
        case .inProgress: "In progress"
        case .inReview: "In review"
        case .verified: "Verified"
        }
    }
    var message: String {
        switch self {
        case .notStarted: "Verify your identity to unlock deposits, withdrawals and higher limits. It takes about 3 minutes."
        case .inProgress: "Pick up where you left off. Your progress is saved."
        case .inReview: "We're reviewing your documents. This usually takes a few minutes."
        case .verified: "Your identity is confirmed. All features and limits are unlocked."
        }
    }
    var icon: String {
        switch self {
        case .notStarted: "person.badge.shield.checkmark"
        case .inProgress: "hourglass"
        case .inReview: "clock.badge.checkmark"
        case .verified: "checkmark.seal.fill"
        }
    }
}

enum IDDocument: String, CaseIterable, Identifiable {
    case passport, idCard, license
    var id: String { rawValue }
    var title: String {
        switch self {
        case .passport: "Passport"
        case .idCard: "National ID card"
        case .license: "Driver's license"
        }
    }
    var icon: String {
        switch self {
        case .passport: "book.closed"
        case .idCard: "person.text.rectangle"
        case .license: "car"
        }
    }
    var needsBack: Bool { self != .passport }
}

enum KYCStep: Int, CaseIterable, Comparable {
    case details, document, capture, selfie, review
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    var title: String {
        switch self {
        case .details: "Confirm your details"
        case .document: "Choose a document"
        case .capture: "Scan your document"
        case .selfie: "Take a selfie"
        case .review: "Review and submit"
        }
    }
    var short: String {
        switch self {
        case .details: "Personal details"
        case .document: "Document type"
        case .capture: "Document photos"
        case .selfie: "Selfie"
        case .review: "Review"
        }
    }
    var icon: String {
        switch self {
        case .details: "person"
        case .document: "doc.text.viewfinder"
        case .capture: "camera.viewfinder"
        case .selfie: "face.smiling"
        case .review: "checklist"
        }
    }
}

@Observable
final class VerificationModel {
    var status: VerificationStatus = .notStarted
    var step: KYCStep = .details
    var completed: Set<KYCStep> = []
    var info = PersonalInfo()
    var document: IDDocument?
    var frontCaptured = false
    var backCaptured = false
    var selfieCaptured = false

    var progress: Double { Double(completed.count) / Double(KYCStep.allCases.count) }

    func complete(_ s: KYCStep) {
        completed.insert(s)
        if let next = KYCStep(rawValue: s.rawValue + 1) { step = next }
        status = .inProgress
    }

    func reset() {
        status = .notStarted; step = .details; completed = []
        document = nil; frontCaptured = false; backCaptured = false; selfieCaptured = false
    }
}

// MARK: - Overview

struct VerificationView: View {
    @State private var model = VerificationModel()
    @State private var showFlow = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                statusCard
                stepsCard
                if model.status == .verified || model.status == .inReview { limitsCard }
                privacyNote
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
            .animation(.smooth, value: model.status)
        }
        .background(Theme.background)
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { primaryAction }
        .fullScreenCover(isPresented: $showFlow) {
            VerificationFlow(model: model)
        }
    }

    private var statusCard: some View {
        VStack(spacing: Space.md) {
            Image(systemName: model.status.icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(model.status == .verified ? Theme.positive : Theme.textPrimary)
                .symbolEffect(.pulse, isActive: model.status == .inReview)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 84, height: 84)
                .background(Theme.surfaceHi, in: Circle())
            VStack(spacing: Space.xs) {
                Text(model.status.title).titleStyle().foregroundStyle(Theme.textPrimary)
                    .contentTransition(.opacity)
                Text(model.status.message)
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if model.status == .inProgress {
                ProgressView(value: model.progress)
                    .tint(Theme.accent)
                    .padding(.horizontal, Space.lg)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity)
        .surfaceCard()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Steps").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                .padding(.bottom, Space.xs)
            ForEach(KYCStep.allCases, id: \.self) { s in
                let done = model.completed.contains(s) || model.status == .inReview || model.status == .verified
                HStack(spacing: Space.sm) {
                    Image(systemName: done ? "checkmark.circle.fill" : s.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(done ? Theme.positive : Theme.textSecondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 28)
                    Text(s.short).font(Typo.body).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if !done && s == model.step && model.status == .inProgress {
                        Text("Next").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, Space.row)
                if s != .review { Divider().overlay(Theme.hairline).padding(.leading, 40) }
            }
        }
        .padding(Space.md)
        .surfaceCard()
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Limits").font(Typo.headline).foregroundStyle(Theme.textPrimary)
            LabeledContent("Daily deposit", value: model.status == .verified ? "$50,000" : "Pending")
            LabeledContent("Daily withdrawal", value: model.status == .verified ? "$25,000" : "Pending")
        }
        .font(Typo.body)
        .padding(Space.md)
        .surfaceCard()
    }

    private var privacyNote: some View {
        Label("Your data is encrypted and only used to verify your identity.", systemImage: "lock.shield")
            .font(Typo.caption).foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private var primaryAction: some View {
        Group {
            switch model.status {
            case .notStarted, .inProgress:
                Button {
                    Haptics.tap(); showFlow = true
                } label: {
                    Text(model.status == .notStarted ? "Start verification" : "Continue")
                        .font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
                }
                .glassProminentButton()
                .controlSize(.large)
            case .inReview:
                // Mock: lets you preview the approved state.
                Button {
                    Haptics.success(); model.status = .verified
                } label: {
                    Text("Simulate approval").font(Typo.headline).frame(maxWidth: .infinity)
                }
                .glassButton().controlSize(.large)
            case .verified:
                EmptyView()
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }
}

// MARK: - Flow

private struct VerificationFlow: View {
    @Bindable var model: VerificationModel
    @Environment(\.dismiss) private var dismiss
    @State private var forward = true
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !submitted {
                    progressHeader
                }
                ZStack {
                    content
                        .id(submitted ? -1 : model.step.rawValue)
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .background(Theme.background)
            .toolbar {
                if !submitted {
                    ToolbarItem(placement: .topBarLeading) {
                        if model.step != .details {
                            Button { back() } label: { Image(systemName: "chevron.left") }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Haptics.tap(); dismiss() } label: { Image(systemName: "xmark") }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: model.step)
        }
        .interactiveDismissDisabled(submitted)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xxs) {
                ForEach(KYCStep.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s <= model.step ? Theme.accent : Theme.surfaceHi)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.sm)
        .animation(.smooth, value: model.step)
    }

    @ViewBuilder
    private var content: some View {
        if submitted {
            SubmittedStep { dismiss() }
        } else {
            switch model.step {
            case .details: DetailsStep(model: model) { advance() }
            case .document: DocumentStep(model: model) { advance() }
            case .capture: CaptureStep(model: model) { advance() }
            case .selfie: SelfieStep(model: model) { advance() }
            case .review: ReviewStep(model: model, edit: jump) { submit() }
            }
        }
    }

    private func advance() {
        Haptics.tap()
        forward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { model.complete(model.step) }
    }

    private func back() {
        Haptics.tap()
        guard let prev = KYCStep(rawValue: model.step.rawValue - 1) else { return }
        forward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { model.step = prev }
    }

    private func jump(_ s: KYCStep) {
        Haptics.tap()
        forward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { model.step = s }
    }

    private func submit() {
        Haptics.success()
        forward = true
        model.completed.insert(.review)
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) {
            submitted = true
            model.status = .inReview
        }
    }
}

// MARK: - Step scaffold

private struct StepScaffold<Content: View>: View {
    let step: KYCStep?
    let title: String
    let subtitle: String
    let actionTitle: String
    let actionEnabled: Bool
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).titleStyle().foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                content
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: action) {
                Text(actionTitle).font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
            }
            .glassProminentButton()
            .controlSize(.large)
            .disabled(!actionEnabled)
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.xs)
            .animation(.smooth, value: actionEnabled)
        }
    }
}

// MARK: Step 1 — details

private struct DetailsStep: View {
    @Bindable var model: VerificationModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .details, title: KYCStep.details.title,
                     subtitle: "Make sure these match your ID exactly.",
                     actionTitle: "Looks good", actionEnabled: valid, action: next) {
            VStack(spacing: 0) {
                row("First name", $model.info.firstName, .givenName)
                Divider().overlay(Theme.hairline)
                row("Last name", $model.info.lastName, .familyName)
                Divider().overlay(Theme.hairline)
                DatePicker("Date of birth", selection: $model.info.birthDate, in: ...Date.now,
                           displayedComponents: .date)
                    .padding(.vertical, Space.row)
                Divider().overlay(Theme.hairline)
                Picker("Country", selection: $model.info.country) {
                    ForEach(PersonalInfo.countries, id: \.self) { Text($0).tag($0) }
                }
                .padding(.vertical, Space.xxs)
                .tint(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Typo.body)
            .padding(.horizontal, Space.md)
            .surfaceCard()
            if !model.info.isAdult {
                Label("You must be at least 18 to verify.", systemImage: "exclamationmark.circle.fill")
                    .font(Typo.caption).foregroundStyle(Theme.negative)
            }
        }
        .sensoryFeedback(.selection, trigger: model.info.country)
        .dismissKeyboardOnTap()
    }

    private var valid: Bool {
        model.info.error(for: .firstName) == nil && model.info.error(for: .lastName) == nil && model.info.isAdult
    }

    private func row(_ title: String, _ text: Binding<String>, _ type: UITextContentType) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .textContentType(type)
                .autocorrectionDisabled()
        }
        .padding(.vertical, Space.row)
    }
}

// MARK: Step 2 — document type

private struct DocumentStep: View {
    @Bindable var model: VerificationModel
    let next: () -> Void

    var body: some View {
        StepScaffold(step: .document, title: KYCStep.document.title,
                     subtitle: "Issued in \(model.info.country). It must be valid and not expired.",
                     actionTitle: "Continue", actionEnabled: model.document != nil, action: next) {
            VStack(spacing: Space.sm) {
                ForEach(IDDocument.allCases) { doc in
                    let selected = model.document == doc
                    Button {
                        withAnimation(.snappy) {
                            if model.document != doc { model.frontCaptured = false; model.backCaptured = false }
                            model.document = doc
                        }
                    } label: {
                        HStack(spacing: Space.sm) {
                            Image(systemName: doc.icon)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(Theme.surfaceHi, in: .rect(cornerRadius: Radius.sm))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title).font(Typo.headline)
                                Text(doc.needsBack ? "Front and back" : "Photo page")
                                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Space.md)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .surfaceCard(radius: Radius.md)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Theme.accent, lineWidth: selected ? 1.5 : 0)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: model.document)
    }
}

// MARK: Step 3 — document capture (mock camera)

private struct CaptureStep: View {
    @Bindable var model: VerificationModel
    let next: () -> Void
    @State private var capturing = false

    private var doc: IDDocument { model.document ?? .passport }
    private var onBack: Bool { doc.needsBack && model.frontCaptured }
    private var done: Bool { model.frontCaptured && (!doc.needsBack || model.backCaptured) }

    var body: some View {
        StepScaffold(step: .capture, title: KYCStep.capture.title,
                     subtitle: done ? "Photos look sharp and readable." :
                        "Place the \(onBack ? "back" : "front") of your \(doc.title.lowercased()) in the frame.",
                     actionTitle: done ? "Continue" : (capturing ? "Capturing…" : "Capture"),
                     actionEnabled: !capturing,
                     action: done ? next : capture) {
            viewfinder
            HStack(spacing: Space.sm) {
                thumb("Front", captured: model.frontCaptured)
                if doc.needsBack { thumb("Back", captured: model.backCaptured) }
            }
            tips
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg).fill(Color.black.opacity(0.85))
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(done ? Theme.positive : .white.opacity(0.9),
                              style: StrokeStyle(lineWidth: 2, dash: done ? [] : [10, 6]))
                .padding(Space.lg)
                .aspectRatio(doc == .passport ? 1.42 : 1.58, contentMode: .fit)
            if capturing {
                RoundedRectangle(cornerRadius: Radius.lg).fill(.white).opacity(0.6)
                    .transition(.opacity)
            }
            Image(systemName: done ? "checkmark.circle.fill" : doc.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(done ? Theme.positive : .white.opacity(0.5))
                .contentTransition(.symbolEffect(.replace))
        }
        .aspectRatio(1.3, contentMode: .fit)
        .animation(.smooth, value: done)
    }

    private func thumb(_ title: String, captured: Bool) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: captured ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(captured ? Theme.positive : Theme.textTertiary)
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(Typo.callout).foregroundStyle(Theme.textPrimary)
            Spacer()
            if captured {
                Button("Retake") { retake(title) }
                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Space.sm)
        .glassCard(radius: Radius.md)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Label("Good lighting, no glare", systemImage: "sun.max")
            Label("All four corners visible", systemImage: "viewfinder")
        }
        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
    }

    private func capture() {
        Haptics.medium()
        withAnimation(.easeOut(duration: 0.12)) { capturing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.smooth) {
                capturing = false
                if !model.frontCaptured { model.frontCaptured = true } else if doc.needsBack { model.backCaptured = true }
            }
            Haptics.success()
        }
    }

    private func retake(_ side: String) {
        Haptics.tap()
        withAnimation(.smooth) {
            if side == "Front" { model.frontCaptured = false; model.backCaptured = false }
            else { model.backCaptured = false }
        }
    }
}

// MARK: Step 4 — selfie (mock liveness)

private struct SelfieStep: View {
    @Bindable var model: VerificationModel
    let next: () -> Void
    @State private var scanning = false
    @State private var scan: Double = 0

    var body: some View {
        StepScaffold(step: .selfie, title: KYCStep.selfie.title,
                     subtitle: model.selfieCaptured ? "Got it. You look great." :
                        "Center your face in the circle and hold still.",
                     actionTitle: model.selfieCaptured ? "Continue" : (scanning ? "Hold still…" : "Start"),
                     actionEnabled: !scanning,
                     action: model.selfieCaptured ? next : start) {
            ZStack {
                Circle().fill(Color.black.opacity(0.85))
                Image(systemName: "person.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(.white.opacity(0.18))
                    .offset(y: 24)
                    .clipShape(Circle())
                Circle().stroke(Theme.surfaceHi, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: model.selfieCaptured ? 1 : scan)
                    .stroke(model.selfieCaptured ? Theme.positive : Theme.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if model.selfieCaptured {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.positive)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 260, height: 260)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            if model.selfieCaptured {
                Button("Retake selfie") {
                    Haptics.tap()
                    withAnimation(.smooth) { model.selfieCaptured = false; scan = 0 }
                }
                .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
            } else {
                Label("Remove glasses or hats. Good, even light.", systemImage: "lightbulb")
                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func start() {
        Haptics.tap()
        scanning = true
        withAnimation(.linear(duration: 1.6)) { scan = 1 }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                model.selfieCaptured = true
                scanning = false
            }
            Haptics.success()
        }
    }
}

// MARK: Step 5 — review

private struct ReviewStep: View {
    @Bindable var model: VerificationModel
    let edit: (KYCStep) -> Void
    let submit: () -> Void
    @State private var consent = false

    var body: some View {
        StepScaffold(step: .review, title: KYCStep.review.title,
                     subtitle: "Check everything before you send it.",
                     actionTitle: "Submit", actionEnabled: consent, action: submit) {
            VStack(spacing: 0) {
                item("Name", "\(model.info.firstName) \(model.info.lastName)", .details)
                Divider().overlay(Theme.hairline)
                item("Date of birth", model.info.birthDate.formatted(date: .long, time: .omitted), .details)
                Divider().overlay(Theme.hairline)
                item("Document", model.document?.title ?? "—", .document)
                Divider().overlay(Theme.hairline)
                item("Photos", (model.document?.needsBack ?? false) ? "Front and back" : "Photo page", .capture)
                Divider().overlay(Theme.hairline)
                item("Selfie", "Captured", .selfie)
            }
            .padding(.horizontal, Space.md)
            .surfaceCard()
            Toggle(isOn: $consent) {
                Text("I confirm this information is accurate and agree to identity checks.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            .tint(Theme.toggleTint)
        }
        .sensoryFeedback(.selection, trigger: consent)
    }

    private func item(_ title: String, _ value: String, _ step: KYCStep) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                Text(value).font(Typo.body).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button("Edit") { edit(step) }
                .font(Typo.callout).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Space.row)
    }
}

// MARK: Submitted

private struct SubmittedStep: View {
    let done: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: appeared)
                .frame(width: 120, height: 120)
                .background(Theme.surfaceHi, in: Circle())
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: Space.xs) {
                Text("Submitted").titleStyle().foregroundStyle(Theme.textPrimary)
                Text("We're reviewing your documents. You'll get a notification as soon as you're verified, usually within minutes.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.lg)
            Spacer()
            Button {
                Haptics.tap(); done()
            } label: {
                Text("Done").font(Typo.headline).frame(maxWidth: .infinity).padding(.vertical, Space.xxs)
            }
            .glassProminentButton()
            .controlSize(.large)
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.xs)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
    }
}

#Preview { NavigationStack { VerificationView() } }
