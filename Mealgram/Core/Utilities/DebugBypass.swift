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
        ProcessInfo.processInfo.arguments.contains("-mealgramDebugBypassAuth")
            || ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_BYPASS_AUTH"] == "1"
    }

    /// Override the initial tab. Values: "today" | "progress" | "profile".
    /// Useful for screenshot scripts.
    static var initialTab: String? {
        ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_TAB"]
    }

    static let fakeAuthUser = AuthUser(
        id: "debug-user-001",
        email: "debug@mealgram.pl",
        displayName: "Anna",
        provider: .apple
    )

    // swiftlint:disable function_body_length
    /// Inserts a fully-onboarded User row + 2 sample meals today + a
    /// streak so every dashboard surface has something to render.
    @MainActor
    static func seed(container: ModelContainer) throws {
        let context = ModelContext(container)
        let remoteID = fakeAuthUser.id

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        if try context.fetch(userDescriptor).first == nil {
            let user = User(
                remoteID: remoteID,
                email: fakeAuthUser.email,
                displayName: fakeAuthUser.displayName,
                providerKind: .apple
            )
            user.onboardingCompletedAt = Date()
            user.goalKind = .lose
            user.activityLevel = .moderate
            user.biologicalSex = .female
            user.heightCm = 168
            user.weightKg = 64.5
            user.dailyCalorieGoalKcal = 1800
            user.proteinGoalGrams = 110
            user.carbsGoalGrams = 200
            user.fatGoalGrams = 60
            context.insert(user)
        }

        let mealCount = try context.fetchCount(FetchDescriptor<MealEntry>())
        if mealCount == 0 {
            let breakfast = MealEntry(
                consumedAt: Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date()) ?? Date(),
                mealType: .breakfast,
                source: .quickDatabase,
                items: [
                    FoodItem(
                        name: "Owsianka na mleku z malinami",
                        quantityGrams: 250,
                        caloriesKcal: 280,
                        proteinGrams: 10,
                        carbsGrams: 45,
                        fatGrams: 6
                    )
                ]
            )
            let lunch = MealEntry(
                consumedAt: Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: Date()) ?? Date(),
                mealType: .lunch,
                source: .photoScan,
                items: [
                    FoodItem(
                        name: "Schabowy z kotleta",
                        quantityGrams: 180,
                        caloriesKcal: 420,
                        proteinGrams: 32,
                        carbsGrams: 18,
                        fatGrams: 22,
                        confidence: 0.92
                    ),
                    FoodItem(
                        name: "Ziemniaki gotowane",
                        quantityGrams: 200,
                        caloriesKcal: 160,
                        proteinGrams: 4,
                        carbsGrams: 36,
                        fatGrams: 0.3,
                        confidence: 0.95
                    ),
                    FoodItem(
                        name: "Surówka z kapusty",
                        quantityGrams: 120,
                        caloriesKcal: 60,
                        proteinGrams: 1.4,
                        carbsGrams: 8,
                        fatGrams: 3,
                        confidence: 0.81
                    ),
                ]
            )
            context.insert(breakfast)
            context.insert(lunch)
        }

        let streakDescriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        if try context.fetch(streakDescriptor).first == nil {
            context.insert(
                Streak(
                    userRemoteID: remoteID,
                    currentLength: 4,
                    longestLength: 12,
                    lastLoggedDate: Date(),
                    freezesAvailable: 1
                )
            )
        }

        // Past 5 days of meals for the Progress chart.
        let calendar = Calendar.current
        for daysBack in 1...5 {
            guard let past = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else { continue }
            let randomKcal = Double(1500 + Int.random(in: -300...400))
            context.insert(
                MealEntry(
                    consumedAt: past,
                    mealType: .lunch,
                    source: .photoScan,
                    items: [
                        FoodItem(
                            name: "Sample lunch",
                            quantityGrams: 350,
                            caloriesKcal: randomKcal,
                            proteinGrams: 30,
                            carbsGrams: 45,
                            fatGrams: 20
                        )
                    ]
                )
            )
        }

        try context.save()
        Logger.persistence.notice("DebugBypass seeded debug fixtures")
    }
    // swiftlint:enable function_body_length
}
#endif
