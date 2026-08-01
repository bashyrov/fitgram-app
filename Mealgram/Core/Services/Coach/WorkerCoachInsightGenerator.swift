import Foundation
import OSLog

/// Cloudflare Worker-backed AI coach. Wraps two endpoints:
///
///   POST /api/v1/coach/daily-insight   — for Today screen tips
///   POST /api/v1/coach/weekly-debrief  — for "How you're doing" sheet
///
/// Both serialise the `CoachContext` to a flat JSON body and parse a
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
        do {
            let request = WireCoachContext.from(context)
            let endpoint = try Endpoint.json(
                path: "/api/v1/coach/daily-insight",
                method: .post,
                payload: request,
                requiresAuth: true
            )
            let response = try await client.send(endpoint, expecting: DailyInsightResponse.self)
            let insights = response.insights.map(CoachInsight.init(wire:))
            if insights.isEmpty {
                Logger.coach.notice("worker daily-insight returned empty list, using fallback")
                return await fallback.generate(for: context)
            }
            return insights
        } catch {
            Logger.coach.error(
                "worker daily-insight failed: \(String(describing: error), privacy: .public)")
            return await fallback.generate(for: context)
        }
    }

    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult {
        do {
            let request = WireCoachContext.from(context)
            let endpoint = try Endpoint.json(
                path: "/api/v1/coach/weekly-debrief",
                method: .post,
                payload: request,
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
        let dailyCalorieAverages: [Double]
        let dailyProteinAverages: [Double]
        let daysWithAnyEntry: Int
        let daysHittingProteinGoal: Int
        let daysWithinCalorieGoal: Int
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

    let goals: Goals
    let today: Today
    let week: Week
    let streak: Streak
    let weight: Weight
    let hourOfDay: Int
    let hasOngoingCulturalEvent: Bool
    let userID: String
    let locale: String

    static func from(_ context: CoachContext) -> WireCoachContext {
        WireCoachContext(
            goals: Goals(
                calorieGoalKcal: context.goals.calorieGoalKcal,
                proteinGoalGrams: context.goals.proteinGoalGrams
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
                dailyCalorieAverages: context.week.dailyCalorieAverages,
                dailyProteinAverages: context.week.dailyProteinAverages,
                daysWithAnyEntry: context.week.daysWithAnyEntry,
                daysHittingProteinGoal: context.week.daysHittingProteinGoal,
                daysWithinCalorieGoal: context.week.daysWithinCalorieGoal
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
            hourOfDay: context.hourOfDay,
            hasOngoingCulturalEvent: context.hasOngoingCulturalEvent,
            userID: context.userRemoteID ?? "anonymous",
            locale: LocalizationStore.currentLanguageCode()
        )
    }
}

private struct DailyInsightResponse: Decodable {
    let insights: [WireCoachInsight]
}

private struct WeeklyDebriefResponse: Decodable {
    let headline: String
    let insights: [WireCoachInsight]
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
