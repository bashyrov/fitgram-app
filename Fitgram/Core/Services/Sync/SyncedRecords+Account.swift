import Foundation
import SwiftData

// Per-account singletons (profile, streak, calibration) and achievements,
// keyed by a fixed id rather than the local UUID so two devices that each
// created their own row still meet on the same server record.

struct ProfileRecord: SyncedRecord {
    static let kind = "profile"
    static let singletonID = "self"

    var email: String?
    var displayName: String?
    var username: String?
    var providerKind: String
    var createdAt: Date
    var onboardingCompletedAt: Date?
    var locale: String
    var timeZoneIdentifier: String
    var birthDate: Date?
    var biologicalSex: String
    var heightCm: Int?
    var weightKg: Double?
    var activityLevel: String
    var goalKind: String
    var dietMacroPreset: String
    var dailyCalorieGoalKcal: Int
    var proteinGoalGrams: Int
    var carbsGoalGrams: Int
    var fatGoalGrams: Int
    var fiberGoalGrams: Int
    var waterGoalMl: Int
    var lastGoalRecalculationWeightKg: Double?
    var lastGoalRecalculationAt: Date?
    var goalPaceKgPerWeek: Double?
    var goalStartWeightKg: Double?
    var goalTargetWeightKg: Double?
    var goalStartDate: Date?
    var goalEstimatedEndDate: Date?
    var caloriesOverridden: Bool
    var macrosOverridden: Bool
    var fiberOverridden: Bool
    var waterOverridden: Bool
    var latestRecommendationsJSON: Data?
    var recommendationsGeneratedAt: Date?
    var dietaryPreferences: String

    static func owned(by owner: String, in context: ModelContext) throws -> [User] {
        Array(try fetch(#Predicate { $0.remoteID == owner }, in: context).prefix(1))
    }

    static func recordID(of model: User) -> String { singletonID }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> User? {
        try fetch(#Predicate { $0.remoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> User {
        let user = User(remoteID: owner)
        context.insert(user)
        return user
    }

    init(_ model: User) {
        email = model.email
        displayName = model.displayName
        username = model.username
        providerKind = model.providerKindRaw
        createdAt = model.createdAt
        onboardingCompletedAt = model.onboardingCompletedAt
        locale = model.locale
        timeZoneIdentifier = model.timeZoneIdentifier
        birthDate = model.birthDate
        biologicalSex = model.biologicalSexRaw
        heightCm = model.heightCm
        weightKg = model.weightKg
        activityLevel = model.activityLevelRaw
        goalKind = model.goalKindRaw
        dietMacroPreset = model.dietMacroPresetRaw
        dailyCalorieGoalKcal = model.dailyCalorieGoalKcal
        proteinGoalGrams = model.proteinGoalGrams
        carbsGoalGrams = model.carbsGoalGrams
        fatGoalGrams = model.fatGoalGrams
        fiberGoalGrams = model.fiberGoalGrams
        waterGoalMl = model.waterGoalMl
        lastGoalRecalculationWeightKg = model.lastGoalRecalculationWeightKg
        lastGoalRecalculationAt = model.lastGoalRecalculationAt
        goalPaceKgPerWeek = model.goalPaceKgPerWeek
        goalStartWeightKg = model.goalStartWeightKg
        goalTargetWeightKg = model.goalTargetWeightKg
        goalStartDate = model.goalStartDate
        goalEstimatedEndDate = model.goalEstimatedEndDate
        caloriesOverridden = model.caloriesOverridden
        macrosOverridden = model.macrosOverridden
        fiberOverridden = model.fiberOverridden
        waterOverridden = model.waterOverridden
        latestRecommendationsJSON = model.latestRecommendationsJSON
        recommendationsGeneratedAt = model.recommendationsGeneratedAt
        dietaryPreferences = model.dietaryPreferencesRaw
    }

    func apply(to model: User, in context: ModelContext) {
        model.email = email
        model.displayName = displayName
        model.username = username
        model.providerKindRaw = providerKind
        model.createdAt = createdAt
        model.onboardingCompletedAt = onboardingCompletedAt
        model.locale = locale
        model.timeZoneIdentifier = timeZoneIdentifier
        model.birthDate = birthDate
        model.biologicalSexRaw = biologicalSex
        model.heightCm = heightCm
        model.weightKg = weightKg
        model.activityLevelRaw = activityLevel
        model.goalKindRaw = goalKind
        model.dietMacroPresetRaw = dietMacroPreset
        model.dailyCalorieGoalKcal = dailyCalorieGoalKcal
        model.proteinGoalGrams = proteinGoalGrams
        model.carbsGoalGrams = carbsGoalGrams
        model.fatGoalGrams = fatGoalGrams
        model.fiberGoalGrams = fiberGoalGrams
        model.waterGoalMl = waterGoalMl
        model.lastGoalRecalculationWeightKg = lastGoalRecalculationWeightKg
        model.lastGoalRecalculationAt = lastGoalRecalculationAt
        model.goalPaceKgPerWeek = goalPaceKgPerWeek
        model.goalStartWeightKg = goalStartWeightKg
        model.goalTargetWeightKg = goalTargetWeightKg
        model.goalStartDate = goalStartDate
        model.goalEstimatedEndDate = goalEstimatedEndDate
        model.caloriesOverridden = caloriesOverridden
        model.macrosOverridden = macrosOverridden
        model.fiberOverridden = fiberOverridden
        model.waterOverridden = waterOverridden
        model.latestRecommendationsJSON = latestRecommendationsJSON
        model.recommendationsGeneratedAt = recommendationsGeneratedAt
        model.dietaryPreferencesRaw = dietaryPreferences
        model.updatedAt = Date()
    }
}

struct StreakRecord: SyncedRecord {
    static let kind = "streak"
    static let singletonID = "self"

    var currentLength: Int
    var longestLength: Int
    var lastLoggedDate: Date?
    var freezesAvailable: Int
    var lastFreezeDate: Date?
    var lastFreezeAwardedLength: Int

    static func owned(by owner: String, in context: ModelContext) throws -> [Streak] {
        Array(try fetch(#Predicate { $0.userRemoteID == owner }, in: context).prefix(1))
    }

    static func recordID(of model: Streak) -> String { singletonID }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Streak? {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Streak {
        let streak = Streak(userRemoteID: owner)
        context.insert(streak)
        return streak
    }

    init(_ model: Streak) {
        currentLength = model.currentLength
        longestLength = model.longestLength
        lastLoggedDate = model.lastLoggedDate
        freezesAvailable = model.freezesAvailable
        lastFreezeDate = model.lastFreezeDate
        lastFreezeAwardedLength = model.lastFreezeAwardedLength
    }

    func apply(to model: Streak, in context: ModelContext) {
        model.currentLength = currentLength
        model.longestLength = longestLength
        model.lastLoggedDate = lastLoggedDate
        model.freezesAvailable = freezesAvailable
        model.lastFreezeDate = lastFreezeDate
        model.lastFreezeAwardedLength = lastFreezeAwardedLength
    }
}

struct CalibrationRecord: SyncedRecord {
    static let kind = "calibration"
    static let singletonID = "self"

    var referenceObject: String
    var portionAdjustmentFactor: Double
    var sampleCount: Int
    var lastUpdated: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [Calibration] {
        Array(try fetch(#Predicate { $0.userRemoteID == owner }, in: context).prefix(1))
    }

    static func recordID(of model: Calibration) -> String { singletonID }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Calibration? {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Calibration {
        let calibration = Calibration(userRemoteID: owner)
        context.insert(calibration)
        return calibration
    }

    init(_ model: Calibration) {
        referenceObject = model.referenceObjectRaw
        portionAdjustmentFactor = model.portionAdjustmentFactor
        sampleCount = model.sampleCount
        lastUpdated = model.lastUpdated
    }

    func apply(to model: Calibration, in context: ModelContext) {
        model.referenceObjectRaw = referenceObject
        model.portionAdjustmentFactor = portionAdjustmentFactor
        model.sampleCount = sampleCount
        model.lastUpdated = lastUpdated
    }
}

/// One row per earned badge, keyed by the badge kind.
struct AchievementRecord: SyncedRecord {
    static let kind = "achievement"

    var earnedAt: Date
    var title: String
    var details: String

    static func owned(by owner: String, in context: ModelContext) throws -> [Achievement] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: Achievement) -> String { model.kind }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Achievement? {
        try fetch(#Predicate { $0.userRemoteID == owner && $0.kind == id }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Achievement {
        let achievement = Achievement(userRemoteID: owner, kind: id, title: "", details: "")
        context.insert(achievement)
        return achievement
    }

    init(_ model: Achievement) {
        earnedAt = model.earnedAt
        title = model.title
        details = model.details
    }

    func apply(to model: Achievement, in context: ModelContext) {
        model.earnedAt = earnedAt
        model.title = title
        model.details = details
    }
}
