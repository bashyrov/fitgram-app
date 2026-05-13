import Foundation

/// Anonymous payload sent to the Worker (or fed to the rule-based
/// fallback). Deliberately strips any identifier — name, email, auth
/// ID, even avatar — so the LLM call carries only the nutrition-
/// relevant metrics.
struct RecommendationsRequest: Codable, Equatable, Sendable {
    var biologicalSex: BiologicalSex
    var age: Int
    var heightCm: Int
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: GoalKind
    /// Pace in kg/week, only meaningful when goal is `.lose` or `.gain`.
    var paceKgPerWeek: Double?
    var dailyCalorieGoalKcal: Int
    var proteinGoalGrams: Int
    var fatGoalGrams: Int
    var carbsGoalGrams: Int
    var fiberGoalGrams: Int
    var waterGoalMl: Int
    var dietaryPreferences: [DietaryPreference]
    var hitSafetyFloor: Bool
}

/// Structured response from the AI Coach. Matches the JSON schema the
/// Worker is expected to emit — when keys are missing we ship the
/// rule-based fallback in the same shape so the UI doesn't branch on
/// data source.
struct Recommendations: Codable, Equatable, Sendable {
    var summary: String
    var tips: [RecommendationTip]
    var warnings: [String]
    var nextSteps: String
    /// "rule_based" | "worker_claude_sonnet_4_5" — surfaced in the
    /// debug build only so we can tell which path delivered the
    /// recommendations the user is reading.
    var source: String
}

struct RecommendationTip: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    /// Single emoji used as the leading glyph in the UI. Worker is
    /// instructed to return one in its response; fallback supplies
    /// canonical ones per tip category.
    var icon: String
    var title: String
    var description: String

    enum CodingKeys: String, CodingKey { case icon, title, description }
}
