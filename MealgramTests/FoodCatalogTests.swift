import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class FoodCatalogTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    // MARK: - Seeder

    func testSeederLoadsBundleFromMainBundle() throws {
        // FoodSeeder defaults to Bundle.main; tests run inside the host app
        // bundle so the resource is reachable. If this throws, the JSON
        // wasn't added to the build phase.
        let seeder = FoodSeeder(container: controller.container)
        let bundle = try seeder.load()
        XCTAssertEqual(bundle.schemaVersion, "1.0.0")
        XCTAssertGreaterThan(bundle.items.count, 20)
        XCTAssertTrue(bundle.items.contains(where: { $0.name == "Schabowy z kotleta" }))
    }

    func testSeederPopulatesEmptyStore() throws {
        let seeder = FoodSeeder(container: controller.container)
        let inserted = try seeder.seedIfNeeded()
        XCTAssertGreaterThan(inserted, 0)
        let foods = try FoodCatalogService(container: controller.container).all()
        XCTAssertEqual(foods.count, inserted)
    }

    func testSeederIsIdempotent() throws {
        let seeder = FoodSeeder(container: controller.container)
        let first = try seeder.seedIfNeeded()
        let second = try seeder.seedIfNeeded()
        XCTAssertGreaterThan(first, 0)
        XCTAssertEqual(second, 0)
    }

    func testSeedItemMapsAllFields() throws {
        let bundle = try FoodSeeder(container: controller.container).load()
        guard let bigMac = bundle.items.first(where: { $0.name == "Big Mac" }) else {
            XCTFail("Big Mac fixture missing")
            return
        }
        let food = bigMac.toFood()
        XCTAssertEqual(food.category, .fastFood)
        XCTAssertEqual(food.brand, "McDonald's")
        XCTAssertEqual(food.restaurantName, "McDonald's")
        XCTAssertGreaterThan(food.caloriesKcalPer100g, 0)
        XCTAssertTrue(food.verified)
    }

    // MARK: - Catalog service

    func testCatalogSearchMatchesByNameOrBrand() throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let service = FoodCatalogService(container: controller.container)
        let byName = try service.search("schabowy")
        XCTAssertFalse(byName.isEmpty)
        XCTAssertTrue(byName.contains(where: { $0.name == "Schabowy z kotleta" }))

        let byBrand = try service.search("McDonald")
        XCTAssertTrue(byBrand.contains(where: { $0.name == "Big Mac" }))

        let blank = try service.search("")
        XCTAssertGreaterThan(blank.count, 1)
    }

    func testCatalogByCategoryFiltersToOneFamily() throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let service = FoodCatalogService(container: controller.container)
        let fastFood = try service.byCategory(.fastFood)
        XCTAssertFalse(fastFood.isEmpty)
        XCTAssertTrue(fastFood.allSatisfy { $0.category == .fastFood })
    }

    // MARK: - QuickDatabaseState

    func testQuickDatabaseStateAppliesQueryAndCategoryFilters() async throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let state = QuickDatabaseState(
            catalog: FoodCatalogService(container: controller.container)
        )
        await state.refresh()
        let initialCount = state.foods.count
        XCTAssertGreaterThan(initialCount, 0)

        await state.applyQuery("schabowy")
        XCTAssertTrue(
            state.foods.allSatisfy { food in
                food.name.localizedCaseInsensitiveContains("schabowy")
                    || (food.brand?.localizedCaseInsensitiveContains("schabowy") ?? false)
            })

        await state.applyQuery("")
        XCTAssertEqual(state.foods.count, initialCount)

        await state.selectCategory(.fastFood)
        XCTAssertTrue(state.foods.allSatisfy { $0.category == .fastFood })
        await state.selectCategory(nil)
        XCTAssertEqual(state.foods.count, initialCount)
    }
}
