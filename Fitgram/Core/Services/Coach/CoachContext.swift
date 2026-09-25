import Foundation

/// Snapshot of everything the coach needs to reason about. Materialised
/// once per request by `CoachService.context(for:)`; the generator then
/// only sees pure values.
struct CoachContext: Equatable, Sendable {
    /// Calorie + macro goal (mirrored off the User row).
    struct Goals: Equatable, Sendable {
        var calorieGoalKcal: Int
        var proteinGoalGrams: Int
        var carbsGoalGrams: Int
        var fatGoalGrams: Int
        var waterGoalMl: Int
        var goalKindRaw: String
        var dietMacroPresetRaw: String

        init(
            calorieGoalKcal: Int,
            proteinGoalGrams: Int,
            carbsGoalGrams: Int = 240,
            fatGoalGrams: Int = 70,
            waterGoalMl: Int = 2500,
            goalKindRaw: String = GoalKind.maintain.rawValue,
            dietMacroPresetRaw: String = DietMacroPreset.balanced.rawValue
        ) {
            self.calorieGoalKcal = calorieGoalKcal
            self.proteinGoalGrams = proteinGoalGrams
            self.carbsGoalGrams = carbsGoalGrams
            self.fatGoalGrams = fatGoalGrams
            self.waterGoalMl = waterGoalMl
            self.goalKindRaw = goalKindRaw
            self.dietMacroPresetRaw = dietMacroPresetRaw
        }
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

    /// Aggregated stats across the user's personal week. The cycle starts
    /// on the weekday they joined, not Monday, so the debrief feels tied
    /// to their own rhythm.
    struct Week: Equatable, Sendable {
        var startAt: Date
        var endAt: Date
        var dailyCalorieAverages: [Double]  // oldest day at index 0
        var dailyProteinAverages: [Double]
        var dailyWaterMl: [Int]
        var workoutCalories: [Double]
        var workoutMinutes: [Int]
        var frequentFoods: [String]
        var daysWithAnyEntry: Int  // 0...7
        var daysHittingProteinGoal: Int  // 0...7
        var daysWithinCalorieGoal: Int  // 0...7 — within ±15 %
        var bestCalorieDayOffset: Int?
        var weakestProteinDayOffset: Int?

        init(
            startAt: Date = Date(),
            endAt: Date = Date(),
            dailyCalorieAverages: [Double],
            dailyProteinAverages: [Double],
            dailyWaterMl: [Int] = [],
            workoutCalories: [Double] = [],
            workoutMinutes: [Int] = [],
            frequentFoods: [String] = [],
            daysWithAnyEntry: Int,
            daysHittingProteinGoal: Int,
            daysWithinCalorieGoal: Int,
            bestCalorieDayOffset: Int? = nil,
            weakestProteinDayOffset: Int? = nil
        ) {
            self.startAt = startAt
            self.endAt = endAt
            self.dailyCalorieAverages = dailyCalorieAverages
            self.dailyProteinAverages = dailyProteinAverages
            self.dailyWaterMl = dailyWaterMl
            self.workoutCalories = workoutCalories
            self.workoutMinutes = workoutMinutes
            self.frequentFoods = frequentFoods
            self.daysWithAnyEntry = daysWithAnyEntry
            self.daysHittingProteinGoal = daysHittingProteinGoal
            self.daysWithinCalorieGoal = daysWithinCalorieGoal
            self.bestCalorieDayOffset = bestCalorieDayOffset
            self.weakestProteinDayOffset = weakestProteinDayOffset
        }
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

    struct MemoryNote: Equatable, Sendable, Codable {
        var kindRaw: String
        var summary: String
        var confidence: Double
    }

    var goals: Goals
    var today: Today
    var week: Week
    var streak: Streak
    var weight: Weight
    var hourOfDay: Int  // 0...23, local time of the request
    var hasOngoingCulturalEvent: Bool
    var memory: [MemoryNote]
    /// Opaque user id. Travels to the Worker so the admin AI-usage
    /// dashboard can attribute cost per user. Empty/nil → "anonymous".
    var userRemoteID: String?
}

struct DailyOlaPlan: Equatable, Sendable, Codable {
    enum Source: String, Codable, Sendable {
        case ai
        case fallback
    }

    enum Moment: String, Codable, Sendable {
        case morning
        case midday
        case evening
        case overshoot
    }

    struct Focus: Equatable, Sendable, Codable, Identifiable {
        var id: String { title + value }
        let title: String
        let value: String
        let detail: String
    }

    let dateKey: String
    let moment: Moment
    let headline: String
    let body: String
    let todayGoal: String
    let firstMealSuggestion: String
    let risk: String?
    let focuses: [Focus]
    let generatedAt: Date
    let source: Source

    init(
        dateKey: String,
        moment: Moment,
        headline: String,
        body: String,
        todayGoal: String,
        firstMealSuggestion: String,
        risk: String?,
        focuses: [Focus],
        generatedAt: Date,
        source: Source = .fallback
    ) {
        self.dateKey = dateKey
        self.moment = moment
        self.headline = headline
        self.body = body
        self.todayGoal = todayGoal
        self.firstMealSuggestion = firstMealSuggestion
        self.risk = risk
        self.focuses = focuses
        self.generatedAt = generatedAt
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case dateKey
        case moment
        case headline
        case body
        case todayGoal
        case firstMealSuggestion
        case risk
        case focuses
        case generatedAt
        case source
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        moment = try container.decode(Moment.self, forKey: .moment)
        headline = try container.decode(String.self, forKey: .headline)
        body = try container.decode(String.self, forKey: .body)
        todayGoal = try container.decode(String.self, forKey: .todayGoal)
        firstMealSuggestion = try container.decode(String.self, forKey: .firstMealSuggestion)
        risk = try container.decodeIfPresent(String.self, forKey: .risk)
        focuses = try container.decode([Focus].self, forKey: .focuses)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .fallback
    }

    func refreshed(with live: DailyOlaPlan) -> DailyOlaPlan {
        let metricsChanged = todayGoal != live.todayGoal || focuses != live.focuses
        let keepsGeneratedCopy = moment == live.moment && !metricsChanged
        return DailyOlaPlan(
            dateKey: live.dateKey,
            moment: live.moment,
            headline: keepsGeneratedCopy ? headline : live.headline,
            body: keepsGeneratedCopy ? body : live.body,
            todayGoal: live.todayGoal,
            firstMealSuggestion: keepsGeneratedCopy ? firstMealSuggestion : live.firstMealSuggestion,
            risk: live.risk ?? risk,
            focuses: live.focuses,
            generatedAt: generatedAt,
            source: source
        )
    }
}
