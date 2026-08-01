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
    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult
}

/// What the weekly debrief endpoint returns (or a rule-based equivalent).
/// `headline` is optional — when nil the caller derives one from stats.
struct WeeklyDebriefAIResult: Sendable, Equatable {
    let headline: String?
    let insights: [CoachInsight]
}
