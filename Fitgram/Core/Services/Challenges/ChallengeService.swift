import Foundation
import SwiftData

/// Materialises challenge progress for the current ISO week. Uses Monday
/// as the week start (`firstWeekday = 2`) so "Codzienny rytm" maps to a
/// natural Polish work-week cadence.
@MainActor
final class ChallengeService {
    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        calendar: Calendar = ChallengeService.mondayStartCalendar(),
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    static func mondayStartCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        return calendar
    }

    func currentProgress(calorieGoal: Int, proteinGoal: Int) -> [ChallengeProgress] {
        let (weekStart, weekEnd) = currentWeekBounds()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= weekStart && $0.consumedAt < weekEnd }
        )
        let meals = (try? context.fetch(descriptor)) ?? []
        return ChallengeEvaluator.evaluate(
            ChallengeCatalog.all,
            with: .init(
                meals: meals,
                calorieGoal: calorieGoal,
                proteinGoal: proteinGoal,
                calendar: calendar
            )
        )
    }

    /// (startOfWeek, startOfNextWeek). Both at midnight in the user's
    /// local timezone.
    func currentWeekBounds() -> (Date, Date) {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now())
        let start = calendar.date(from: components) ?? now()
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now()
        return (start, end)
    }
}
