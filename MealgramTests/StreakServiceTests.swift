import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class StreakServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
        return date
    }

    func testFirstLogStartsStreakAtOne() throws {
        var now = Self.date("2026-05-12T08:00:00Z")
        let service = StreakService(container: controller.container, now: { now })

        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-12T20:00:00Z")  // later same day
        let streak = try service.currentStreak(for: "u-1")
        XCTAssertEqual(streak.currentLength, 1)
        XCTAssertEqual(streak.longestLength, 1)
    }

    func testSameDayLogsDoNotIncrement() throws {
        var now = Self.date("2026-05-12T08:00:00Z")
        let service = StreakService(container: controller.container, now: { now })

        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-12T20:00:00Z")
        try service.registerLog(for: "u-1")

        let streak = try service.currentStreak(for: "u-1")
        XCTAssertEqual(streak.currentLength, 1)
    }

    func testConsecutiveDayIncrements() throws {
        var now = Self.date("2026-05-12T08:00:00Z")
        let service = StreakService(container: controller.container, now: { now })

        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-13T08:00:00Z")
        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-14T08:00:00Z")
        try service.registerLog(for: "u-1")

        let streak = try service.currentStreak(for: "u-1")
        XCTAssertEqual(streak.currentLength, 3)
        XCTAssertEqual(streak.longestLength, 3)
    }

    func testGapResetsCurrentButPreservesLongest() throws {
        var now = Self.date("2026-05-10T08:00:00Z")
        let service = StreakService(container: controller.container, now: { now })

        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-11T08:00:00Z")
        try service.registerLog(for: "u-1")
        now = Self.date("2026-05-12T08:00:00Z")
        try service.registerLog(for: "u-1")
        // skip 2026-05-13
        now = Self.date("2026-05-14T08:00:00Z")
        try service.registerLog(for: "u-1")

        let streak = try service.currentStreak(for: "u-1")
        XCTAssertEqual(streak.currentLength, 1)
        XCTAssertEqual(streak.longestLength, 3)
    }

    func testConsumeFreezeReducesAvailable() throws {
        let now = Self.date("2026-05-12T20:00:00Z")
        let yesterday = Self.date("2026-05-11T12:00:00Z")
        let context = ModelContext(controller.container)
        context.insert(
            Streak(
                userRemoteID: "u-1",
                currentLength: 5,
                longestLength: 5,
                lastLoggedDate: yesterday,
                freezesAvailable: 2
            )
        )
        try context.save()

        let service = StreakService(container: controller.container, now: { now })
        XCTAssertTrue(try service.consumeFreeze(for: "u-1"))
        let updated = try service.currentStreak(for: "u-1")
        XCTAssertEqual(updated.freezesAvailable, 1)
        XCTAssertEqual(updated.currentLength, 5)
        XCTAssertNotNil(updated.lastFreezeDate)
    }

    func testConsumeFreezeNoOpWhenNoneAvailable() throws {
        let service = StreakService(container: controller.container)
        _ = try service.currentStreak(for: "u-1")
        XCTAssertFalse(try service.consumeFreeze(for: "u-1"))
    }

    func testSevenDayStreakEarnsFreezeUpToCap() throws {
        var now = Self.date("2026-05-01T08:00:00Z")
        let calendar = Calendar(identifier: .gregorian)
        let service = StreakService(container: controller.container, now: { now }, calendar: calendar)

        for dayOffset in 0..<14 {
            now = calendar.date(byAdding: .day, value: dayOffset, to: Self.date("2026-05-01T08:00:00Z")) ?? now
            try service.registerLog(for: "u-earn")
        }

        let streak = try service.currentStreak(for: "u-earn")
        XCTAssertEqual(streak.currentLength, 14)
        XCTAssertEqual(streak.freezesAvailable, 2)
        XCTAssertEqual(streak.lastFreezeAwardedLength, 14)
    }

    func testFreezeLetsTomorrowLogContinueStreak() throws {
        var now = Self.date("2026-05-12T20:00:00Z")
        let yesterday = Self.date("2026-05-11T12:00:00Z")
        let context = ModelContext(controller.container)
        context.insert(
            Streak(
                userRemoteID: "u-bridge",
                currentLength: 6,
                longestLength: 6,
                lastLoggedDate: yesterday,
                freezesAvailable: 1
            )
        )
        try context.save()

        let service = StreakService(container: controller.container, now: { now })
        XCTAssertTrue(try service.consumeFreeze(for: "u-bridge"))
        now = Self.date("2026-05-13T08:00:00Z")
        try service.registerLog(for: "u-bridge")

        let streak = try service.currentStreak(for: "u-bridge")
        XCTAssertEqual(streak.currentLength, 7)
        XCTAssertEqual(streak.longestLength, 7)
    }

    func testCurrentStreakResetsAfterUnprotectedGap() throws {
        let stale = Self.date("2026-05-10T12:00:00Z")
        let now = Self.date("2026-05-12T08:00:00Z")
        let context = ModelContext(controller.container)
        context.insert(
            Streak(
                userRemoteID: "u-gap",
                currentLength: 4,
                longestLength: 6,
                lastLoggedDate: stale,
                freezesAvailable: 1
            )
        )
        try context.save()

        let service = StreakService(container: controller.container, now: { now })
        let streak = try service.currentStreak(for: "u-gap")
        XCTAssertEqual(streak.currentLength, 0)
        XCTAssertEqual(streak.longestLength, 6)
        XCTAssertNil(streak.lastLoggedDate)
    }
}
