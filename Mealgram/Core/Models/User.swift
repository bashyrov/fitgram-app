import Foundation
import SwiftData

/// On-device mirror of the Supabase `users` row + locally cached profile.
/// The Supabase JWT subject (`sub`) becomes `remoteID`; SwiftData generates
/// a separate `id` so the local store doesn't conflict if the user
/// re-authenticates with a new identity.
@Model
final class User {
    @Attribute(.unique) var id: UUID
    var remoteID: String
    var email: String?
    var displayName: String?
    var providerKindRaw: String
    var avatarFilename: String?

    var createdAt: Date
    var updatedAt: Date
    var onboardingCompletedAt: Date?

    var locale: String
    var timeZoneIdentifier: String

    // Profile
    var birthDate: Date?
    var biologicalSexRaw: String
    var heightCm: Int?
    var weightKg: Double?
    var activityLevelRaw: String
    var goalKindRaw: String

    // Targets (server-recomputed but cached for offline display)
    var dailyCalorieGoalKcal: Int
    var proteinGoalGrams: Int
    var carbsGoalGrams: Int
    var fatGoalGrams: Int

    /// Persisted as a comma-joined raw-value list so SwiftData lightweight
    /// migration on existing rows keeps default-empty without bumping the
    /// schema version. Read/write via the typed `dietaryPreferences`
    /// extension below.
    var dietaryPreferencesRaw: String = ""

    init(
        id: UUID = UUID(),
        remoteID: String,
        email: String? = nil,
        displayName: String? = nil,
        providerKind: AuthProviderKind = .apple,
        locale: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        biologicalSex: BiologicalSex = .undisclosed,
        activityLevel: ActivityLevel = .moderate,
        goalKind: GoalKind = .maintain,
        dailyCalorieGoalKcal: Int = 2100,
        proteinGoalGrams: Int = 120,
        carbsGoalGrams: Int = 240,
        fatGoalGrams: Int = 70
    ) {
        let now = Date()
        self.id = id
        self.remoteID = remoteID
        self.email = email
        self.displayName = displayName
        self.providerKindRaw = providerKind.rawValue
        self.createdAt = now
        self.updatedAt = now
        self.locale = locale
        self.timeZoneIdentifier = timeZoneIdentifier
        self.biologicalSexRaw = biologicalSex.rawValue
        self.activityLevelRaw = activityLevel.rawValue
        self.goalKindRaw = goalKind.rawValue
        self.dailyCalorieGoalKcal = dailyCalorieGoalKcal
        self.proteinGoalGrams = proteinGoalGrams
        self.carbsGoalGrams = carbsGoalGrams
        self.fatGoalGrams = fatGoalGrams
    }
}

extension User {
    var providerKind: AuthProviderKind {
        get { AuthProviderKind(rawValue: providerKindRaw) ?? .apple }
        set { providerKindRaw = newValue.rawValue }
    }

    var biologicalSex: BiologicalSex {
        get { BiologicalSex(rawValue: biologicalSexRaw) ?? .undisclosed }
        set { biologicalSexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goalKind: GoalKind {
        get { GoalKind(rawValue: goalKindRaw) ?? .maintain }
        set { goalKindRaw = newValue.rawValue }
    }

    var isOnboarded: Bool { onboardingCompletedAt != nil }

    var dietaryPreferences: Set<DietaryPreference> {
        get {
            Set(
                dietaryPreferencesRaw.split(separator: ",")
                    .compactMap { DietaryPreference(rawValue: String($0)) }
            )
        }
        set {
            dietaryPreferencesRaw = newValue.map(\.rawValue).sorted().joined(separator: ",")
        }
    }
}

/// User-facing dietary preference / restriction tags. Used by the
/// onboarding step + Coach context to bias suggestions. Adding a case
/// is safe for existing rows because storage is comma-joined raw.
enum DietaryPreference: String, CaseIterable, Sendable, Identifiable, Hashable {
    case vegetarian
    case vegan
    case glutenFree
    case dairyFree
    case keto
    case pescatarian

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegetarian: return String(localized: "Wegetariańskie")
        case .vegan: return String(localized: "Wegańskie")
        case .glutenFree: return String(localized: "Bez glutenu")
        case .dairyFree: return String(localized: "Bez nabiału")
        case .keto: return String(localized: "Keto")
        case .pescatarian: return String(localized: "Pescatariańskie")
        }
    }

    var symbol: String {
        switch self {
        case .vegetarian: return "leaf"
        case .vegan: return "leaf.fill"
        case .glutenFree: return "carrot.fill"
        case .dairyFree: return "drop.triangle"
        case .keto: return "bolt.fill"
        case .pescatarian: return "fish.fill"
        }
    }
}
