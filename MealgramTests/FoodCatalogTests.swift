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
        XCTAssertFalse(bundle.schemaVersion.isEmpty)
        XCTAssertGreaterThan(bundle.items.count, 150)
        // Polish staple from the legacy seed survives the merge.
        XCTAssertTrue(bundle.items.contains(where: { $0.name == "Schabowy z kotleta" }))
    }

    func testSeederCoversAllProductCategories() throws {
        let seeder = FoodSeeder(container: controller.container)
        let bundle = try seeder.load()
        let representedCategories = Set(bundle.items.map(\.category))
        // The "Inne" (.general) bucket is intentionally empty in the seed —
        // anything user-imported lives there. Every other category has at
        // least one canonical row.
        let expected: Set<String> = [
            "homemade", "fast_food", "bakery", "beverage", "dairy",
            "meat", "seafood", "produce", "grain", "snack", "sweets",
        ]
        XCTAssertTrue(
            expected.isSubset(of: representedCategories),
            "Missing categories: \(expected.subtracting(representedCategories))"
        )
    }

    func testSeederHasNoDuplicateIDs() throws {
        let seeder = FoodSeeder(container: controller.container)
        let bundle = try seeder.load()
        let ids = bundle.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate id detected in seed JSON")
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
        // Multiple seeds can carry the same brand — pick the one whose
        // restaurant column is also populated (covers both fields).
        guard
            let bigMac = bundle.items.first(where: {
                $0.name == "Big Mac" && $0.restaurant != nil
            })
        else {
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
        // Search now spans every localized name + brand + restaurant. Assert
        // every result has the term in at least one searchable column.
        XCTAssertTrue(
            state.foods.allSatisfy { food in
                food.allSearchableNames.contains { $0.localizedCaseInsensitiveContains("schabowy") }
                    || (food.brand?.localizedCaseInsensitiveContains("schabowy") ?? false)
                    || (food.restaurantName?.localizedCaseInsensitiveContains("schabowy") ?? false)
            })

        await state.applyQuery("")
        XCTAssertEqual(state.foods.count, initialCount)

        await state.selectCategory(.fastFood)
        XCTAssertTrue(state.foods.allSatisfy { $0.category == .fastFood })
        await state.selectCategory(nil)
        XCTAssertEqual(state.foods.count, initialCount)
    }

    func testRecordPickIncrementsCounterAndStampsTime() throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let catalog = FoodCatalogService(container: controller.container)
        let food = try XCTUnwrap(catalog.all().first)

        try catalog.recordPick(food)
        try catalog.recordPick(food)

        let refreshed = try XCTUnwrap(catalog.all().first { $0.id == food.id })
        XCTAssertEqual(refreshed.pickCount, 2)
        XCTAssertNotNil(refreshed.lastPickedAt)
    }

    func testRecentIsSortedByLastPickedDescending() async throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let catalog = FoodCatalogService(container: controller.container)
        let foods = try catalog.all()
        guard foods.count >= 2 else { return XCTFail("need at least 2 foods seeded") }

        try catalog.recordPick(foods[0])
        try await Task.sleep(nanoseconds: 5_000_000)
        try catalog.recordPick(foods[1])

        let recent = try catalog.recent(limit: 2)
        XCTAssertEqual(recent.first?.id, foods[1].id)
        XCTAssertEqual(recent.last?.id, foods[0].id)
    }

    func testPopularSortsByPickCount() throws {
        try FoodSeeder(container: controller.container).seedIfNeeded()
        let catalog = FoodCatalogService(container: controller.container)
        let foods = try catalog.all()
        guard foods.count >= 2 else { return XCTFail("need at least 2 foods seeded") }
        for _ in 0..<3 { try catalog.recordPick(foods[0]) }
        try catalog.recordPick(foods[1])

        let popular = try catalog.popular(limit: 2)
        XCTAssertEqual(popular.first?.id, foods[0].id)
        XCTAssertEqual(popular.last?.id, foods[1].id)
    }
}
