import SwiftData
import UserNotifications
import XCTest

@testable import Mealgram

@MainActor
final class NotificationCoordinatorTests: XCTestCase {
    private var controller: PersistenceController!
    private var scheduler: SpyScheduler!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        scheduler = SpyScheduler()
    }

    override func tearDown() async throws {
        controller = nil
        scheduler = nil
    }

    func testNotifyAchievementFormatsTitleWithDefinition() async {
        let coordinator = NotificationCoordinator(
            scheduler: scheduler,
            container: controller.container
        )
        let definition = AchievementDefinition(
            id: "streak.7",
            title: "Tydzień!",
            summary: "Siedem dni z rzędu wpisów.",
            symbol: "flame.fill",
            order: 10
        )
        await coordinator.notifyAchievement(definition)

        XCTAssertEqual(scheduler.achievements.count, 1)
        XCTAssertEqual(scheduler.achievements.first?.title, "Nowa odznaka: Tydzień!")
        XCTAssertEqual(scheduler.achievements.first?.body, "Siedem dni z rzędu wpisów.")
    }

    func testRescheduleAllForwardsPlanToScheduler() async {
        let coordinator = NotificationCoordinator(
            scheduler: scheduler,
            container: controller.container
        )
        await coordinator.rescheduleAll(for: "u-x")
        XCTAssertEqual(scheduler.reschedules.count, 1)
    }
}

@MainActor
private final class SpyScheduler: NotificationScheduling {
    var reschedules: [NotificationPlan] = []
    var achievements: [(title: String, body: String)] = []

    func requestAuthorization() async -> Bool { true }
    func currentStatus() async -> UNAuthorizationStatus { .authorized }

    func reschedule(plan: NotificationPlan) async {
        reschedules.append(plan)
    }

    func notifyAchievement(title: String, body: String) async {
        achievements.append((title, body))
    }
}
