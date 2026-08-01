import Foundation

/// Snapshot of everything the coach needs to reason about. Materialised
/// once per request by `CoachService.context(for:)`; the generator then
/// only sees pure values.
struct CoachContext: Equatable, Sendable {
    /// Calorie + macro goal (mirrored off the User row).
    struct Goals: Equatable, Sendable {
        var calorieGoalKcal: Int
        var proteinGoalGrams: Int
    }

    /// Today-so-far totals.
    struct Today: Equatable, Sendable {
        var caloriesKcal: Double
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var entryCount: Int
        var lastLoggedAt: Date?
    }

    /// Aggregated stats across the last 7 calendar days (incl. today).
    struct Week: Equatable, Sendable {
        var dailyCalorieAverages: [Double]  // newest day at index 0
        var dailyProteinAverages: [Double]
        var daysWithAnyEntry: Int  // 0...7
        var daysHittingProteinGoal: Int  // 0...7
        var daysWithinCalorieGoal: Int  // 0...7 — within ±15 %
    }

    struct Streak: Equatable, Sendable {
        var current: Int
        var longest: Int
        var freezesAvailable: Int
        /// Whether the user has *not* logged anything today — sets up
        /// the streak-at-risk nudge after a certain hour.
        var atRiskToday: Bool
    }

    struct Weight: Equatable, Sendable {
        var latestKg: Double?
        var deltaKg30Days: Double?
    }

    var goals: Goals
    var today: Today
    var week: Week
    var streak: Streak
    var weight: Weight
    var hourOfDay: Int  // 0...23, local time of the request
    var hasOngoingCulturalEvent: Bool
    /// Opaque user id. Travels to the Worker so the admin AI-usage
    /// dashboard can attribute cost per user. Empty/nil → "anonymous".
    var userRemoteID: String?
}
