import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class DataExportServiceTests: XCTestCase {
    private var controller: PersistenceController!
    private var context: ModelContext!
    private var service: DataExportService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        context = ModelContext(controller.container)
        service = DataExportService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        context = nil
        service = nil
    }

    func testEmptyStoreProducesValidBundle() throws {
        let bundle = try service.snapshot(for: "u-1")
        XCTAssertNil(bundle.user)
        XCTAssertTrue(bundle.meals.isEmpty)
        XCTAssertTrue(bundle.recipes.isEmpty)
        XCTAssertNil(bundle.streak)
        XCTAssertTrue(bundle.achievements.isEmpty)
        XCTAssertEqual(bundle.schemaVersion, "1.0.0")
    }

    func testFullBundleIncludesEverything() throws {
        let user = User(remoteID: "u-42", email: "a@b.pl", displayName: "Anka")
        user.dailyCalorieGoalKcal = 1900
        user.heightCm = 170
        user.weightKg = 68.5
        context.insert(user)

        let meal = MealEntry(
            consumedAt: Date(timeIntervalSince1970: 1_700_000_000),
            mealType: .lunch,
            source: .photoScan,
            portionMultiplier: 1.25,
            items: [
                FoodItem(
                    name: "Schabowy", quantityGrams: 180, caloriesKcal: 420, proteinGrams: 32, carbsGrams: 18,
                    fatGrams: 22)
            ]
        )
        context.insert(meal)

        let recipe = Recipe(title: "Pierogi z kapustą", servings: 4)
        recipe.modifications = ["mniej masła"]
        recipe.cookCount = 3
        context.insert(recipe)

        let streak = Streak(userRemoteID: "u-42", currentLength: 7, longestLength: 12, freezesAvailable: 1)
        context.insert(streak)

        let achievement = Achievement(
            userRemoteID: "u-42",
            kind: "streak.7",
            title: "Tydzień!",
            details: "Świetnie, tak trzymaj!"
        )
        context.insert(achievement)
        try context.save()

        let bundle = try service.snapshot(for: "u-42")
        XCTAssertEqual(bundle.user?.remoteID, "u-42")
        XCTAssertEqual(bundle.user?.heightCm, 170)
        XCTAssertEqual(bundle.meals.count, 1)
        let firstMeal = try XCTUnwrap(bundle.meals.first)
        XCTAssertEqual(firstMeal.items.first?.name, "Schabowy")
        XCTAssertEqual(firstMeal.portionMultiplier, 1.25, accuracy: 0.001)
        XCTAssertEqual(bundle.recipes.first?.title, "Pierogi z kapustą")
        XCTAssertEqual(bundle.recipes.first?.modifications, ["mniej masła"])
        XCTAssertEqual(bundle.streak?.currentLength, 7)
        XCTAssertEqual(bundle.achievements.count, 1)
        XCTAssertEqual(bundle.achievements.first?.kind, "streak.7")
    }

    func testExportWritesFileThatRoundTripsThroughCodable() throws {
        let user = User(remoteID: "u-round", email: nil, displayName: "Round")
        context.insert(user)
        try context.save()

        let url = try service.export(for: "u-round")
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportBundle.self, from: data)
        XCTAssertEqual(decoded.user?.remoteID, "u-round")
        XCTAssertGreaterThan(decoded.appBuild.count, 0)
    }
}
