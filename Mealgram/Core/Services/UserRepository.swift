import Foundation
import OSLog
import SwiftData

/// Resolves the SwiftData `User` row for whoever is currently signed in.
/// First call after sign-in creates the row; subsequent calls return the
/// existing one and patch in any newly-available profile fields.
@MainActor
final class UserRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Returns the `User` row matching the auth identity, creating one if
    /// it doesn't exist yet.
    @discardableResult
    func ensureUser(for authUser: AuthUser) throws -> User {
        let context = ModelContext(container)
        let remoteID = authUser.id
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        if let existing = try context.fetch(descriptor).first {
            apply(authUser: authUser, to: existing)
            existing.updatedAt = Date()
            try context.save()
            return existing
        }
        let fresh = User(
            remoteID: authUser.id,
            email: authUser.email,
            displayName: authUser.displayName,
            providerKind: authUser.provider
        )
        context.insert(fresh)
        try context.save()
        Logger.persistence.notice("Created User row for \(authUser.id, privacy: .private)")
        return fresh
    }

    /// Stamps the onboarding completion date and persists the gathered
    /// profile data in one shot.
    func completeOnboarding(_ user: User, profile: OnboardingProfile) throws {
        let context = ModelContext(container)
        let remoteID = user.remoteID
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        guard let stored = try context.fetch(descriptor).first else {
            throw RepositoryError.userNotFound
        }
        stored.goalKind = profile.goal
        stored.biologicalSex = profile.biologicalSex
        stored.activityLevel = profile.activityLevel
        stored.birthDate = profile.birthDate
        stored.heightCm = profile.heightCm
        stored.weightKg = profile.weightKg
        stored.dailyCalorieGoalKcal = profile.dailyCalorieGoalKcal
        stored.dietaryPreferences = profile.dietaryPreferences
        stored.proteinGoalGrams = profile.proteinGoalGrams
        stored.carbsGoalGrams = profile.carbsGoalGrams
        stored.fatGoalGrams = profile.fatGoalGrams
        stored.fiberGoalGrams = profile.fiberGoalGrams
        stored.waterGoalMl = profile.waterGoalMl
        stored.goalPaceKgPerWeek = profile.goalPaceKgPerWeek
        stored.goalTargetWeightKg = profile.goalTargetWeightKg
        if let pace = profile.goalPaceKgPerWeek,
            let target = profile.goalTargetWeightKg,
            let current = profile.weightKg,
            pace > 0
        {
            stored.goalStartDate = Date()
            stored.goalEstimatedEndDate = GoalProjection.estimatedEndDate(
                currentWeightKg: current,
                targetWeightKg: target,
                paceKgPerWeek: pace
            )
        } else {
            stored.goalStartDate = nil
            stored.goalEstimatedEndDate = nil
        }
        stored.onboardingCompletedAt = Date()
        stored.updatedAt = Date()
        try context.save()
        Logger.persistence.notice("Onboarding completed for \(user.remoteID, privacy: .private)")
    }

    /// Clears the onboarding completion timestamp so AppRouter sends the
    /// user back through the onboarding flow on next evaluation. Used by
    /// Profile → Preferences → "Powtórz onboarding".
    func resetOnboarding(forRemoteID remoteID: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        guard let stored = try context.fetch(descriptor).first else {
            throw RepositoryError.userNotFound
        }
        stored.onboardingCompletedAt = nil
        stored.updatedAt = Date()
        try context.save()
    }

    func fetchUser(remoteID: String) throws -> User? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        return try context.fetch(descriptor).first
    }

    enum RepositoryError: Error, Equatable {
        case userNotFound
    }

    // MARK: - Helpers

    private func apply(authUser: AuthUser, to user: User) {
        if let email = authUser.email, !email.isEmpty { user.email = email }
        if let name = authUser.displayName, !name.isEmpty { user.displayName = name }
        user.providerKind = authUser.provider
    }
}

/// Free-floating value the onboarding flow accumulates as the user moves
/// step-to-step. Persisted once via `UserRepository.completeOnboarding`.
struct OnboardingProfile: Equatable {
    var goal: GoalKind = .maintain
    var biologicalSex: BiologicalSex = .undisclosed
    var activityLevel: ActivityLevel = .moderate
    var birthDate: Date?
    var heightCm: Int?
    var weightKg: Double?

    var dailyCalorieGoalKcal: Int = 2100
    var proteinGoalGrams: Int = 120
    var carbsGoalGrams: Int = 240
    var fatGoalGrams: Int = 70
    var fiberGoalGrams: Int = 30
    var waterGoalMl: Int = 2500

    /// Set only when goal is `.lose` or `.gain` and the user proceeded
    /// through the pace step. Nil otherwise.
    var goalPaceKgPerWeek: Double?
    var goalTargetWeightKg: Double?

    /// True when the calculator returned a kcal value below the safety
    /// floor and clamped. Surfaced on the results step so the user gets
    /// a "Cel jest zbyt agresywny" warning before they finish.
    var hitSafetyFloor: Bool = false

    var dietaryPreferences: Set<DietaryPreference> = []
}

extension OnboardingProfile {
    /// Snapshot suitable for the (anonymous) Worker payload. No name, no
    /// auth ID — just the metrics + targets that produced the plan.
    var recommendationsRequest: RecommendationsRequest? {
        guard let height = heightCm,
            let weight = weightKg,
            let birth = birthDate
        else { return nil }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return RecommendationsRequest(
            biologicalSex: biologicalSex,
            age: age,
            heightCm: height,
            weightKg: weight,
            activityLevel: activityLevel,
            goal: goal,
            paceKgPerWeek: goalPaceKgPerWeek,
            dailyCalorieGoalKcal: dailyCalorieGoalKcal,
            proteinGoalGrams: proteinGoalGrams,
            fatGoalGrams: fatGoalGrams,
            carbsGoalGrams: carbsGoalGrams,
            fiberGoalGrams: fiberGoalGrams,
            waterGoalMl: waterGoalMl,
            dietaryPreferences: Array(dietaryPreferences),
            hitSafetyFloor: hitSafetyFloor
        )
    }
}
