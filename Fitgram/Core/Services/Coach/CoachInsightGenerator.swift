import Foundation

/// Strategy boundary so the rule-based coach + Worker-backed Gemini coach
/// are swappable behind the same call site. Generators must return
/// insights in display order — most relevant first.
///
/// Both methods are async so AI-backed implementations don't have to
/// fake synchronicity. The rule-based implementation just returns
/// immediately; the Worker one suspends on the network call.
protocol CoachInsightGenerator: Sendable {
    func generate(for context: CoachContext) async -> [CoachInsight]
    /// Same insights plus whether they came from the AI model. Only AI
    /// output is worth reusing for an unchanged context — a fallback after
    /// a network error should be retried on the next refresh.
    func generateBatch(for context: CoachContext) async -> CoachInsightBatch
    func generateDailyPlan(for context: CoachContext, now: Date) async -> DailyOlaPlan
    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult
}

/// Insights plus where they came from; see `generateBatch(for:)`.
struct CoachInsightBatch: Sendable, Equatable {
    let insights: [CoachInsight]
    let isFromAI: Bool
}

extension CoachInsightGenerator {
    func generateBatch(for context: CoachContext) async -> CoachInsightBatch {
        CoachInsightBatch(insights: await generate(for: context), isFromAI: false)
    }

    func generateDailyPlan(for context: CoachContext, now: Date) async -> DailyOlaPlan {
        DailyOlaPlanBuilder.build(context: context, now: now)
    }
}

/// What the weekly debrief endpoint returns (or a rule-based equivalent).
/// `headline` is optional — when nil the caller derives one from stats.
struct WeeklyDebriefAIResult: Sendable, Equatable {
    let headline: String?
    let sections: [WeeklyDebrief.Section]
    let nextWeekRules: [String]
    let insights: [CoachInsight]

    init(
        headline: String?,
        sections: [WeeklyDebrief.Section] = [],
        nextWeekRules: [String] = [],
        insights: [CoachInsight]
    ) {
        self.headline = headline
        self.sections = sections
        self.nextWeekRules = nextWeekRules
        self.insights = insights
    }
}
