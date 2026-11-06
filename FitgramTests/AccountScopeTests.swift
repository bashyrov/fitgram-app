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
}
