import SwiftData
import XCTest

@testable import Fitgram

@MainActor
final class AchievementLevelsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private var engine: AchievementEngine { AchievementEngine(calendar: calendar) }

    private func meal(
        _ iso: String,
        type: MealType = .lunch,
        source: MealSource = .manual,
        items: [FoodItem] = [FoodItem(name: "X", quantityGrams: 100, caloriesKcal: 50)]
    ) -> MealEntry {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: iso) ?? Date(timeIntervalSince1970: 0)
        return MealEntry(consumedAt: date, mealType: type, source: source, items: items)
    }

    func testCatalogIsLargeAndIdsAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertGreaterThanOrEqual(ids.count, 300)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate achievement ids")
    }

    func testTrackLevelMath() throws {
        let track = try XCTUnwrap(AchievementTracks.all.first { $0.slug == "kcal" })
        XCTAssertEqual(track.level(for: 0), 0)
        XCTAssertEqual(track.level(for: 5000), 1)
        XCTAssertEqual(track.level(for: 60000), 3)
        XCTAssertEqual(track.nextThreshold(after: 60000), 100_000)
        XCTAssertNil(track.nextThreshold(after: 5_000_000))
        XCTAssertEqual(AchievementTracks.roman(4), "IV")
        XCTAssertEqual(AchievementTracks.roman(9), "IX")
        XCTAssertEqual(AchievementTracks.roman(11), "XI")
    }

    func testMealMetricsUnlockTrackLevels() {
        let meals = (1...7).map { day in
            meal(String(format: "2026-06-%02dT12:00:00Z", day))
        }
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("lvl.days.1"))
        XCTAssertTrue(unlocks.contains("lvl.days.2"), "7 active days = level II")
        XCTAssertFalse(unlocks.contains("lvl.days.3"))
        XCTAssertTrue(unlocks.contains("lvl.weekend.1"), "6–7 June 2026 is a weekend")
    }

    func testExternalCountersUnlockSocialAndActivityTracks() {
        var inputs = AchievementEngine.Inputs.empty
        inputs.counters = [.friends: 5, .reactionsGiven: 10, .waterLiters: 26, .maxWaterDayMl: 2100, .workouts: 1]
        let unlocks = engine.evaluate(meals: [], streak: nil, alreadyEarned: [], inputs: inputs)
        XCTAssertTrue(unlocks.contains("lvl.friends.3"))
        XCTAssertFalse(unlocks.contains("lvl.friends.4"))
        XCTAssertTrue(unlocks.contains("lvl.cheer.2"))
        XCTAssertTrue(unlocks.contains("lvl.water.2"))
        XCTAssertTrue(unlocks.contains("lvl.workouts.1"))
        XCTAssertTrue(unlocks.contains("special.hydrated_2l"))
        XCTAssertFalse(unlocks.contains("special.hydrated_3l"))
    }

    func testSpecialBadges() {
        let meals = [
            meal("2026-12-24T18:00:00Z", type: .dinner),
            meal("2026-12-25T23:30:00Z", type: .snack, source: .photoScan),
            meal("2027-01-05T06:30:00Z", type: .breakfast),
        ]
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("special.wigilia"))
        XCTAssertTrue(unlocks.contains("special.night_owl"))
        XCTAssertTrue(unlocks.contains("special.early_bird"))
        XCTAssertTrue(unlocks.contains("special.comeback"), "11-day gap then a new entry")
        XCTAssertFalse(unlocks.contains("special.new_year"))
    }

    func testEveryUnlockableIdExistsInCatalog() {
        var inputs = AchievementEngine.Inputs.empty
        inputs.counters = Dictionary(uniqueKeysWithValues: AchievementMetric.allCases.map { ($0, 10_000_000) })
        let unlocks = engine.evaluate(meals: [], streak: nil, alreadyEarned: [], inputs: inputs)
        let catalog = Set(AchievementCatalog.all.map(\.id))
        for id in unlocks {
            XCTAssertTrue(catalog.contains(id), "\(id) unlocks but has no definition")
        }
    }

    func testXPLevels() {
        XCTAssertEqual(AchievementXP.progress(xp: 0).level, 1)
        XCTAssertEqual(AchievementXP.progress(xp: 59).level, 1)
        XCTAssertEqual(AchievementXP.progress(xp: 60).level, 2)
        XCTAssertEqual(AchievementXP.progress(xp: 180).level, 3)
        let progress = AchievementXP.progress(xp: 120)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(
            AchievementXP.total(earnedIDs: ["lvl.kcal.8"]), AchievementXP.total(earnedIDs: ["lvl.kcal.1"]))
    }

    func testCounterStoreFriendsOnlyRatchetsUp() {
        let store = AchievementCounterStore(defaults: UserDefaults(suiteName: "counters-\(UUID())") ?? .standard)
        store.recordAtLeast(4, for: .friends, user: "u")
        store.recordAtLeast(2, for: .friends, user: "u")
        store.increment(.reactionsGiven, user: "u")
        XCTAssertEqual(store.counters(forUser: "u")[.friends], 4)
        XCTAssertEqual(store.counters(forUser: "u")[.reactionsGiven], 1)
        XCTAssertEqual(store.counters(forUser: "other")[.friends], 0)
    }
}
