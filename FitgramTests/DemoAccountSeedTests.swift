import SwiftData
import XCTest

@testable import Fitgram

/// Records what the sync engine would upload instead of sending it.
private actor RecordingTransport: CloudSyncTransport {
    private(set) var uploaded: [UploadRecord] = []

    func fetchChanges(owner: String, after cursor: String?, limit: Int) async throws -> [RemoteRecord] { [] }

    func upsert(_ records: [UploadRecord]) async throws {
        uploaded.append(contentsOf: records)
    }
}

/// Builds two weeks of realistic data for the App Review demo account and
/// writes it as SQL for `public.user_records`, using the app's own sync
/// payloads so a sign-in pulls it like any other account.
///
/// Skipped unless `DEMO_SEED_OUT` (pass `TEST_RUNNER_DEMO_SEED_OUT` to
/// xcodebuild) names the output file; `DEMO_SEED_EMAIL` picks the account.
@MainActor
final class DemoAccountSeedTests: XCTestCase {
    private let owner = "demo-account"

    private struct Dish {
        let type: MealType
        let source: MealSource
        let items: [FoodItem]
    }

    func testWriteDemoAccountSQL() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let output = environment["DEMO_SEED_OUT"] else {
            throw XCTSkip("Set TEST_RUNNER_DEMO_SEED_OUT to generate the demo account SQL.")
        }
        let email = environment["DEMO_SEED_EMAIL"] ?? "review@fitgram.space"

        AccountScope.activate(owner)
        defer { AccountScope.activate(nil) }
        let container = try PersistenceController.makeInMemory().container
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        }

        context.insert(makeUser(email: email, start: day(-14, 9)))
        insertMeals(context: context, day: day)
        insertTracking(context: context, day: day)
        insertRecipes(context: context, createdAt: day(-12, 20))
        try context.save()

        let transport = RecordingTransport()
        let directory = FileManager.default.temporaryDirectory.appending(path: "demo-seed-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = CloudSyncService(
            container: container, stateStore: CloudSyncStateStore(directory: directory), makeTransport: { transport })
        await service.sync(owner: owner)
        let records = await transport.uploaded
        XCTAssertGreaterThan(records.count, 50)

        try sql(for: records, email: email).write(toFile: output, atomically: true, encoding: .utf8)
    }

    // MARK: - Data

    private func makeUser(email: String, start: Date) -> User {
        let user = User(remoteID: owner, email: email, displayName: "Anna", providerKind: .email, locale: "en_US")
        user.timeZoneIdentifier = "Europe/Warsaw"
        user.onboardingCompletedAt = start
        user.createdAt = start
        user.birthDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1994, month: 5, day: 12))
        user.biologicalSex = .female
        user.heightCm = 168
        user.weightKg = 70.8
        user.activityLevel = .moderate
        user.goalKind = .lose
        user.goalPaceKgPerWeek = 0.5
        user.goalStartWeightKg = 72.0
        user.goalTargetWeightKg = 65.0
        user.goalStartDate = start
        let input = GoalCalculator.Input(
            heightCm: 168, weightKg: 72.0, age: 32, biologicalSex: .female, activityLevel: .moderate,
            goal: .lose, paceKgPerWeek: 0.5)
        if let targets = GoalCalculator.calculateTargets(from: input) {
            user.dailyCalorieGoalKcal = targets.dailyCalorieGoalKcal
            user.proteinGoalGrams = targets.proteinGoalGrams
            user.carbsGoalGrams = targets.carbsGoalGrams
            user.fatGoalGrams = targets.fatGoalGrams
            user.fiberGoalGrams = targets.fiberGoalGrams
            user.waterGoalMl = targets.waterGoalMl
        }
        return user
    }

    // swiftlint:disable:next function_parameter_count
    private func food(
        _ name: String, _ grams: Double, _ kcal: Double, _ protein: Double, _ carbs: Double, _ fat: Double
    ) -> FoodItem {
        FoodItem(
            name: name, quantityGrams: grams, caloriesKcal: kcal, proteinGrams: protein, carbsGrams: carbs,
            fatGrams: fat)
    }

    private var breakfasts: [Dish] {
        [
            Dish(
                type: .breakfast, source: .recipe,
                items: [food("Oatmeal with berries", 300, 390, 14, 62, 9)]),
            Dish(
                type: .breakfast, source: .quickDatabase,
                items: [
                    food("Scrambled eggs", 150, 230, 16, 2, 17), food("Rye bread", 60, 150, 5, 28, 1),
                    food("Tomato", 100, 18, 1, 4, 0),
                ]),
            Dish(
                type: .breakfast, source: .barcode,
                items: [food("Skyr natural", 150, 95, 17, 6, 0), food("Granola", 40, 180, 4, 26, 6)]),
            Dish(
                type: .breakfast, source: .quickDatabase,
                items: [
                    food("Cottage cheese", 150, 150, 18, 5, 6), food("Wholegrain bread", 60, 140, 6, 25, 2),
                    food("Radishes", 50, 8, 0, 2, 0),
                ]),
        ]
    }

    private var lunches: [Dish] {
        [
            Dish(
                type: .lunch, source: .photoScan,
                items: [
                    food("Grilled chicken breast", 150, 250, 46, 0, 6), food("Rice", 150, 195, 4, 43, 0),
                    food("Steamed broccoli", 120, 42, 3, 8, 0),
                ]),
            Dish(
                type: .lunch, source: .photoScan,
                items: [food("Pierogi ruskie", 250, 520, 15, 75, 17), food("Sour cream", 30, 55, 1, 1, 5)]),
            Dish(
                type: .lunch, source: .recipe,
                items: [food("Tomato soup with rice", 400, 260, 8, 44, 6)]),
            Dish(
                type: .lunch, source: .photoScan,
                items: [
                    food("Salmon fillet", 150, 310, 31, 0, 20), food("Potatoes", 200, 150, 4, 34, 0),
                    food("Cucumber salad", 120, 45, 1, 4, 3),
                ]),
            Dish(
                type: .lunch, source: .voice,
                items: [
                    food("Pork chop (schabowy)", 180, 430, 32, 14, 27), food("Boiled potatoes", 200, 150, 4, 34, 0),
                ]),
        ]
    }

    private var dinners: [Dish] {
        [
            Dish(
                type: .dinner, source: .quickDatabase,
                items: [food("Greek salad", 300, 290, 9, 12, 23), food("Wholegrain bread", 40, 95, 4, 17, 1)]),
            Dish(
                type: .dinner, source: .photoScan,
                items: [food("Chicken wrap", 250, 480, 30, 45, 18)]),
            Dish(
                type: .dinner, source: .quickDatabase,
                items: [food("Tuna sandwich", 180, 360, 24, 36, 12), food("Apple", 180, 94, 0, 25, 0)]),
            Dish(
                type: .dinner, source: .photoScan,
                items: [food("Shakshuka", 300, 340, 19, 18, 21)]),
        ]
    }

    private var snacks: [Dish] {
        [
            Dish(type: .snack, source: .quickDatabase, items: [food("Banana", 120, 107, 1, 27, 0)]),
            Dish(type: .snack, source: .barcode, items: [food("Protein bar", 55, 200, 20, 18, 7)]),
            Dish(type: .snack, source: .quickDatabase, items: [food("Almonds", 30, 175, 6, 6, 15)]),
        ]
    }

    private func insertMeals(context: ModelContext, day: (Int, Int, Int) -> Date) {
        for offset in -13...0 {
            let index = offset + 13
            var plan: [(Dish, Date)] = [(breakfasts[index % breakfasts.count], day(offset, 8, 10 + index % 4 * 10))]
            if offset < 0 {
                plan.append((lunches[index % lunches.count], day(offset, 13, index % 3 * 15)))
                if index % 3 != 1 {
                    plan.append((snacks[index % snacks.count], day(offset, 16, 30)))
                }
                plan.append((dinners[index % dinners.count], day(offset, 19, index % 2 * 20)))
            }
            for (dish, date) in plan {
                let items = dish.items.map {
                    FoodItem(
                        name: $0.name, quantityGrams: $0.quantityGrams, caloriesKcal: $0.caloriesKcal,
                        proteinGrams: $0.proteinGrams, carbsGrams: $0.carbsGrams, fatGrams: $0.fatGrams,
                        confidence: dish.source == .photoScan ? 0.86 : nil)
                }
                let meal = MealEntry(consumedAt: date, mealType: dish.type, source: dish.source, items: items)
                meal.createdAt = date
                if offset == -2 && dish.type == .lunch {
                    meal.rating = 5
                    meal.notes = "Lunch with Kasia"
                }
                context.insert(meal)
            }
        }
    }

    private func insertTracking(context: ModelContext, day: (Int, Int, Int) -> Date) {
        let weights: [Double] = [72.0, 71.8, 71.9, 71.5, 71.4, 71.2, 71.3, 70.9, 70.8]
        for (step, kg) in weights.enumerated() {
            let offset = -14 + step * 14 / (weights.count - 1)
            context.insert(WeightEntry(userRemoteID: owner, recordedAt: day(offset, 7, 30), weightKg: kg))
        }
        for offset in -13...0 {
            let glasses = offset == 0 ? 2 : 6 + (offset + 13) % 3
            for glass in 0..<glasses {
                context.insert(
                    WaterEntry(userRemoteID: owner, recordedAt: day(offset, 8 + glass * 2, 0), milliliters: 250))
            }
        }
        context.insert(
            Streak(
                userRemoteID: owner, currentLength: 14, longestLength: 14, lastLoggedDate: day(0, 8, 0),
                freezesAvailable: 1, lastFreezeAwardedLength: 7))
        let achievements = [
            Achievement(
                userRemoteID: owner, kind: "meal.first", title: "First meal", details: "You logged your first meal.",
                earnedAt: day(-13, 20, 0)),
            Achievement(
                userRemoteID: owner, kind: "scan.first", title: "First scan",
                details: "You logged a meal from a photo.", earnedAt: day(-13, 20, 0)),
            Achievement(
                userRemoteID: owner, kind: "weight.tracked", title: "First weight", details: "You logged your weight.",
                earnedAt: day(-14, 20, 0)),
            Achievement(
                userRemoteID: owner, kind: "recipe.first", title: "First recipe",
                details: "You added your first recipe.", earnedAt: day(-12, 20, 0)),
            Achievement(
                userRemoteID: owner, kind: "streak.7", title: "Week!", details: "Seven days of entries in a row.",
                earnedAt: day(-7, 20, 0)),
            Achievement(
                userRemoteID: owner, kind: "week.consistent", title: "Consistent week",
                details: "You logged every day for a week.", earnedAt: day(-7, 20, 0)),
        ]
        achievements.forEach(context.insert)
    }

    private func insertRecipes(context: ModelContext, createdAt: Date) {
        let oatmeal = Recipe(
            title: "Oatmeal with berries", summary: "Quick breakfast, ready in 10 minutes.", servings: 1,
            prepMinutes: 2, cookMinutes: 8,
            instructions: ["Cook the oats in milk for 5 minutes.", "Top with berries and honey."],
            ingredients: [
                RecipeIngredient(name: "Oat flakes", quantityText: "60 g", quantityGrams: 60),
                RecipeIngredient(name: "Milk 2%", quantityText: "200 ml", quantityGrams: 200),
                RecipeIngredient(name: "Blueberries", quantityText: "80 g", quantityGrams: 80),
                RecipeIngredient(name: "Honey", quantityText: "1 tsp", quantityGrams: 7),
            ])
        oatmeal.caloriesPerServing = 390
        oatmeal.proteinPerServing = 14
        oatmeal.carbsPerServing = 62
        oatmeal.fatPerServing = 9
        oatmeal.cookCount = 4
        oatmeal.isFavorite = true

        let soup = Recipe(
            title: "Tomato soup with rice", summary: "Classic Polish pomidorówka.", servings: 4,
            prepMinutes: 10, cookMinutes: 30,
            instructions: [
                "Simmer the vegetable stock.", "Add passata and season.", "Serve with cooked rice.",
            ],
            ingredients: [
                RecipeIngredient(name: "Vegetable stock", quantityText: "1.2 l", quantityGrams: 1200),
                RecipeIngredient(name: "Tomato passata", quantityText: "500 g", quantityGrams: 500),
                RecipeIngredient(name: "Rice", quantityText: "120 g", quantityGrams: 120),
                RecipeIngredient(name: "Cream 12%", quantityText: "100 ml", quantityGrams: 100),
            ])
        soup.caloriesPerServing = 260
        soup.proteinPerServing = 8
        soup.carbsPerServing = 44
        soup.fatPerServing = 6
        soup.cookCount = 2

        for recipe in [oatmeal, soup] {
            recipe.createdAt = createdAt
            context.insert(recipe)
        }
    }

    // MARK: - SQL

    private func sql(for records: [UploadRecord], email: String) -> String {
        let rows = records.map { record in
            "    ('\(record.kind)', '\(record.id)', $fg$\(record.payload)$fg$)"
        }
        return """
            -- Demo data for the App Review account (\(records.count) records).
            -- Run in the Supabase SQL editor after creating the user \(email).
            -- Replaces that account's synced data; safe to re-run.

            delete from public.user_records
            where user_id = (select id from auth.users where email = '\(email)');

            insert into public.user_records (user_id, kind, id, payload)
            select u.id, v.kind, v.id, v.payload
            from auth.users u
            cross join (values
            \(rows.joined(separator: ",\n"))
            ) as v(kind, id, payload)
            where u.email = '\(email)';

            select kind, count(*) from public.user_records
            where user_id = (select id from auth.users where email = '\(email)')
            group by kind order by kind;

            """
    }
}
