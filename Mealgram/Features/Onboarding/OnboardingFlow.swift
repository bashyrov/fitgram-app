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
        /// Name + email capture. Lives right after Welcome so the rest
        /// of the flow can address the user by name.
        case account
        case goal
        case profile
        /// Pace + target-weight picker. Skipped when goal is not
        /// `.lose` / `.gain` — flow auto-advances over it.
        case pace
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

    /// Lazily loaded once the user reaches calibration. UI renders a
    /// loading skeleton until non-nil. Persisted to User row inside
    /// `complete()` so Profile can re-display it later.
    private(set) var recommendations: Recommendations?
    private(set) var isLoadingRecommendations: Bool = false

    private let authUser: AuthUser
    private let userRepository: UserRepository
    private let recommendationsService: any RecommendationsServing
    private let userProfileService: UserProfileServing?
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

    /// Full target bundle (kcal + macros + fiber + water + bmr + tdee +
    /// safetyFloor flag). Drives the AI results screen.
    var computedTargets: GoalCalculator.Targets? {
        guard let input = goalCalculatorInput else { return nil }
        return GoalCalculator.calculateTargets(from: input)
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
            goal: profile.goal,
            paceKgPerWeek: profile.goalPaceKgPerWeek
        )
    }

    private func applyComputedTargets() {
        guard let targets = computedTargets else { return }
        profile.dailyCalorieGoalKcal = targets.dailyCalorieGoalKcal
        profile.proteinGoalGrams = targets.proteinGoalGrams
        profile.carbsGoalGrams = targets.carbsGoalGrams
        profile.fatGoalGrams = targets.fatGoalGrams
        profile.fiberGoalGrams = targets.fiberGoalGrams
        profile.waterGoalMl = targets.waterGoalMl
        profile.hitSafetyFloor = targets.hitSafetyFloor
    }

    /// Kicks off the AI recommendations call. Idempotent — re-entering
    /// the calibration step won't re-fire while one is in flight, and
    /// won't re-fire once `recommendations` is non-nil for the current
    /// profile snapshot.
    func loadRecommendationsIfNeeded() async {
        guard recommendations == nil, !isLoadingRecommendations else { return }
        applyComputedTargets()
        guard let request = profile.recommendationsRequest else { return }
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            recommendations = try await recommendationsService.generate(for: request)
        } catch {
            Logger.coach.error("Onboarding recommendations failed: \(String(describing: error))")
        }
    }

    init(
        authUser: AuthUser,
        userRepository: UserRepository,
        recommendationsService: any RecommendationsServing,
        userProfileService: UserProfileServing? = nil,
        onFinished: @escaping @MainActor (CompletionOutcome) -> Void
    ) {
        self.authUser = authUser
        self.userRepository = userRepository
        self.recommendationsService = recommendationsService
        self.userProfileService = userProfileService
        self.onFinished = onFinished
    }

    // MARK: - Navigation

    func advance() {
        var next = Step(rawValue: currentStep.rawValue + 1)
        while let candidate = next, shouldSkip(step: candidate) {
            next = Step(rawValue: candidate.rawValue + 1)
        }
        if let resolved = next {
            currentStep = resolved
        } else {
            Task { await complete() }
        }
    }

    func goBack() {
        var previous = Step(rawValue: currentStep.rawValue - 1)
        while let candidate = previous, shouldSkip(step: candidate) {
            previous = Step(rawValue: candidate.rawValue - 1)
        }
        guard let resolved = previous else { return }
        currentStep = resolved
    }

    /// Steps that don't apply to the current profile snapshot get
    /// skipped both forward and back so the user never sees a dead-end
    /// "Next" / "Back" tap.
    private func shouldSkip(step: Step) -> Bool {
        switch step {
        case .pace:
            return !profile.goal.requiresPaceAndTarget
        default:
            return false
        }
    }

    func jump(to step: Step) {
        currentStep = step
    }

    var canGoBack: Bool {
        currentStep.rawValue > 0
    }

    /// Skip-ahead from the welcome screen — finishes onboarding with
    /// whatever defaults are in the OnboardingProfile (typically the
    /// pristine values). Used by the "Later" link so users who just
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
        applyComputedTargets()
        do {
            let user = try userRepository.ensureUser(for: authUser)
            try userRepository.completeOnboarding(user, profile: profile)
            if let recommendations {
                try? userProfileService?.storeRecommendations(recommendations)
            }
            lastError = nil
            onFinished(.completed)
        } catch {
            Logger.ui.error("Onboarding completion failed: \(String(describing: error))")
            lastError = L("Couldn't save your profile. Please try again.")
            onFinished(.failed(reason: String(describing: error)))
        }
    }
}
