import SwiftData
import UserNotifications
import XCTest

@testable import Mealgram

@MainActor
final class NotificationCoordinatorTests: XCTestCase {
    private var controller: PersistenceController!
    private var scheduler: SpyScheduler!

    override func setUp() async throws {
        UserDefaults.standard.set("pl", forKey: "app.language")
        Bundle.setLanguage("pl")
        controller = try PersistenceController.makeInMemory()
        scheduler = SpyScheduler()
    }

    override func tearDown() async throws {
        controller = nil
        scheduler = nil
        UserDefaults.standard.removeObject(forKey: "app.language")
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
        XCTAssertEqual(scheduler.achievements.first?.title, "Odblokowano: Tydzień!")
        XCTAssertEqual(
            scheduler.achievements.first?.body,
            "Siedem dni z rzędu wpisów. Zobacz odznakę i zachowaj ten rytm."
        )
    }

    func testRescheduleAllForwardsPlanToScheduler() async {
        let coordinator = NotificationCoordinator(
            scheduler: scheduler,
            container: controller.container
        )
        await coordinator.rescheduleAll(for: "u-x")
        XCTAssertEqual(scheduler.reschedules.count, 1)
    }

    func testRescheduleAllSuggestsFreezeWhenStreakIsAtRisk() async throws {
        let yesterday = Self.date("2026-05-11T12:00:00Z")
        let context = ModelContext(controller.container)
        context.insert(
            Streak(
                userRemoteID: "u-freeze",
                currentLength: 8,
                longestLength: 8,
                lastLoggedDate: yesterday,
                freezesAvailable: 1
            )
        )
        try context.save()

        let coordinator = NotificationCoordinator(
            scheduler: scheduler,
            container: controller.container,
            now: { Self.date("2026-05-12T19:00:00Z") }
        )
        await coordinator.rescheduleAll(for: "u-freeze")

        XCTAssertEqual(scheduler.reschedules.count, 1)
        XCTAssertTrue(scheduler.reschedules[0].streakRiskSuggestsFreeze)
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
        return date
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
