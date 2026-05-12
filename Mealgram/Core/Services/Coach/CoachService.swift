import Foundation
import SwiftData

/// Materialises a `CoachContext` from SwiftData + supporting services,
/// then runs whatever `CoachInsightGenerator` the composition root wired
/// up. Lives on the main actor because every collaborator does.
@MainActor
final class CoachService {
    private let container: ModelContainer
    private let streakService: StreakService
    private let weightService: WeightService
    private let culturalEvents: CulturalEventService
    private let generator: any CoachInsightGenerator
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        streakService: StreakService,
        weightService: WeightService,
        culturalEvents: CulturalEventService = CulturalEventService(),
        generator: any CoachInsightGenerator = RuleBasedCoach(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.weightService = weightService
        self.culturalEvents = culturalEvents
        self.generator = generator
        self.calendar = calendar
        self.now = now
    }

    func insights(for userRemoteID: String) -> [CoachInsight] {
        let context = buildContext(for: userRemoteID)
        return generator.generate(for: context)
    }

    func headline(for userRemoteID: String) -> CoachInsight? {
        insights(for: userRemoteID).first
    }

    func weeklyDebrief(for userRemoteID: String) -> WeeklyDebrief {
        let context = buildContext(for: userRemoteID)
        return WeeklyDebrief.from(context: context, generator: generator, now: now())
    }

    // MARK: - Context assembly

    private func buildContext(for userRemoteID: String) -> CoachContext {
        let user = fetchUser(for: userRemoteID)
        let goals = CoachContext.Goals(
            calorieGoalKcal: user?.dailyCalorieGoalKcal ?? 2100,
            proteinGoalGrams: user?.proteinGoalGrams ?? 100
        )
        let today = aggregateToday()
        let week = aggregateWeek(calorieGoal: goals.calorieGoalKcal, proteinGoal: goals.proteinGoalGrams)
        let streak = streakSnapshot(for: userRemoteID)
        let weight = weightSnapshot(for: userRemoteID)
        let hour = calendar.component(.hour, from: now())
        let event = culturalEvents.upcoming(from: now()) != nil
        return CoachContext(
            goals: goals,
            today: today,
            week: week,
            streak: streak,
            weight: weight,
            hourOfDay: hour,
            hasOngoingCulturalEvent: event
        )
    }

    private func fetchUser(for userRemoteID: String) -> User? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        return try? context.fetch(descriptor).first
    }

    private func aggregateToday() -> CoachContext.Today {
        let context = ModelContext(container)
        let dayStart = calendar.startOfDay(for: now())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return CoachContext.Today(
                caloriesKcal: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0,
                entryCount: 0, lastLoggedAt: nil
            )
        }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd },
            sortBy: [SortDescriptor(\MealEntry.consumedAt, order: .reverse)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return CoachContext.Today(
            caloriesKcal: entries.reduce(0) { $0 + $1.totalCaloriesKcal },
            proteinGrams: entries.reduce(0) { $0 + $1.totalProteinGrams },
            carbsGrams: entries.reduce(0) { $0 + $1.totalCarbsGrams },
            fatGrams: entries.reduce(0) { $0 + $1.totalFatGrams },
            entryCount: entries.count,
            lastLoggedAt: entries.first?.consumedAt
        )
    }

    private func aggregateWeek(calorieGoal: Int, proteinGoal: Int) -> CoachContext.Week {
        let context = ModelContext(container)
        let today = calendar.startOfDay(for: now())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
            let windowEnd = calendar.date(byAdding: .day, value: 1, to: today)
        else {
            return CoachContext.Week(
                dailyCalorieAverages: [], dailyProteinAverages: [],
                daysWithAnyEntry: 0, daysHittingProteinGoal: 0, daysWithinCalorieGoal: 0
            )
        }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= weekStart && $0.consumedAt < windowEnd }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        var caloriesByDay: [Date: Double] = [:]
        var proteinByDay: [Date: Double] = [:]
        for entry in entries {
            let key = calendar.startOfDay(for: entry.consumedAt)
            caloriesByDay[key, default: 0] += entry.totalCaloriesKcal
            proteinByDay[key, default: 0] += entry.totalProteinGrams
        }
        var dailyCalories: [Double] = []
        var dailyProtein: [Double] = []
        var daysWithEntry = 0
        var daysProteinHit = 0
        var daysCalorieHit = 0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = calendar.startOfDay(for: day)
            let kcal = caloriesByDay[key] ?? 0
            let protein = proteinByDay[key] ?? 0
            dailyCalories.append(kcal)
            dailyProtein.append(protein)
            if kcal > 0 { daysWithEntry += 1 }
            if proteinGoal > 0, protein >= Double(proteinGoal) * 0.9 { daysProteinHit += 1 }
            if calorieGoal > 0 {
                let ratio = kcal / Double(calorieGoal)
                if ratio >= 0.85, ratio <= 1.15 { daysCalorieHit += 1 }
            }
        }
        return CoachContext.Week(
            dailyCalorieAverages: dailyCalories,
            dailyProteinAverages: dailyProtein,
            daysWithAnyEntry: daysWithEntry,
            daysHittingProteinGoal: daysProteinHit,
            daysWithinCalorieGoal: daysCalorieHit
        )
    }

    private func streakSnapshot(for userRemoteID: String) -> CoachContext.Streak {
        guard let streak = try? streakService.currentStreak(for: userRemoteID) else {
            return CoachContext.Streak(current: 0, longest: 0, freezesAvailable: 0, atRiskToday: true)
        }
        let dayStart = calendar.startOfDay(for: now())
        let loggedToday: Bool = {
            guard let last = streak.lastLoggedDate else { return false }
            return calendar.startOfDay(for: last) >= dayStart
        }()
        return CoachContext.Streak(
            current: streak.currentLength,
            longest: streak.longestLength,
            freezesAvailable: streak.freezesAvailable,
            atRiskToday: !loggedToday && streak.currentLength > 0
        )
    }

    private func weightSnapshot(for userRemoteID: String) -> CoachContext.Weight {
        let entries = (try? weightService.entries(for: userRemoteID)) ?? []
        let summary = (try? weightService.summary(for: userRemoteID)).flatMap { $0 }
        return CoachContext.Weight(
            latestKg: entries.first?.weightKg,
            deltaKg30Days: summary?.thirtyDayDelta
        )
    }
}
