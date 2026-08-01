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

    /// Saves a new main goal (kind + optional pace/target weight) and
    /// recomputes targets accordingly. Caller is responsible for
    /// validating pace is within safe ranges before calling.
    func updateMainGoal(
        kind: GoalKind,
        paceKgPerWeek: Double?,
        targetWeightKg: Double?
    ) throws

    /// Stores the most recent `Recommendations` payload on the user
    /// row so the Profile screen can re-render it without re-asking
    /// the Worker.
    func storeRecommendations(_ recommendations: Recommendations) throws

    func loadStoredRecommendations() throws -> Recommendations?
}

/// SwiftData-backed implementation. All work happens on `@MainActor`
/// because `ModelContext` isn't Sendable.
@MainActor
final class UserProfileService: UserProfileServing {
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
        user.weightKg = kg
        user.updatedAt = Date()
        recalculate(user: user)
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

    func updateMainGoal(
        kind: GoalKind,
        paceKgPerWeek: Double?,
        targetWeightKg: Double?
    ) throws {
        let context = ModelContext(container)
        let user = try fetchUser(in: context)
        user.goalKind = kind
        if kind.requiresPaceAndTarget {
            user.goalPaceKgPerWeek = paceKgPerWeek
            user.goalTargetWeightKg = targetWeightKg
            user.goalStartDate = Date()
            if let pace = paceKgPerWeek, let target = targetWeightKg, let current = user.weightKg {
                if pace > 0 {
                    user.goalEstimatedEndDate = GoalProjection.estimatedEndDate(
                        currentWeightKg: current,
                        targetWeightKg: target,
                        paceKgPerWeek: pace
                    )
                }
            } else {
                user.goalEstimatedEndDate = nil
            }
        } else {
            user.goalPaceKgPerWeek = nil
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
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: height,
            weightKg: weight,
            age: age,
            biologicalSex: user.biologicalSex,
            activityLevel: user.activityLevel,
            goal: user.goalKind,
            paceKgPerWeek: user.goalPaceKgPerWeek
        )
        guard let targets = GoalCalculator.calculateTargets(from: input) else { return }
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
