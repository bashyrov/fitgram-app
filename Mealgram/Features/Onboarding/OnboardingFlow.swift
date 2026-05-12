import Foundation
import OSLog
import Observation

/// Observable state machine driving the multi-step onboarding flow. Views
/// read `currentStep` + the accumulated `profile`; user actions go through
/// `advance()` / `goBack()` / `complete()`.
@MainActor
@Observable
final class OnboardingFlow {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome
        case goal
        case profile
        case firstScan
        case calibration
        case notifications
        case paywall
        case celebration

        var id: Int { rawValue }

        var progressIndex: Int { rawValue }
        /// Total *visible* steps for the progress bar — the celebration
        /// is a coda, not a step the user has to "complete", so we exclude
        /// it from the denominator.
        var progressTotal: Int { Step.allCases.count - 1 }
    }

    enum CompletionOutcome: Equatable {
        case completed
        case failed(reason: String)
    }

    private(set) var currentStep: Step = .welcome
    var profile = OnboardingProfile()
    private(set) var isSubmitting: Bool = false
    private(set) var lastError: String?

    private let authUser: AuthUser
    private let userRepository: UserRepository
    private let onFinished: @MainActor (CompletionOutcome) -> Void

    /// Surface name for the celebration step ("Witaj, X!"). Sourced from
    /// the AuthUser the flow was initialised with.
    var displayName: String? { authUser.displayName }

    init(
        authUser: AuthUser,
        userRepository: UserRepository,
        onFinished: @escaping @MainActor (CompletionOutcome) -> Void
    ) {
        self.authUser = authUser
        self.userRepository = userRepository
        self.onFinished = onFinished
    }

    // MARK: - Navigation

    func advance() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        } else {
            Task { await complete() }
        }
    }

    func goBack() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func jump(to step: Step) {
        currentStep = step
    }

    var canGoBack: Bool {
        currentStep.rawValue > 0
    }

    // MARK: - Completion

    func complete() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let user = try userRepository.ensureUser(for: authUser)
            try userRepository.completeOnboarding(user, profile: profile)
            lastError = nil
            onFinished(.completed)
        } catch {
            Logger.ui.error("Onboarding completion failed: \(String(describing: error))")
            lastError = String(localized: "Nie udało się zapisać profilu. Spróbuj ponownie.")
            onFinished(.failed(reason: String(describing: error)))
        }
    }
}
