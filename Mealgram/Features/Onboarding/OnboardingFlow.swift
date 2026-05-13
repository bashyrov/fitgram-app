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
        case dietary
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

    /// Preview of the computed goal — surfaced on CalibrationStepView so
    /// the user sees the number before committing.
    var computedGoals: GoalCalculator.Output? {
        guard let input = goalCalculatorInput else { return nil }
        return GoalCalculator.calculate(from: input)
    }

    private var goalCalculatorInput: GoalCalculator.Input? {
        guard let height = profile.heightCm,
            let weight = profile.weightKg,
            let birth = profile.birthDate
        else { return nil }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return GoalCalculator.Input(
            heightCm: height,
            weightKg: weight,
            age: age,
            biologicalSex: profile.biologicalSex,
            activityLevel: profile.activityLevel,
            goal: profile.goal
        )
    }

    private func applyComputedGoals() {
        guard let output = computedGoals else { return }
        profile.dailyCalorieGoalKcal = output.dailyCalorieGoalKcal
        profile.proteinGoalGrams = output.proteinGoalGrams
        profile.carbsGoalGrams = output.carbsGoalGrams
        profile.fatGoalGrams = output.fatGoalGrams
    }

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

    /// Skip-ahead from the welcome screen — finishes onboarding with
    /// whatever defaults are in the OnboardingProfile (typically the
    /// pristine values). Used by the "Później" link so users who just
    /// want to peek at the app aren't forced through every step.
    func skipToEnd() {
        Task { await complete() }
    }

    // MARK: - Completion

    func complete() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        // Apply the Mifflin-St Jeor calculation right before persisting
        // so the user lands on Today with real numbers instead of the
        // 2100 / 120 / 240 / 70 defaults.
        applyComputedGoals()
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
