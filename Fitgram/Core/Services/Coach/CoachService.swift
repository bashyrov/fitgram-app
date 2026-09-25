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
    private let logStore: CoachInsightLogStore?
    private let dismissalStore: CoachDismissalStore?
    private let dailyPlanStore: DailyOlaPlanStore
    private let calorieOverrideStore: DailyCalorieOverrideStore
    private let macroOverrideStore: DailyMacroOverrideStore
    private let activityCaloriePolicyStore: ActivityCaloriePolicyStore

    init(
        container: ModelContainer,
        streakService: StreakService,
        weightService: WeightService,
        culturalEvents: CulturalEventService = CulturalEventService(),
        generator: any CoachInsightGenerator = RuleBasedCoach(),
        logStore: CoachInsightLogStore? = nil,
        dismissalStore: CoachDismissalStore? = nil,
        dailyPlanStore: DailyOlaPlanStore = DailyOlaPlanStore(),
        calorieOverrideStore: DailyCalorieOverrideStore = DailyCalorieOverrideStore(),
        macroOverrideStore: DailyMacroOverrideStore = DailyMacroOverrideStore(),
        activityCaloriePolicyStore: ActivityCaloriePolicyStore = ActivityCaloriePolicyStore(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.weightService = weightService
        self.culturalEvents = culturalEvents
        self.generator = generator
        self.logStore = logStore
        self.dismissalStore = dismissalStore
        self.dailyPlanStore = dailyPlanStore
        self.calorieOverrideStore = calorieOverrideStore
        self.macroOverrideStore = macroOverrideStore
        self.activityCaloriePolicyStore = activityCaloriePolicyStore
        self.calendar = calendar
        self.now = now
    }

    func insights(for userRemoteID: String) async -> [CoachInsight] {
        let context = buildContext(for: userRemoteID)
        let allInsights = await generator.generate(for: context)
        guard let dismissalStore else { return allInsights }
        return allInsights.filter { !dismissalStore.isDismissed(headline: $0.headline) }
    }

    func dismiss(insight: CoachInsight) {
        dismissalStore?.dismiss(headline: insight.headline)
    }

    func headline(for userRemoteID: String) async -> CoachInsight? {
        await insights(for: userRemoteID).first
    }

    func weeklyDebrief(for userRemoteID: String) async -> WeeklyDebrief {
        let context = buildContext(for: userRemoteID)
        let debrief = await WeeklyDebrief.from(context: context, generator: generator, now: now())
        logStore?.record(debrief, for: userRemoteID)
        return debrief
    }

    func dailyPlan(for userRemoteID: String) async -> DailyOlaPlan {
        let context = buildContext(for: userRemoteID)
        let currentNow = now()
        let livePlan = DailyOlaPlanBuilder.build(context: context, now: currentNow)
        let locale = LocalizationStore.currentLanguageCode()
        let signature = dailyPlanSignature(for: context, moment: livePlan.moment)
        if let cached = dailyPlanStore.load(
            userRemoteID: userRemoteID,
            dateKey: livePlan.dateKey,
            locale: locale,
            signature: signature
        ) {
            return cached.refreshed(with: livePlan)
        }
        let generated = await generator.generateDailyPlan(for: context, now: currentNow)
        if generated != livePlan {
            dailyPlanStore.save(generated, userRemoteID: userRemoteID, locale: locale, signature: signature)
        }
        return generated.refreshed(with: livePlan)
    }

    func history(for userRemoteID: String, limit: Int = 12) -> [CoachInsightLog] {
        logStore?.recent(for: userRemoteID, limit: limit) ?? []
    }

    func recordFeedback(helpful: Bool, for userRemoteID: String) {
        logStore?.recordFeedback(helpful: helpful, for: userRemoteID)
    }

    func feedback(for userRemoteID: String) -> Bool? {
        logStore?.feedback(for: userRemoteID)
    }

    func decode(log: CoachInsightLog) -> [CoachInsight] {
        guard let logStore else { return [] }
        return logStore.decodeInsights(log.insightsJSON).compactMap { stored in
            guard let tone = CoachInsight.Tone(rawValue: stored.tone) else { return nil }
            return CoachInsight(
                tone: tone,
                headline: stored.headline,
                body: stored.body,
                actionTitle: stored.actionTitle,
                actionKind: stored.actionKind.flatMap { CoachInsight.ActionKind(rawValue: $0) }
            )
        }
    }

    // MARK: - Context assembly

    private func buildContext(for userRemoteID: String) -> CoachContext {
        let currentNow = now()
        let todayStart = calendar.startOfDay(for: currentNow)
        let user = fetchUser(for: userRemoteID)
        let profileCalorieGoal = user?.dailyCalorieGoalKcal ?? 2100
        let baseCalorieGoal =
            calorieOverrideStore.value(for: userRemoteID, on: todayStart)
            ?? profileCalorieGoal
        var goals = CoachContext.Goals(
            calorieGoalKcal: baseCalorieGoal,
            proteinGoalGrams: user?.proteinGoalGrams ?? 100,
            carbsGoalGrams: user?.carbsGoalGrams ?? 240,
            fatGoalGrams: user?.fatGoalGrams ?? 70,
            waterGoalMl: user?.waterGoalMl ?? 2500,
            goalKindRaw: user?.goalKind.rawValue ?? GoalKind.maintain.rawValue,
            dietMacroPresetRaw: user?.dietMacroPreset.rawValue ?? DietMacroPreset.balanced.rawValue
        )
        let today = aggregateToday()
        let week = CoachWeekAggregator(
            container: container,
            calendar: calendar,
            now: now,
            activityCaloriePolicyStore: activityCaloriePolicyStore
        ).aggregate(
            userRemoteID: userRemoteID,
            registeredAt: user?.createdAt ?? user?.onboardingCompletedAt ?? currentNow,
            calorieGoal: goals.calorieGoalKcal,
            proteinGoal: goals.proteinGoalGrams
        )
        if activityCaloriePolicyStore.includesActivityCalories(on: currentNow, now: currentNow) {
            goals.calorieGoalKcal += Int(
                todayWorkoutCaloriesCountedTowardGoal(userRemoteID: userRemoteID, on: todayStart).rounded()
            )
        }
        applyDailyMacroGoals(
            &goals, user: user, userRemoteID: userRemoteID, on: todayStart, baseCalorieGoal: baseCalorieGoal)
        let streak = streakSnapshot(for: userRemoteID)
        let weight = weightSnapshot(for: userRemoteID)
        let hour = calendar.component(.hour, from: currentNow)
        let event = culturalEvents.upcoming(from: currentNow) != nil
        let memory = memorySnapshot(for: userRemoteID)
        return CoachContext(
            goals: goals,
            today: today,
            week: week,
            streak: streak,
            weight: weight,
            hourOfDay: hour,
            hasOngoingCulturalEvent: event,
            memory: memory,
            userRemoteID: userRemoteID
        )
    }

    private func applyDailyMacroGoals(
        _ goals: inout CoachContext.Goals,
        user: User?,
        userRemoteID: String,
        on date: Date,
        baseCalorieGoal: Int
    ) {
        if let override = macroOverrideStore.value(for: userRemoteID, on: date) {
            goals.proteinGoalGrams = override.protein
            goals.carbsGoalGrams = override.carbs
            goals.fatGoalGrams = override.fat
            return
        }

        guard let user else { return }
        if user.macrosOverridden {
            let ratio = max(0.25, min(2.5, Double(goals.calorieGoalKcal) / Double(max(1, baseCalorieGoal))))
            goals.proteinGoalGrams = Int((Double(user.proteinGoalGrams) * ratio).rounded())
            goals.carbsGoalGrams = Int((Double(user.carbsGoalGrams) * ratio).rounded())
            goals.fatGoalGrams = Int((Double(user.fatGoalGrams) * ratio).rounded())
            return
        }

        let split = GoalCalculator.macroSplit(for: user.goalKind, preset: user.dietMacroPreset)
        let calories = Double(max(0, goals.calorieGoalKcal))
        goals.proteinGoalGrams = Int(((calories * split.protein) / 4).rounded())
        goals.carbsGoalGrams = Int(((calories * split.carbs) / 4).rounded())
        goals.fatGoalGrams = Int(((calories * split.fat) / 9).rounded())
    }

    private func todayWorkoutCaloriesCountedTowardGoal(userRemoteID: String, on date: Date) -> Double {
        let context = ModelContext(container)
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.userRemoteID == userRemoteID
                    && entry.recordedAt >= dayStart
                    && entry.recordedAt < dayEnd
                    && entry.countsTowardDailyGoal
            }
        )
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.caloriesBurnedKcal }
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

    private func memorySnapshot(for userRemoteID: String) -> [CoachContext.MemoryNote] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachMemoryNote>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID },
            sortBy: [SortDescriptor(\CoachMemoryNote.updatedAt, order: .reverse)]
        )
        let notes = (try? context.fetch(descriptor)) ?? []
        return notes.prefix(8).map {
            CoachContext.MemoryNote(
                kindRaw: $0.kindRaw,
                summary: $0.summary,
                confidence: $0.confidence
            )
        }
    }

    private func dailyPlanSignature(for context: CoachContext, moment: DailyOlaPlan.Moment) -> String {
        let weight = context.weight.latestKg.map { String(format: "%.1f", $0) } ?? "none"
        let delta = context.weight.deltaKg30Days.map { String(format: "%.1f", $0) } ?? "none"
        let currentDay = calendar.startOfDay(for: now())
        let dayOffset = calendar.dateComponents([.day], from: context.week.startAt, to: currentDay).day ?? 0
        let todayWater =
            context.week.dailyWaterMl.indices.contains(dayOffset)
            ? context.week.dailyWaterMl[dayOffset]
            : 0
        let todayWorkoutCalories =
            context.week.workoutCalories.indices.contains(dayOffset)
            ? Int(context.week.workoutCalories[dayOffset].rounded())
            : 0
        let memory = context.memory
            .map { "\($0.kindRaw):\($0.summary):\(Int(($0.confidence * 100).rounded()))" }
            .joined(separator: "|")
        let raw = [
            moment.rawValue,
            "\(context.goals.calorieGoalKcal)",
            "\(context.goals.proteinGoalGrams)",
            "\(context.goals.carbsGoalGrams)",
            "\(context.goals.fatGoalGrams)",
            "\(context.goals.waterGoalMl)",
            context.goals.goalKindRaw,
            context.goals.dietMacroPresetRaw,
            "\(Int(context.today.caloriesKcal.rounded()))",
            "\(Int(context.today.proteinGrams.rounded()))",
            "\(Int(context.today.carbsGrams.rounded()))",
            "\(Int(context.today.fatGrams.rounded()))",
            "\(context.today.entryCount)",
            "\(todayWater)",
            "\(todayWorkoutCalories)",
            weight,
            delta,
            "\(context.week.daysWithAnyEntry)",
            "\(context.week.daysHittingProteinGoal)",
            "\(context.week.daysWithinCalorieGoal)",
            context.week.frequentFoods.joined(separator: ","),
            memory,
        ].joined(separator: "#")
        return checksum(raw)
    }

    private func checksum(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
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

struct DailyOlaPlanStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load(userRemoteID: String, dateKey: String, locale: String, signature: String) -> DailyOlaPlan? {
        guard
            let data = defaults.data(
                forKey: key(userRemoteID: userRemoteID, dateKey: dateKey, locale: locale, signature: signature)
            )
        else {
            return nil
        }
        return try? decoder.decode(DailyOlaPlan.self, from: data)
    }

    func save(_ plan: DailyOlaPlan, userRemoteID: String, locale: String, signature: String) {
        guard let data = try? encoder.encode(plan) else { return }
        defaults.set(
            data,
            forKey: key(userRemoteID: userRemoteID, dateKey: plan.dateKey, locale: locale, signature: signature)
        )
    }

    private func key(userRemoteID: String, dateKey: String, locale: String, signature: String) -> String {
        let safeUserID =
            userRemoteID
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "coach.dailyPlan.\(safeUserID).\(locale).\(dateKey).\(signature)"
    }
}
