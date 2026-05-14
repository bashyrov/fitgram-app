import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class GoalTrackingServiceTests: XCTestCase {
    private var controller: PersistenceController!
    private var weightService: WeightService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        weightService = WeightService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        weightService = nil
    }

    private func seedUser(
        kind: GoalKind = .lose,
        startWeight: Double = 80,
        targetWeight: Double = 72,
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> User {
        let context = ModelContext(controller.container)
        let user = User(remoteID: "u", goalKind: kind)
        user.weightKg = startWeight
        user.goalStartDate = startDate
        user.goalTargetWeightKg = targetWeight
        context.insert(user)
        try context.save()
        return user
    }

    // MARK: - One-per-day behaviour

    func testLogOrUpdateForDayInsertsFirstAndUpdatesSecond() throws {
        _ = try seedUser()
        let cal = Calendar.current
        let today = Date()
        try weightService.logOrUpdateForDay(80.0, for: "u", on: today)
        try weightService.logOrUpdateForDay(79.5, for: "u", on: today)
        let entries = try weightService.entries(for: "u")
        XCTAssertEqual(entries.count, 1, "Second tap should update, not duplicate")
        XCTAssertEqual(entries.first?.weightKg, 79.5)
        XCTAssertEqual(entries.first?.source, .goalTracker)
        // Verify same calendar day too
        let firstRecorded = try XCTUnwrap(entries.first?.recordedAt)
        XCTAssertTrue(cal.isDate(firstRecorded, inSameDayAs: today))
    }

    func testLogOrUpdateForDayKeepsDistinctDaysSeparate() throws {
        _ = try seedUser()
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        try weightService.logOrUpdateForDay(80.0, for: "u", on: yesterday)
        try weightService.logOrUpdateForDay(79.5, for: "u", on: today)
        let entries = try weightService.entries(for: "u")
        XCTAssertEqual(entries.count, 2)
    }

    // MARK: - Snapshot

    func testSnapshotNilWithoutActiveGoal() throws {
        let context = ModelContext(controller.container)
        let user = User(remoteID: "u", goalKind: .maintain)
        context.insert(user)
        try context.save()
        let svc = GoalTrackingService(
            weightService: weightService, container: controller.container
        )
        XCTAssertNil(svc.snapshot(for: "u"))
    }

    func testSnapshotReportsCurrentVsTargetAndProgress() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try seedUser(kind: .lose, startWeight: 80, targetWeight: 70, startDate: start)
        // Goal-relevant entries (after startDate)
        try weightService.log(80, for: "u", at: start, source: .goalTracker)
        try weightService.log(
            75, for: "u",
            at: start.addingTimeInterval(60 * 60 * 24 * 7),
            source: .goalTracker
        )
        let svc = GoalTrackingService(
            weightService: weightService, container: controller.container
        )
        let snap = try XCTUnwrap(svc.snapshot(for: "u"))
        XCTAssertEqual(snap.startWeightKg, 80)
        XCTAssertEqual(snap.currentWeightKg, 75)
        XCTAssertEqual(snap.targetWeightKg, 70)
        // Lose: covered 5kg of 10kg = 50%
        XCTAssertEqual(snap.progress, 0.5, accuracy: 0.0001)
        XCTAssertFalse(snap.isGoalReached)
    }

    func testSnapshotFlagsGoalReachedForLose() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try seedUser(kind: .lose, startWeight: 80, targetWeight: 70, startDate: start)
        try weightService.log(80, for: "u", at: start, source: .goalTracker)
        try weightService.log(
            69, for: "u",
            at: start.addingTimeInterval(60 * 60 * 24 * 14),
            source: .goalTracker
        )
        let svc = GoalTrackingService(
            weightService: weightService, container: controller.container
        )
        let snap = try XCTUnwrap(svc.snapshot(for: "u"))
        XCTAssertTrue(snap.isGoalReached)
    }

    func testSnapshotEntriesAreChronologicalSoSkippedDaysAreGaps() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try seedUser(kind: .lose, startWeight: 80, targetWeight: 70, startDate: start)
        // Day 0, Day 3, Day 7 — no carry-forward on days 1, 2, 4–6
        let d0 = start
        let d3 = start.addingTimeInterval(60 * 60 * 24 * 3)
        let d7 = start.addingTimeInterval(60 * 60 * 24 * 7)
        try weightService.log(80, for: "u", at: d0, source: .goalTracker)
        try weightService.log(78, for: "u", at: d3, source: .goalTracker)
        try weightService.log(76, for: "u", at: d7, source: .goalTracker)
        let svc = GoalTrackingService(
            weightService: weightService, container: controller.container
        )
        let snap = try XCTUnwrap(svc.snapshot(for: "u"))
        XCTAssertEqual(snap.entries.count, 3, "Only the 3 logged days; gaps stay empty")
        XCTAssertEqual(snap.entries.map(\.weightKg), [80, 78, 76])
    }

    func testGoalEntryIsMirroredIntoWeightHistoryWithGoalTrackerSource() throws {
        _ = try seedUser()
        let svc = GoalTrackingService(
            weightService: weightService, container: controller.container
        )
        _ = svc.logTodayWeight(78.4, for: "u")
        let entries = try weightService.entries(for: "u")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg, 78.4)
        XCTAssertEqual(entries.first?.source, .goalTracker)
    }
}
