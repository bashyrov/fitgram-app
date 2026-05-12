import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class WaterServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    func testLogPersistsEntry() throws {
        let service = WaterService(container: controller.container)
        try service.log(forUser: "u-x", milliliters: 250)
        XCTAssertEqual(service.totalToday(for: "u-x"), 250)
    }

    func testTotalAccumulatesAcrossMultipleEntries() throws {
        let service = WaterService(container: controller.container)
        try service.log(forUser: "u-x", milliliters: 250)
        try service.log(forUser: "u-x", milliliters: 250)
        try service.log(forUser: "u-x", milliliters: 500)
        XCTAssertEqual(service.totalToday(for: "u-x"), 1000)
    }

    func testEntriesScopedPerUser() throws {
        let service = WaterService(container: controller.container)
        try service.log(forUser: "u-a", milliliters: 250)
        try service.log(forUser: "u-b", milliliters: 500)
        XCTAssertEqual(service.totalToday(for: "u-a"), 250)
        XCTAssertEqual(service.totalToday(for: "u-b"), 500)
    }

    func testUndoRemovesNewestEntry() throws {
        let service = WaterService(container: controller.container)
        try service.log(forUser: "u-x", milliliters: 250)
        try service.log(forUser: "u-x", milliliters: 500)
        try service.undoLast(for: "u-x")
        XCTAssertEqual(service.totalToday(for: "u-x"), 250)
    }

    func testUndoWithoutEntriesIsNoOp() throws {
        let service = WaterService(container: controller.container)
        XCTAssertNoThrow(try service.undoLast(for: "u-x"))
        XCTAssertEqual(service.totalToday(for: "u-x"), 0)
    }

    func testYesterdaysEntriesExcluded() async throws {
        // Use a fixed "now" so the day boundary check is deterministic.
        let pinnedNow = Date(timeIntervalSince1970: 1_715_500_000)  // mid-day
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: pinnedNow) ?? pinnedNow

        let context = ModelContext(controller.container)
        context.insert(
            WaterEntry(userRemoteID: "u-x", recordedAt: yesterday, milliliters: 500)
        )
        try context.save()

        let service = WaterService(
            container: controller.container,
            now: { pinnedNow }
        )
        XCTAssertEqual(service.totalToday(for: "u-x"), 0)
    }
}
