#if DEBUG
import Foundation
import OSLog
import SwiftData

// Screenshot-ready demo data installed when `DebugBypass.bypassAuth` is on.
extension DebugBypass {
    /// UserDefaults key stamped once the v3 demo fixtures are installed.
    /// Bump the suffix whenever the seed shape changes so old installs
    /// can re-seed without piling duplicates on top.
    private static let seededVersionKey = "DebugBypassSeedV7"

    /// Inserts a fully-onboarded Premium user with rich, screenshot-ready
    /// data. When bumping the seed version, **every previous demo row gets
    /// wiped first** — without this, leftover Polish strings (meals,
    /// recipes, achievements, favorites) from earlier seeds leak into the
    /// UI on every relaunch.
    @MainActor
    static func seed(container: ModelContainer) throws {
        let context = ModelContext(container)
        let remoteID = fakeAuthUser.id

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        let userExists = try context.fetch(userDescriptor).first != nil
        if userExists && UserDefaults.standard.bool(forKey: seededVersionKey) {
            Logger.persistence.notice("DebugBypass: seed v6 already applied, skipping")
            return
        }

        // Fresh-version migration: nuke every demo row from older seeds
        // so the new English strings replace stale Polish ones.
        try wipePreviousSeed(context: context, remoteID: remoteID)

        try seedUser(context: context, remoteID: remoteID)
        try seedMeals(context: context)
        try seedStreak(context: context, remoteID: remoteID)
        try seedWater(context: context, remoteID: remoteID)
        try seedWeights(context: context, remoteID: remoteID)
        try seedAchievements(context: context, remoteID: remoteID)
        try seedRecipes(context: context)

        try context.save()
        UserDefaults.standard.set(true, forKey: seededVersionKey)
        // Drop the older-version flags so future bumps trigger a re-wipe.
        for legacy in ["DebugBypassSeedV3", "DebugBypassSeedV4", "DebugBypassSeedV5", "DebugBypassSeedV6"] {
            UserDefaults.standard.removeObject(forKey: legacy)
        }
        Logger.persistence.notice("DebugBypass seeded full premium demo fixtures (v7)")
    }

    @MainActor
    private static func wipePreviousSeed(context: ModelContext, remoteID: String) throws {
        try context.delete(model: MealEntry.self)
        try context.delete(model: Recipe.self)
        try context.delete(model: RecipeIngredient.self)
        try context.delete(model: WeightEntry.self)
        try context.delete(model: WaterEntry.self)
        try context.delete(model: Streak.self)
        try context.delete(model: Achievement.self)
        try context.delete(model: FavoriteMeal.self)
        try context.delete(model: CoachInsightLog.self)
        try context.save()
        Logger.persistence.notice("DebugBypass: wiped previous demo rows")
    }

    // MARK: - Seeders

    @MainActor
    private static func seedUser(context: ModelContext, remoteID: String) throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        let user: User
        if let existing = try context.fetch(descriptor).first {
            user = existing
        } else {
            user = User(
                remoteID: remoteID,
                email: fakeAuthUser.email,
                displayName: fakeAuthUser.displayName,
                providerKind: .apple
            )
            context.insert(user)
        }
        user.onboardingCompletedAt = Date().addingTimeInterval(-90 * 24 * 3600)
        user.goalKind = .lose
        user.activityLevel = .moderate
        user.biologicalSex = .female
        user.heightCm = 168
        user.weightKg = 62.4
        user.goalTargetWeightKg = 58.0
        user.goalStartDate = Date().addingTimeInterval(-84 * 24 * 3600)
        user.dailyCalorieGoalKcal = 1800
        user.proteinGoalGrams = 110
        user.carbsGoalGrams = 200
        user.fatGoalGrams = 60

        // Seed AI Coach recommendations so the goal-tracking card on
        // Today renders its 3 inline tips during screenshot capture.
        if user.latestRecommendationsJSON == nil {
            let recs: [String: Any] = [
                "summary": "You're 4 kg in, 5 to go. Consistency wins this.",
                "tips": [
                    [
                        "icon": "🥚", "title": "Front-load protein",
                        "description": "Aim for 35 g at breakfast — keeps lunch cravings calmer.",
                    ],
                    [
                        "icon": "🚶", "title": "10-min walk after dinner",
                        "description": "Drops post-meal glucose by ~20% on average.",
                    ],
                    [
                        "icon": "💧", "title": "One extra glass at 4 PM",
                        "description": "Cuts the 5 PM snack reflex more than half of users notice.",
                    ],
                ],
                "warnings": [],
                "nextSteps": "Log dinner before 21:00 and you'll close today under 1700 kcal.",
                "source": "rule_based",
            ]
            if let data = try? JSONSerialization.data(withJSONObject: recs) {
                user.latestRecommendationsJSON = data
            }
        }
    }

    @MainActor
    private static func seedMeals(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<MealEntry>())
        guard existingCount < 30 else { return }
        let now = Date()
        let times = todayMealTimes(now: now)
        (morningMeals(at: times) + mainMeals(at: times)).forEach { context.insert($0) }
        seedPastMeals(context: context, today: now)
    }

    /// Breakfast / snack / lunch / dinner clock times for today.
    private static func todayMealTimes(now: Date) -> [Date] {
        let calendar = Calendar.current
        // Anchor today's meals to realistic clock hours (8 / 11 / 13 / 19).
        // If a target hour is still in the future relative to `now` (e.g.,
        // the seed runs at 02:20), squish that meal into the early morning
        // so it stays within today and reads as already-past.
        let startOfToday = calendar.startOfDay(for: now)
        let mealHours: [Int] = [8, 11, 13, 19]
        let mealTimes: [Date] = mealHours.enumerated().map { idx, hour in
            let candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            if candidate < now { return candidate }
            // Target hour hasn't happened yet — fall back to past hours of today.
            return startOfToday.addingTimeInterval(TimeInterval(idx + 1) * 30 * 60)
        }
        return mealTimes
    }

    private static func morningMeals(at times: [Date]) -> [MealEntry] {
        let breakfast = MealEntry(
            consumedAt: times[0],
            mealType: .breakfast,
            source: .quickDatabase,
            items: [
                FoodItem(
                    name: "Oatmeal with raspberries",
                    quantityGrams: 250, caloriesKcal: 320,
                    proteinGrams: 12, carbsGrams: 48, fatGrams: 7
                ),
                FoodItem(
                    name: "Coffee with milk",
                    quantityGrams: 200, caloriesKcal: 60,
                    proteinGrams: 3, carbsGrams: 6, fatGrams: 2
                ),
            ]
        )
        let snack = MealEntry(
            consumedAt: times[1],
            mealType: .snack,
            source: .quickDatabase,
            items: [
                FoodItem(
                    name: "Apple",
                    quantityGrams: 180, caloriesKcal: 95,
                    proteinGrams: 0.5, carbsGrams: 25, fatGrams: 0.3
                )
            ]
        )
        return [breakfast, snack]
    }

    private static func mainMeals(at times: [Date]) -> [MealEntry] {
        let lunch = MealEntry(
            consumedAt: times[2],
            mealType: .lunch,
            source: .photoScan,
            items: [
                FoodItem(
                    name: "Breaded pork cutlet",
                    quantityGrams: 180, caloriesKcal: 420,
                    proteinGrams: 32, carbsGrams: 18, fatGrams: 22, confidence: 0.92
                ),
                FoodItem(
                    name: "Boiled potatoes",
                    quantityGrams: 200, caloriesKcal: 160,
                    proteinGrams: 4, carbsGrams: 36, fatGrams: 0.3, confidence: 0.95
                ),
                FoodItem(
                    name: "Cabbage slaw",
                    quantityGrams: 120, caloriesKcal: 60,
                    proteinGrams: 1.4, carbsGrams: 8, fatGrams: 3, confidence: 0.81
                ),
            ]
        )
        let dinner = MealEntry(
            consumedAt: times[3],
            mealType: .dinner,
            source: .recipe,
            items: [
                FoodItem(
                    name: "Greek salad with tofu",
                    quantityGrams: 350, caloriesKcal: 420,
                    proteinGrams: 26, carbsGrams: 18, fatGrams: 28
                )
            ]
        )
        return [lunch, dinner]
    }

    @MainActor
    private static func seedPastMeals(context: ModelContext, today: Date) {
        let calendar = Calendar.current
        // 29 prior days of meals — pseudo-random but deterministic per day.
        for daysBack in 1...29 {
            guard let day = calendar.date(byAdding: .day, value: -daysBack, to: today) else { continue }
            let kcalBase = 1700 + ((daysBack * 73) % 350) - 150
            let lunchKcal = Double(max(900, kcalBase * 60 / 100))
            let dinnerKcal = Double(max(400, kcalBase * 40 / 100))

            context.insert(
                MealEntry(
                    consumedAt: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: day) ?? day,
                    mealType: .breakfast,
                    source: .quickDatabase,
                    items: [
                        FoodItem(
                            name: "Oatmeal", quantityGrams: 250,
                            caloriesKcal: 300, proteinGrams: 10, carbsGrams: 45, fatGrams: 6
                        )
                    ]
                )
            )
            context.insert(
                MealEntry(
                    consumedAt: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: day) ?? day,
                    mealType: .lunch, source: .photoScan,
                    items: [
                        FoodItem(
                            name: "Lunch", quantityGrams: 350,
                            caloriesKcal: lunchKcal, proteinGrams: 35, carbsGrams: 50, fatGrams: 22
                        )
                    ]
                )
            )
            context.insert(
                MealEntry(
                    consumedAt: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: day) ?? day,
                    mealType: .dinner, source: .quickDatabase,
                    items: [
                        FoodItem(
                            name: "Dinner", quantityGrams: 280,
                            caloriesKcal: dinnerKcal, proteinGrams: 28, carbsGrams: 30, fatGrams: 14
                        )
                    ]
                )
            )
        }
    }

    @MainActor
    private static func seedStreak(context: ModelContext, remoteID: String) throws {
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(
            Streak(
                userRemoteID: remoteID,
                currentLength: 23,
                longestLength: 47,
                lastLoggedDate: Date(),
                freezesAvailable: 2
            )
        )
    }

    @MainActor
    private static func seedWater(context: ModelContext, remoteID: String) throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.userRemoteID == remoteID && $0.recordedAt >= startOfToday }
        )
        guard try context.fetch(descriptor).isEmpty else { return }
        // Spread 6 glasses evenly between startOfToday and now so a fresh
        // install always reads 6 × 250 ml = 1.5 L "today", regardless of
        // wall-clock hour at install time.
        let secondsSinceMidnight = max(now.timeIntervalSince(startOfToday), 600)
        let slice = secondsSinceMidnight / 7
        for index in 1...6 {
            let when = startOfToday.addingTimeInterval(slice * Double(index))
            context.insert(
                WaterEntry(userRemoteID: remoteID, recordedAt: when, milliliters: 250)
            )
        }
    }

    @MainActor
    private static func seedWeights(context: ModelContext, remoteID: String) throws {
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard try context.fetch(descriptor).count < 8 else { return }
        let calendar = Calendar.current
        let today = Date()
        for weeksBack in 0...11 {
            guard let day = calendar.date(byAdding: .day, value: -weeksBack * 7, to: today) else { continue }
            let kg = 62.4 + Double(weeksBack) * 0.45
            context.insert(
                WeightEntry(
                    userRemoteID: remoteID,
                    recordedAt: day,
                    weightKg: kg
                )
            )
        }
    }

    private struct SeedAchievement {
        let kind: String
        let title: String
        let details: String
        let daysAgo: Int
    }

    @MainActor
    private static func seedAchievements(context: ModelContext, remoteID: String) throws {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard try context.fetch(descriptor).count < 5 else { return }
        let calendar = Calendar.current
        let today = Date()
        let unlocked: [SeedAchievement] = [
            SeedAchievement(
                kind: "meal.first", title: "First meal", details: "You logged your first meal.", daysAgo: 89),
            SeedAchievement(
                kind: "scan.first", title: "First scan", details: "You scanned a plate with the camera.", daysAgo: 87),
            SeedAchievement(
                kind: "barcode.first", title: "First barcode", details: "You scanned a barcode.", daysAgo: 80),
            SeedAchievement(kind: "streak.7", title: "Week!", details: "Seven days of entries in a row.", daysAgo: 70),
            SeedAchievement(kind: "streak.30", title: "Month of rhythm", details: "Thirty days in a row.", daysAgo: 30),
            SeedAchievement(
                kind: "protein.heavy", title: "Protein day", details: "Ate ≥1g of protein per kg.", daysAgo: 25),
            SeedAchievement(
                kind: "recipe.first", title: "First recipe", details: "You added your first recipe.", daysAgo: 60),
            SeedAchievement(
                kind: "weight.tracked", title: "First weight", details: "You logged your weight.", daysAgo: 84),
            SeedAchievement(
                kind: "voice.first", title: "Voice lunch", details: "You added a meal by voice.", daysAgo: 50),
        ]
        for seed in unlocked {
            let when = calendar.date(byAdding: .day, value: -seed.daysAgo, to: today) ?? today
            context.insert(
                Achievement(
                    userRemoteID: remoteID,
                    kind: seed.kind,
                    title: seed.title,
                    details: seed.details,
                    earnedAt: when
                )
            )
        }
    }
}
#endif
