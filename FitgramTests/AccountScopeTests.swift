import SwiftData
import XCTest

@testable import Fitgram

@MainActor
final class AccountScopeTests: XCTestCase {
    override func tearDown() {
        AccountScope.activate(nil)
        super.tearDown()
    }

    func testSecondAccountDoesNotSeeFirstAccountsMealsOrRecipes() throws {
        let container = try PersistenceController.makeInMemory().container
        let meals = MealRepository(container: container)
        let recipes = RecipeRepository(container: container)
        let saver = SwiftDataMealSaver(container: container)
        let today = Calendar.current.startOfDay(for: Date())
        let range = today..<today.addingTimeInterval(86_400)

        AccountScope.activate("apple-user")
        try saver.save(meal: MealEntry(mealType: .lunch, source: .manual))
        try recipes.create(Recipe(title: "Bigos"))

        AccountScope.activate("google-user")
        XCTAssertTrue(meals.meals(in: range).isEmpty)
        XCTAssertTrue(try recipes.all().isEmpty)
        try saver.save(meal: MealEntry(mealType: .dinner, source: .manual))
        XCTAssertEqual(meals.meals(in: range).map(\.mealType), [.dinner])

        AccountScope.activate("apple-user")
        XCTAssertEqual(meals.meals(in: range).map(\.mealType), [.lunch])
        XCTAssertEqual(try recipes.all().map(\.title), ["Bigos"])
    }

    func testLegacyRowsAreClaimedBySignedInAccount() throws {
        let container = try PersistenceController.makeInMemory().container
        let saver = SwiftDataMealSaver(container: container)
        AccountScope.activate(nil)
        try saver.save(meal: MealEntry(mealType: .breakfast, source: .manual))

        AccountScope.activate("apple-user")
        AccountScope.claimUnownedRows(for: "apple-user", in: container)

        let today = Calendar.current.startOfDay(for: Date())
        let found = MealRepository(container: container).meals(in: today..<today.addingTimeInterval(86_400))
        XCTAssertEqual(found.map(\.userRemoteID), ["apple-user"])
    }

    func testSignOutClearsScope() {
        let session = AuthSession()
        session.update(phase: .authenticated(AuthUser(id: "u1", email: nil, displayName: nil, provider: .apple)))
        XCTAssertEqual(AccountScope.currentUserID, "u1")
        session.update(phase: .anonymous)
        XCTAssertEqual(AccountScope.currentUserID, "")
    }

    // MARK: - Switching and deleting accounts

    private func makeDefaults() -> UserDefaults {
        let name = "AccountScopeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testSettingsAndPicksFollowTheAccount() throws {
        let container = try PersistenceController.makeInMemory().container
        let defaults = makeDefaults()
        let context = ModelContext(container)
        let banana = Food(name: "Banan", caloriesKcalPer100g: 89, verified: true)
        context.insert(banana)
        try context.save()
        let catalog = FoodCatalogService(container: container)

        AccountScope.activate("apple-user")
        AccountSwitcher.activate("apple-user", container: container, defaults: defaults)
        defaults.set(7, forKey: "usage.aiWeekly.test")
        defaults.set("pl", forKey: "app.language")
        try catalog.recordPick(banana)

        AccountScope.activate("google-user")
        AccountSwitcher.activate("google-user", container: container, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: "usage.aiWeekly.test"))
        XCTAssertEqual(defaults.string(forKey: "app.language"), "pl", "Device settings stay shared")
        XCTAssertTrue(try catalog.recent(limit: 5).isEmpty)

        AccountScope.activate("apple-user")
        AccountSwitcher.activate("apple-user", container: container, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: "usage.aiWeekly.test"), 7)
        XCTAssertEqual(try catalog.recent(limit: 5).map(\.name), ["Banan"])
    }

    func testCustomFoodsAreVisibleOnlyToTheirAccount() throws {
        let container = try PersistenceController.makeInMemory().container
        let catalog = FoodCatalogService(container: container)
        AccountScope.activate("apple-user")
        try catalog.create(Food(name: "Moja owsianka", caloriesKcalPer100g: 150))

        AccountScope.activate("google-user")
        NotificationCenter.default.post(name: .fitgramAccountDidChange, object: nil)
        XCTAssertFalse(try catalog.all().contains { $0.name == "Moja owsianka" })

        AccountScope.activate("apple-user")
        NotificationCenter.default.post(name: .fitgramAccountDidChange, object: nil)
        XCTAssertTrue(try catalog.all().contains { $0.name == "Moja owsianka" })
    }

    func testDeletingOneAccountKeepsTheOther() throws {
        let container = try PersistenceController.makeInMemory().container
        let defaults = makeDefaults()
        let context = ModelContext(container)
        let saver = SwiftDataMealSaver(container: container)

        AccountScope.activate("apple-user")
        AccountSwitcher.activate("apple-user", container: container, defaults: defaults)
        try saver.save(meal: MealEntry(mealType: .lunch, source: .manual))
        context.insert(User(remoteID: "apple-user", providerKind: .apple))
        context.insert(WaterEntry(userRemoteID: "apple-user", recordedAt: Date(), milliliters: 250))
        defaults.set(3, forKey: "usage.aiWeekly.test")

        AccountScope.activate("google-user")
        AccountSwitcher.activate("google-user", container: container, defaults: defaults)
        try saver.save(meal: MealEntry(mealType: .dinner, source: .manual))
        context.insert(User(remoteID: "google-user", providerKind: .google))
        context.insert(WaterEntry(userRemoteID: "google-user", recordedAt: Date(), milliliters: 500))
        try context.save()

        try AccountSwitcher.deleteAccountData("google-user", container: container, defaults: defaults)

        let check = ModelContext(container)
        XCTAssertEqual(try check.fetch(FetchDescriptor<MealEntry>()).map(\.userRemoteID), ["apple-user"])
        XCTAssertEqual(try check.fetch(FetchDescriptor<User>()).map(\.remoteID), ["apple-user"])
        XCTAssertEqual(try check.fetch(FetchDescriptor<WaterEntry>()).map(\.userRemoteID), ["apple-user"])

        AccountScope.activate("apple-user")
        AccountSwitcher.activate("apple-user", container: container, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: "usage.aiWeekly.test"), 3)
    }
}
