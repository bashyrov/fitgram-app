import Foundation

/// Strategy boundary so the rule-based coach today and the Claude-backed
/// coach later are swappable behind the same call site. Generators must
/// return insights in display order — most relevant first.
protocol CoachInsightGenerator: Sendable {
    func generate(for context: CoachContext) -> [CoachInsight]
}
