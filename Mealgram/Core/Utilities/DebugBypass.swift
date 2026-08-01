#if DEBUG
import Foundation
import OSLog
import SwiftData

/// Launch-time arguments for screenshot / preview flows. Compiled out of
/// release builds entirely via `#if DEBUG` so production never branches
/// on this.
enum DebugBypass {
    /// Pass `-mealgramDebugBypassAuth 1` (or set the env var) at launch
    /// to skip Sign in with Apple + onboarding and land in the main
    /// scene with seeded sample meals.
    static var bypassAuth: Bool {
        true
    }

    /// Override the initial tab. Values: "today" | "progress" | "profile".
    /// Useful for screenshot scripts.
    static var initialTab: String? {
        ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_TAB"]
    }

    /// Auto-open a sheet after launch for screenshot capture.
    /// Values: "streak-share" | "weight-log" | "ola-tips".
    static var initialSheet: String? {
        ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_SHEET"]
    }

    /// Auto-scroll a scrollable view to an anchor for screenshots.
    /// Values: "journey".
    static var initialScroll: String? {
        ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_SCROLL"]
    }

    static let fakeAuthUser = AuthUser(
        id: "debug-user-001",
        email: "demo@mealgram.xyz",
        displayName: "Anna",
        provider: .apple
    )

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
        let calendar = Calendar.current
        let now = Date()
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
        let breakfastTime = mealTimes[0]
        let snackTime = mealTimes[1]
        let lunchTime = mealTimes[2]
        let dinnerTime = mealTimes[3]
        let today = now

        let breakfast = MealEntry(
            consumedAt: breakfastTime,
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
            consumedAt: snackTime,
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
        let lunch = MealEntry(
            consumedAt: lunchTime,
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
            consumedAt: dinnerTime,
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
        [breakfast, snack, lunch, dinner].forEach { context.insert($0) }

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

    @MainActor
    private static func seedAchievements(context: ModelContext, remoteID: String) throws {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard try context.fetch(descriptor).count < 5 else { return }
        let calendar = Calendar.current
        let today = Date()
        let unlocked: [(String, String, String, Int)] = [
            ("meal.first", "First meal", "You logged your first meal.", 89),
            ("scan.first", "First scan", "You scanned a plate with the camera.", 87),
            ("barcode.first", "First barcode", "You scanned a barcode.", 80),
            ("streak.7", "Week!", "Seven days of entries in a row.", 70),
            ("streak.30", "Month of rhythm", "Thirty days in a row.", 30),
            ("protein.heavy", "Protein day", "Ate ≥1g of protein per kg.", 25),
            ("recipe.first", "First recipe", "You added your first recipe.", 60),
            ("weight.tracked", "First weight", "You logged your weight.", 84),
            ("voice.first", "Voice lunch", "You added a meal by voice.", 50),
        ]
        for (kind, title, details, daysAgo) in unlocked {
            let when = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            context.insert(
                Achievement(
                    userRemoteID: remoteID,
                    kind: kind,
                    title: title,
                    details: details,
                    earnedAt: when
                )
            )
        }
    }

    @MainActor
    private static func seedRecipes(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<Recipe>())
        guard existingCount < 3 else { return }
        let buddha = Recipe(
            title: "Tofu Buddha bowl",
            summary: "Light dinner in 25 minutes.",
            servings: 2,
            prepMinutes: 10,
            cookMinutes: 15,
            instructions: [
                "Cube the tofu and pan-fry.",
                "Cook the quinoa.",
                "Chop the vegetables and arrange in a bowl.",
                "Drizzle with tahini sauce.",
            ],
            ingredients: [
                RecipeIngredient(name: "Plain tofu", quantityText: "200 g", quantityGrams: 200),
                RecipeIngredient(name: "Quinoa", quantityText: "100 g", quantityGrams: 100),
                RecipeIngredient(name: "Avocado", quantityText: "1 piece", quantityGrams: 200),
                RecipeIngredient(name: "Carrot", quantityText: "1 piece", quantityGrams: 80),
                RecipeIngredient(name: "Tahini", quantityText: "2 tbsp", quantityGrams: 30),
            ]
        )
        buddha.caloriesPerServing = 520
        buddha.proteinPerServing = 24
        buddha.carbsPerServing = 38
        buddha.fatPerServing = 28
        buddha.cookCount = 7
        buddha.rating = 4.5
        buddha.isFavorite = true

        let pancakes = Recipe(
            title: "Banana pancakes",
            summary: "Three ingredients, ready in 10 minutes.",
            servings: 1,
            prepMinutes: 3,
            cookMinutes: 7,
            instructions: [
                "Blend banana, eggs and flour.",
                "Fry on the pan one minute each side.",
            ],
            ingredients: [
                RecipeIngredient(name: "Banana", quantityText: "1 piece", quantityGrams: 120),
                RecipeIngredient(name: "Eggs", quantityText: "2 pieces", quantityGrams: 100),
                RecipeIngredient(name: "Oat flour", quantityText: "30 g", quantityGrams: 30),
            ]
        )
        pancakes.caloriesPerServing = 320
        pancakes.proteinPerServing = 16
        pancakes.carbsPerServing = 42
        pancakes.fatPerServing = 9
        pancakes.cookCount = 4
        pancakes.rating = 4.0

        let salad = Recipe(
            title: "Greek salad with feta",
            summary: "A classic, with fresh vegetables.",
            servings: 2,
            prepMinutes: 15,
            cookMinutes: 0,
            instructions: [
                "Chop the tomatoes, cucumber and onion.",
                "Add feta, olives, and drizzle with olive oil.",
            ],
            ingredients: [
                RecipeIngredient(name: "Tomatoes", quantityText: "3 pieces", quantityGrams: 300),
                RecipeIngredient(name: "Cucumber", quantityText: "1 piece", quantityGrams: 200),
                RecipeIngredient(name: "Feta", quantityText: "150 g", quantityGrams: 150),
                RecipeIngredient(name: "Olives", quantityText: "60 g", quantityGrams: 60),
                RecipeIngredient(name: "Olive oil", quantityText: "2 tbsp", quantityGrams: 30),
            ]
        )
        salad.caloriesPerServing = 380
        salad.proteinPerServing = 14
        salad.carbsPerServing = 16
        salad.fatPerServing = 30
        salad.cookCount = 2

        let pierogi = Recipe(
            title: "Pierogi ruskie",
            summary: "A classic, made at home.",
            servings: 4,
            prepMinutes: 60,
            cookMinutes: 15,
            instructions: [
                "Knead the dough from flour, water and egg.",
                "Boil the potatoes and blend with cottage cheese.",
                "Form pierogi and drop into boiling water.",
                "Cook 5 minutes after they float.",
            ],
            ingredients: [
                RecipeIngredient(name: "Wheat flour", quantityText: "500 g", quantityGrams: 500),
                RecipeIngredient(name: "Potatoes", quantityText: "400 g", quantityGrams: 400),
                RecipeIngredient(name: "Cottage cheese", quantityText: "250 g", quantityGrams: 250),
                RecipeIngredient(name: "Onion", quantityText: "1 piece", quantityGrams: 100),
                RecipeIngredient(name: "Egg", quantityText: "1 piece", quantityGrams: 50),
            ]
        )
        pierogi.caloriesPerServing = 450
        pierogi.proteinPerServing = 14
        pierogi.carbsPerServing = 76
        pierogi.fatPerServing = 6
        pierogi.cookCount = 12
        pierogi.rating = 5.0
        pierogi.isFavorite = true

        [buddha, pancakes, salad, pierogi].forEach { context.insert($0) }
    }
}
#endif
