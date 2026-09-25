import Foundation
import OSLog
import SwiftData

/// Higher-level façade over `UserRepository` for the Goals & Targets
/// surfaces in Profile. Anywhere outside of auth/onboarding, code should
/// reach for this — UserRepository is the auth-time bootstrap layer.
@MainActor
protocol UserProfileServing: AnyObject {
    func currentProfile() throws -> User?

    /// Records a new weigh-in to WeightEntry history *and* updates
    /// the canonical `User.weightKg`. Triggers a target recalculation
    /// for non-overridden fields.
    func updateWeight(_ kg: Double, note: String?) throws

    /// Persists a change to the activity level + reruns target
    /// recalculation for non-overridden fields.
    func updateActivityLevel(_ level: ActivityLevel) throws

    /// Persists a manual macro override. Sets `macrosOverridden` so
    /// the recalculator stops touching them.
    func overrideMacros(protein: Int, carbs: Int, fat: Int) throws

    /// Manually overrides daily calorie target. Sets `caloriesOverridden`.
    func overrideCalories(_ kcal: Int) throws

    /// Manually overrides daily water target. Sets `waterOverridden`.
    func overrideWater(_ ml: Int) throws

    /// Drops all override flags and recomputes targets from current
    /// profile snapshot. Used by Profile → "Wróć do zalecanych".
    func resetTargetsToRecommended() throws

    /// Returns the same calculator output the onboarding calibration
    /// screen shows, using the currently saved profile.
    func recommendedTargetsPreview() throws -> GoalCalculator.Targets?

    /// Recomputes the calorie target from the saved onboarding inputs,
    /// clears the calorie override, then refreshes Ola's recommendation
    /// bundle through the same AI/fallback path onboarding uses.
    func recalculateCaloriesWithOla(using recommendationsService: any RecommendationsServing) async throws
    func recalculateTargetsWithOla(
        profile: CalorieRecalculationProfile,
        using recommendationsService: any RecommendationsServing
    ) async throws

    /// Saves a new main goal (kind + optional pace/target weight) and
    /// recomputes targets accordingly. Caller is responsible for
    /// validating pace is within safe ranges before calling.
    func updateMainGoal(
        kind: GoalKind,
        paceKgPerWeek: Double?,
        startWeightKg: Double?,
        targetWeightKg: Double?
    ) throws

    /// Stores the most recent `Recommendations` payload on the user
    /// row so the Profile screen can re-render it without re-asking
    /// the Worker.
    func storeRecommendations(_ recommendations: Recommendations) throws

    func loadStoredRecommendations() throws -> Recommendations?
}

struct CalorieRecalculationProfile: Sendable {
    var weightKg: Double
    var heightCm: Int
    var birthDate: Date
    var biologicalSex: BiologicalSex
    var activityLevel: ActivityLevel
    var goalKind: GoalKind
    var goalStartWeightKg: Double?
    var goalTargetWeightKg: Double?
    var goalPaceKgPerWeek: Double?
    var dietMacroPreset: DietMacroPreset
}

/// SwiftData-backed implementation. All work happens on `@MainActor`
/// because `ModelContext` isn't Sendable.
@MainActor
final class UserProfileService: UserProfileServing {
    static let weightRecalculationThresholdKg = 2.0

    private let container: ModelContainer
    private let sessionRemoteID: () -> String?

    init(container: ModelContainer, sessionRemoteID: @escaping () -> String?) {
        self.container = container
        self.sessionRemoteID = sessionRemoteID
    }

    func currentProfile() throws -> User? {
        guard let remoteID = sessionRemoteID() else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        return try context.fetch(descriptor).first
    }

    func updateWeight(_ kg: Double, note: String?) throws {
        guard kg > 0 else { return }
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        let shouldRecalculate = shouldRecalculateTargets(for: user, newWeightKg: kg)
        user.weightKg = kg
        user.updatedAt = Date()
        if shouldRecalculate {
            recalculate(user: user, reasonWeightKg: kg)
        }
        if let pace = user.goalPaceKgPerWeek, let target = user.goalTargetWeightKg {
            if pace > 0 {
                user.goalEstimatedEndDate = GoalProjection.estimatedEndDate(
                    currentWeightKg: kg,
                    targetWeightKg: target,
                    paceKgPerWeek: pace
                )
            }
        }
        context.insert(
            WeightEntry(
                userRemoteID: user.remoteID,
                weightKg: kg,
                note: note
            )
        )
        regenerateRecommendations(user: user)
        try context.save()
        notifyGoalsChanged()
        Logger.persistence.notice("UserProfileService updated weight to \(kg, privacy: .public) kg")
    }

    func updateActivityLevel(_ level: ActivityLevel) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.activityLevel = level
        user.updatedAt = Date()
        recalculate(user: user)
        regenerateRecommendations(user: user)
        try context.save()
        notifyGoalsChanged()
    }

    func overrideMacros(protein: Int, carbs: Int, fat: Int) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.proteinGoalGrams = max(0, protein)
        user.carbsGoalGrams = max(0, carbs)
        user.fatGoalGrams = max(0, fat)
        user.macrosOverridden = true
        user.updatedAt = Date()
        regenerateRecommendations(user: user)
        try context.save()
        notifyGoalsChanged()
    }

    func overrideCalories(_ kcal: Int) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.dailyCalorieGoalKcal = max(1000, kcal)
        user.caloriesOverridden = true
        user.updatedAt = Date()
        regenerateRecommendations(user: user)
        try context.save()
        notifyGoalsChanged()
    }

    func overrideWater(_ ml: Int) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.waterGoalMl = max(500, ml)
        user.waterOverridden = true
        user.updatedAt = Date()
        regenerateRecommendations(user: user)
        try context.save()
        notifyGoalsChanged()
    }

    func resetTargetsToRecommended() throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.caloriesOverridden = false
        user.macrosOverridden = false
        user.fiberOverridden = false
        user.waterOverridden = false
        recalculate(user: user)
        regenerateRecommendations(user: user)
        user.updatedAt = Date()
        try context.save()
        notifyGoalsChanged()
    }

    func recommendedTargetsPreview() throws -> GoalCalculator.Targets? {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        return recommendedTargets(for: user)
    }

    func recalculateCaloriesWithOla(using recommendationsService: any RecommendationsServing) async throws {
        let request: RecommendationsRequest?
        do {
            let context = ModelContext(container)
            let user = try fetchUser(in: context)
            user.caloriesOverridden = false
            recalculate(user: user)
            regenerateRecommendations(user: user)
            user.updatedAt = Date()
            request = recommendationsRequest(for: user)
            try context.save()
            notifyGoalsChanged()
        }

        guard let request else { return }
        do {
            let recommendations = try await recommendationsService.generate(for: request)
            try storeRecommendations(recommendations)
        } catch {
            Logger.coach.notice("Ola calorie recalculation recommendations failed: \(String(describing: error))")
        }
    }

    func recalculateTargetsWithOla(
        profile: CalorieRecalculationProfile,
        using recommendationsService: any RecommendationsServing
    ) async throws {
        let request: RecommendationsRequest?
        do {
            let context = ModelContext(container)
            let user = try fetchUser(in: context)
            user.weightKg = profile.weightKg
            user.heightCm = profile.heightCm
            user.birthDate = profile.birthDate
            user.biologicalSex = profile.biologicalSex
            user.activityLevel = profile.activityLevel
            user.goalKind = profile.goalKind
            user.dietMacroPreset = profile.dietMacroPreset
            if profile.goalKind.requiresPaceAndTarget {
                user.goalStartWeightKg = profile.goalStartWeightKg ?? profile.weightKg
                user.goalTargetWeightKg = profile.goalTargetWeightKg
                user.goalPaceKgPerWeek = profile.goalPaceKgPerWeek
                user.goalStartDate = Date()
                if let target = profile.goalTargetWeightKg,
                    let pace = profile.goalPaceKgPerWeek,
                    pace > 0
                {
                    user.goalEstimatedEndDate = GoalProjection.estimatedEndDate(
                        currentWeightKg: user.goalStartWeightKg ?? profile.weightKg,
                        targetWeightKg: target,
                        paceKgPerWeek: pace
                    )
                } else {
                    user.goalEstimatedEndDate = nil
                }
            } else {
                user.goalStartWeightKg = nil
                user.goalTargetWeightKg = nil
                user.goalPaceKgPerWeek = nil
                user.goalStartDate = nil
                user.goalEstimatedEndDate = nil
            }
            user.caloriesOverridden = false
            user.macrosOverridden = false
            user.fiberOverridden = false
            user.waterOverridden = false
            recalculate(user: user, reasonWeightKg: profile.weightKg)
            regenerateRecommendations(user: user)
            user.updatedAt = Date()
            request = recommendationsRequest(for: user)
            try context.save()
            notifyGoalsChanged()
        }

        guard let request else { return }
        do {
            let recommendations = try await recommendationsService.generate(for: request)
            try storeRecommendations(recommendations)
        } catch {
            Logger.coach.notice("Ola target recalculation recommendations failed: \(String(describing: error))")
        }
    }

    func updateMainGoal(
        kind: GoalKind,
        paceKgPerWeek: Double?,
        startWeightKg: Double?,
        targetWeightKg: Double?
    ) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        let previousGoal = user.goalKind
        let wasUsingRecommendedDiet = user.dietMacroPreset == DietMacroPreset.recommended(for: previousGoal)
        user.goalKind = kind
        if wasUsingRecommendedDiet {
            user.dietMacroPreset = DietMacroPreset.recommended(for: kind)
        }
        if kind.requiresPaceAndTarget {
            user.goalPaceKgPerWeek = paceKgPerWeek
            user.goalStartWeightKg = startWeightKg ?? user.weightKg
            user.goalTargetWeightKg = targetWeightKg
            user.goalStartDate = Date()
            if let pace = paceKgPerWeek, let target = targetWeightKg {
                let start = user.goalStartWeightKg ?? user.weightKg ?? target
                if pace > 0 {
                    user.goalEstimatedEndDate = GoalProjection.estimatedEndDate(
                        currentWeightKg: start,
                        targetWeightKg: target,
                        paceKgPerWeek: pace
                    )
                }
            } else {
                user.goalEstimatedEndDate = nil
            }
        } else {
            user.goalPaceKgPerWeek = nil
            user.goalStartWeightKg = nil
            user.goalTargetWeightKg = nil
            user.goalStartDate = nil
            user.goalEstimatedEndDate = nil
        }
        recalculate(user: user)
        regenerateRecommendations(user: user)
        user.updatedAt = Date()
        try context.save()
        notifyGoalsChanged()
    }

    func storeRecommendations(_ recommendations: Recommendations) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.latestRecommendationsJSON = try JSONEncoder().encode(recommendations)
        user.recommendationsGeneratedAt = Date()
        try context.save()
    }

    func loadStoredRecommendations() throws -> Recommendations? {
        let context = ModelContext(container)
        guard let user = try? fetchUser(in: context),
            let json = user.latestRecommendationsJSON
        else { return nil }
        return try? JSONDecoder().decode(Recommendations.self, from: json)
    }

    // MARK: - Private

    /// Re-runs the calculator on the user's current snapshot, but only
    /// for fields where the user hasn't ticked the override flag. This
    /// is the reason User has separate flags for kcal / macros / fiber /
    /// water instead of one mega-flag — users frequently want to lock
    /// kcal but still let macros float with the calculator.
    private func recalculate(user: User) {
        recalculate(user: user, reasonWeightKg: user.weightKg)
    }

    private func recalculate(user: User, reasonWeightKg: Double?) {
        guard let targets = recommendedTargets(for: user) else { return }
        if !user.caloriesOverridden {
            user.dailyCalorieGoalKcal = targets.dailyCalorieGoalKcal
        }
        if !user.macrosOverridden {
            user.proteinGoalGrams = targets.proteinGoalGrams
            user.carbsGoalGrams = targets.carbsGoalGrams
            user.fatGoalGrams = targets.fatGoalGrams
        }
        if !user.fiberOverridden {
            user.fiberGoalGrams = targets.fiberGoalGrams
        }
        if !user.waterOverridden {
            user.waterGoalMl = targets.waterGoalMl
        }
        user.lastGoalRecalculationWeightKg = reasonWeightKg ?? user.weightKg
        user.lastGoalRecalculationAt = Date()
    }

    private func shouldRecalculateTargets(for user: User, newWeightKg: Double) -> Bool {
        guard let previous = user.lastGoalRecalculationWeightKg else { return true }
        return abs(newWeightKg - previous) >= Self.weightRecalculationThresholdKg
    }

    private func recommendedTargets(for user: User) -> GoalCalculator.Targets? {
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return nil }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: height,
            weightKg: weight,
            age: age,
            biologicalSex: user.biologicalSex,
            activityLevel: user.activityLevel,
            goal: user.goalKind,
            dietMacroPreset: user.dietMacroPreset,
            paceKgPerWeek: user.goalPaceKgPerWeek
        )
        return GoalCalculator.calculateTargets(from: input)
    }

    private func recommendationsRequest(for user: User) -> RecommendationsRequest? {
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return nil }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return RecommendationsRequest(
            biologicalSex: user.biologicalSex,
            age: age,
            heightCm: height,
            weightKg: weight,
            activityLevel: user.activityLevel,
            goal: user.goalKind,
            paceKgPerWeek: user.goalPaceKgPerWeek,
            dailyCalorieGoalKcal: user.dailyCalorieGoalKcal,
            proteinGoalGrams: user.proteinGoalGrams,
            fatGoalGrams: user.fatGoalGrams,
            carbsGoalGrams: user.carbsGoalGrams,
            fiberGoalGrams: user.fiberGoalGrams,
            waterGoalMl: user.waterGoalMl,
            dietaryPreferences: Array(user.dietaryPreferences),
            hitSafetyFloor: user.dailyCalorieGoalKcal <= GoalCalculator.safetyFloor(for: user.biologicalSex),
            userID: user.remoteID,
            locale: LocalizationStore.currentLanguageCode()
        )
    }

    /// Refreshes the cached `Recommendations` blob on the user row from
    /// the current goal/macro/water snapshot. Called from every override
    /// path so the "Porady od Oli" hero on Today never quotes a stale
    /// kcal number after the user edits a goal. Failures are swallowed —
    /// stale tips are better than crashing the save.
    /// Public hook called when the user changes the in-app language so the
    /// cached Coach copy rebuilds in the new locale on the next render.
    func refreshRecommendationsForUser(remoteID: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.remoteID == remoteID })
        guard let user = try context.fetch(descriptor).first else { return }
        regenerateRecommendations(user: user)
        try context.save()
    }

    private func regenerateRecommendations(user: User) {
        guard let recommendations = RuleBasedRecommendationsService.buildSync(for: user) else { return }
        do {
            user.latestRecommendationsJSON = try JSONEncoder().encode(recommendations)
            user.recommendationsGeneratedAt = Date()
        } catch {
            Logger.persistence.error(
                "Failed to encode regenerated recommendations: \(String(describing: error))"
            )
        }
    }

    private func notifyGoalsChanged() {
        NotificationCenter.default.post(name: AppShortcutAction.mainGoalChanged, object: nil)
    }

    private func fetchUser(in context: ModelContext) throws -> User {
        guard let remoteID = sessionRemoteID() else {
            throw UserRepository.RepositoryError.userNotFound
        }
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        guard let user = try context.fetch(descriptor).first else {
            throw UserRepository.RepositoryError.userNotFound
        }
        return user
    }
}
