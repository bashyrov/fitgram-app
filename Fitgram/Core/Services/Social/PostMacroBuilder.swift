import Foundation
import SwiftData

/// Turns logged meals into the frozen macro snapshots a post can carry.
enum PostMacroBuilder {
    static func mealLabel(_ type: MealType) -> String {
        switch type {
        case .breakfast: return L("Śniadanie")
        case .lunch: return L("Obiad")
        case .dinner: return L("Kolacja")
        case .snack: return L("Przekąska")
        }
    }

    /// Whole-day totals, or nil when nothing was logged.
    static func day(_ meals: [MealEntry], goalKcal: Int?) -> PostMacroSnapshot? {
        guard let first = meals.min(by: { $0.consumedAt < $1.consumedAt }) else { return nil }
        return PostMacroSnapshot(
            scope: .day,
            label: nil,
            consumedAt: first.consumedAt,
            kcal: Int(meals.reduce(0) { $0 + $1.totalCaloriesKcal }.rounded()),
            proteinG: Int(meals.reduce(0) { $0 + $1.totalProteinGrams }.rounded()),
            carbsG: Int(meals.reduce(0) { $0 + $1.totalCarbsGrams }.rounded()),
            fatG: Int(meals.reduce(0) { $0 + $1.totalFatGrams }.rounded()),
            goalKcal: goalKcal.flatMap { $0 > 0 ? $0 : nil },
            items: topItems(
                meals.flatMap { meal in meal.items.map { (item: $0, multiplier: meal.portionMultiplier) } }),
            mealCount: meals.count
        )
    }

    static func meal(_ meal: MealEntry, goalKcal: Int?) -> PostMacroSnapshot {
        PostMacroSnapshot(
            scope: .meal,
            label: mealLabel(meal.mealType),
            consumedAt: meal.consumedAt,
            kcal: Int(meal.totalCaloriesKcal.rounded()),
            proteinG: Int(meal.totalProteinGrams.rounded()),
            carbsG: Int(meal.totalCarbsGrams.rounded()),
            fatG: Int(meal.totalFatGrams.rounded()),
            goalKcal: goalKcal.flatMap { $0 > 0 ? $0 : nil },
            items: topItems(meal.items.map { (item: $0, multiplier: meal.portionMultiplier) }),
            mealCount: 1
        )
    }

    /// Distinct food names, highest calories first, at most four.
    static func topItems(_ items: [(item: FoodItem, multiplier: Double)]) -> [String] {
        var seen: Set<String> = []
        return
            items
            .sorted { $0.item.caloriesKcal * $0.multiplier > $1.item.caloriesKcal * $1.multiplier }
            .map { $0.item.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(4)
            .map { $0 }
    }

    /// Meals logged on the calendar day of `day`, oldest first.
    @MainActor
    static func meals(on day: Date, in context: ModelContext, calendar: Calendar = .current) -> [MealEntry] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= start && $0.consumedAt < end },
            sortBy: [SortDescriptor(\MealEntry.consumedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
