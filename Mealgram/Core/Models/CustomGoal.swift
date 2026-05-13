import Foundation
import SwiftData

/// User-defined supplementary goal that runs alongside the main weight
/// goal on User. Max 3 active at a time (enforced by the service, not
/// the model — kept as a soft cap so historical rows aren't deleted).
///
/// `targets` is JSON-encoded because CustomGoal stores a heterogeneous
/// list (weight loss + protein bump + no-fast-food run can all live on
/// one goal). Encoding into a single field avoids a full sub-table
/// while staying queryable enough for the kinds of reads the app does
/// (always "list active goals for user").
@Model
final class CustomGoal {
    @Attribute(.unique) var id: UUID
    var userRemoteID: String
    var name: String
    var startDate: Date
    var endDate: Date
    /// Encoded `[CustomGoalTarget]` — never nil, may be empty array
    /// data while the user is in the middle of building.
    var targetsJSON: Data
    var reminderTypeRaw: String?
    var statusRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        name: String,
        startDate: Date = Date(),
        endDate: Date,
        targets: [CustomGoalTarget] = [],
        reminderType: CustomGoalReminder? = nil,
        status: CustomGoalStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.targetsJSON = (try? JSONEncoder().encode(targets)) ?? Data("[]".utf8)
        self.reminderTypeRaw = reminderType?.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
    }
}

extension CustomGoal {
    var targets: [CustomGoalTarget] {
        get {
            (try? JSONDecoder().decode([CustomGoalTarget].self, from: targetsJSON)) ?? []
        }
        set {
            targetsJSON = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
        }
    }

    var status: CustomGoalStatus {
        get { CustomGoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var reminderType: CustomGoalReminder? {
        get { reminderTypeRaw.flatMap(CustomGoalReminder.init(rawValue:)) }
        set { reminderTypeRaw = newValue?.rawValue }
    }

    var isActive: Bool { status == .active && endDate > Date() }
}

/// One target inside a CustomGoal. The type determines how
/// `GoalsService.calculateGoalProgress` evaluates it.
struct CustomGoalTarget: Codable, Equatable, Sendable, Identifiable {
    enum TargetType: String, Codable, Sendable {
        case weightLoss = "weight_loss"
        case weightGain = "weight_gain"
        case proteinDaily = "protein_daily"
        case waterDaily = "water_daily"
        case noFastFoodDays = "no_fast_food_days"
        case maxCaloriesDaily = "max_calories_daily"
        case custom
    }

    var id = UUID()
    var type: TargetType
    /// Target numeric value. Unit defined by `type`:
    /// - weightLoss / weightGain → kg
    /// - proteinDaily → grams
    /// - waterDaily → ml
    /// - noFastFoodDays → days
    /// - maxCaloriesDaily → kcal
    /// - custom → free-form (paired with `customName` for UI)
    var value: Double
    var customName: String?
}

enum CustomGoalStatus: String, Codable, CaseIterable, Sendable {
    case active
    case completed
    case abandoned
    case paused
}

enum CustomGoalReminder: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case onDeviation = "on_deviation"
}
