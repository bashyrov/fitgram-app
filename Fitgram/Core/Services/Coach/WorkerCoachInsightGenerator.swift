import Foundation
import OSLog

/// Cloudflare Worker-backed AI coach. Only the weekly debrief goes to AI:
///
///   POST /api/v1/coach/weekly-debrief  — for "How you're doing" sheet
///
/// Daily tips and the Today plan come from `fallback` (the rule-based coach)
/// to keep AI cost per active user flat. The request serialises the `CoachContext` to a flat JSON body and parse a
/// `CoachInsight` list back. Every call logs its token usage on the
/// server side via the same `ai_usage` table the admin dashboard reads.
///
/// Wraps a `fallback` generator (typically `RuleBasedCoach`) — when the
/// Worker is unreachable or returns malformed data, we ship the
/// deterministic copy so the UI never shows a blank state. Fallbacks are
/// invisible to the user; they only show up in the structured log.
struct WorkerCoachInsightGenerator: CoachInsightGenerator {
    private let baseURL: URL
    private let client: any APIClient
    private let fallback: any CoachInsightGenerator

    init(baseURL: URL, client: any APIClient, fallback: any CoachInsightGenerator) {
        self.baseURL = baseURL
        self.client = client
        self.fallback = fallback
    }

    func generate(for context: CoachContext) async -> [CoachInsight] {
        await generateBatch(for: context).insights
    }

    /// Daily tips stay on the local rule engine: they regenerate after every
    /// logged meal, so an AI call each time cost far more than it added.
    func generateBatch(for context: CoachContext) async -> CoachInsightBatch {
        CoachInsightBatch(insights: await fallback.generate(for: context), isFromAI: false)
    }

    /// Same for the Today plan — local only; AI is reserved for the weekly debrief.
    func generateDailyPlan(for context: CoachContext, now: Date) async -> DailyOlaPlan {
        await fallback.generateDailyPlan(for: context, now: now)
    }

    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult {
        do {
            let request = WireCoachContext.from(context)
            let endpoint = try Endpoint.json(
                path: "/api/v1/coach/weekly-debrief",
                method: .post,
                payload: request,
                encoder: .workerCoach,
                requiresAuth: true
            )
            let response = try await client.send(endpoint, expecting: WeeklyDebriefResponse.self)
            let insights = response.insights.map(CoachInsight.init(wire:))
            if insights.isEmpty {
                Logger.coach.notice("worker weekly-debrief returned empty list, using fallback")
                return await fallback.generateWeekly(for: context)
            }
            let cleanedHeadline = response.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            return WeeklyDebriefAIResult(
                headline: cleanedHeadline.isEmpty ? nil : cleanedHeadline,
                sections: response.cleanedSections,
                nextWeekRules: response.cleanedRules,
                insights: insights
            )
        } catch {
            Logger.coach.error(
                "worker weekly-debrief failed: \(String(describing: error), privacy: .public)")
            return await fallback.generateWeekly(for: context)
        }
    }
}

// MARK: - Wire types

/// Flattened context that gets serialised over the wire. Keeps the
/// JSON shape stable even if `CoachContext` evolves.
private struct WireCoachContext: Encodable {
    struct Goals: Encodable {
        let calorieGoalKcal: Int
        let proteinGoalGrams: Int
        let carbsGoalGrams: Int
        let fatGoalGrams: Int
        let waterGoalMl: Int
        let goalKind: String
        let dietMacroPreset: String
    }
    struct Today: Encodable {
        let caloriesKcal: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let entryCount: Int
        let hasLoggedToday: Bool
    }
    struct Week: Encodable {
        let startAt: Date
        let endAt: Date
        let dailyCalorieAverages: [Double]
        let dailyProteinAverages: [Double]
        let dailyWaterMl: [Int]
        let workoutCalories: [Double]
        let workoutMinutes: [Int]
        let frequentFoods: [String]
        let daysWithAnyEntry: Int
        let daysHittingProteinGoal: Int
        let daysWithinCalorieGoal: Int
        let bestCalorieDayOffset: Int?
        let weakestProteinDayOffset: Int?
    }
    struct Streak: Encodable {
        let current: Int
        let longest: Int
        let freezesAvailable: Int
        let atRiskToday: Bool
    }
    struct Weight: Encodable {
        let latestKg: Double?
        let deltaKg30Days: Double?
    }
    struct MemoryNote: Encodable {
        let kind: String
        let summary: String
        let confidence: Double
    }

    let goals: Goals
    let today: Today
    let week: Week
    let streak: Streak
    let weight: Weight
    let memory: [MemoryNote]
    let hourOfDay: Int
    let hasOngoingCulturalEvent: Bool
    let userID: String
    let locale: String

    static func from(_ context: CoachContext) -> WireCoachContext {
        WireCoachContext(
            goals: Goals(
                calorieGoalKcal: context.goals.calorieGoalKcal,
                proteinGoalGrams: context.goals.proteinGoalGrams,
                carbsGoalGrams: context.goals.carbsGoalGrams,
                fatGoalGrams: context.goals.fatGoalGrams,
                waterGoalMl: context.goals.waterGoalMl,
                goalKind: context.goals.goalKindRaw,
                dietMacroPreset: context.goals.dietMacroPresetRaw
            ),
            today: Today(
                caloriesKcal: context.today.caloriesKcal,
                proteinGrams: context.today.proteinGrams,
                carbsGrams: context.today.carbsGrams,
                fatGrams: context.today.fatGrams,
                entryCount: context.today.entryCount,
                hasLoggedToday: context.today.entryCount > 0
            ),
            week: Week(
                startAt: context.week.startAt,
                endAt: context.week.endAt,
                dailyCalorieAverages: context.week.dailyCalorieAverages,
                dailyProteinAverages: context.week.dailyProteinAverages,
                dailyWaterMl: context.week.dailyWaterMl,
                workoutCalories: context.week.workoutCalories,
                workoutMinutes: context.week.workoutMinutes,
                frequentFoods: context.week.frequentFoods,
                daysWithAnyEntry: context.week.daysWithAnyEntry,
                daysHittingProteinGoal: context.week.daysHittingProteinGoal,
                daysWithinCalorieGoal: context.week.daysWithinCalorieGoal,
                bestCalorieDayOffset: context.week.bestCalorieDayOffset,
                weakestProteinDayOffset: context.week.weakestProteinDayOffset
            ),
            streak: Streak(
                current: context.streak.current,
                longest: context.streak.longest,
                freezesAvailable: context.streak.freezesAvailable,
                atRiskToday: context.streak.atRiskToday
            ),
            weight: Weight(
                latestKg: context.weight.latestKg,
                deltaKg30Days: context.weight.deltaKg30Days
            ),
            memory: context.memory.map {
                MemoryNote(kind: $0.kindRaw, summary: $0.summary, confidence: $0.confidence)
            },
            hourOfDay: context.hourOfDay,
            hasOngoingCulturalEvent: context.hasOngoingCulturalEvent,
            userID: context.userRemoteID ?? "anonymous",
            locale: LocalizationStore.currentLanguageCode()
        )
    }
}

private struct WeeklyDebriefResponse: Decodable {
    struct WireSection: Decodable {
        let id: String?
        let title: String
        let body: String
        let symbol: String?
    }

    let headline: String
    let sections: [WireSection]?
    let nextWeekRules: [String]?
    let insights: [WireCoachInsight]

    var cleanedSections: [WeeklyDebrief.Section] {
        (sections ?? [])
            .map { section in
                WeeklyDebrief.Section(
                    id: section.id?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        ?? section.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: section.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: section.body.trimmingCharacters(in: .whitespacesAndNewlines),
                    symbol: section.symbol?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        ?? "sparkles"
                )
            }
            .filter { !$0.title.isEmpty && !$0.body.isEmpty }
            .prefix(7)
            .map { $0 }
    }

    var cleanedRules: [String] {
        (nextWeekRules ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }
    }
}

private struct WireCoachInsight: Decodable {
    let tone: String
    let headline: String
    let body: String
    let actionTitle: String?
    let actionKind: String?
}

extension CoachInsight {
    fileprivate init(wire: WireCoachInsight) {
        let tone = CoachInsight.Tone(rawValue: wire.tone) ?? .encouragement
        let action = wire.actionKind.flatMap(CoachInsight.ActionKind.init(rawValue:))
        self.init(
            tone: tone,
            headline: wire.headline,
            body: wire.body,
            actionTitle: wire.actionTitle,
            actionKind: action
        )
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension JSONEncoder {
    fileprivate static var workerCoach: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
