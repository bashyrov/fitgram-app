import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class WeightServiceTests: XCTestCase {
    private var controller: PersistenceController!
    private var service: WeightService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        service = WeightService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        service = nil
    }

    func testLogPersistsAndMirrorsOntoUser() throws {
        let context = ModelContext(controller.container)
        let user = User(remoteID: "u-1")
        context.insert(user)
        try context.save()

        try service.log(72.5, for: "u-1")
        let entries = try service.entries(for: "u-1")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg, 72.5)

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == "u-1" }
        )
        let storedUser = try ModelContext(controller.container).fetch(userDescriptor).first
        XCTAssertEqual(storedUser?.weightKg, 72.5)
    }

    func testEntriesAreNewestFirst() throws {
        try service.log(70, for: "u", at: Date(timeIntervalSince1970: 1_700_000_000))
        try service.log(71, for: "u", at: Date(timeIntervalSince1970: 1_700_100_000))
        try service.log(72, for: "u", at: Date(timeIntervalSince1970: 1_700_200_000))
        let entries = try service.entries(for: "u")
        XCTAssertEqual(entries.map(\.weightKg), [72, 71, 70])
    }

    func testSummaryComputesThirtyDayDelta() throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now
        try service.log(80, for: "u", at: oldDate)
        try service.log(76.5, for: "u", at: now)
        let summary = try XCTUnwrap(try service.summary(for: "u"))
        XCTAssertEqual(summary.latest.weightKg, 76.5)
        XCTAssertEqual(summary.thirtyDayDelta, -3.5, accuracy: 0.01)
    }

    func testSummaryNilForEmptyHistory() throws {
        XCTAssertNil(try service.summary(for: "ghost"))
    }

    func testDelete() throws {
        try service.log(70, for: "u")
        let entry = try XCTUnwrap(try service.entries(for: "u").first)
        try service.delete(entry)
        XCTAssertTrue(try service.entries(for: "u").isEmpty)
    }

    func testEntriesSegregatedPerUser() throws {
        try service.log(70, for: "a")
        try service.log(80, for: "b")
        XCTAssertEqual(try service.entries(for: "a").map(\.weightKg), [70])
        XCTAssertEqual(try service.entries(for: "b").map(\.weightKg), [80])
    }
}
