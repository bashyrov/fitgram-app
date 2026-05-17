import XCTest

@testable import Mealgram

final class NutritionFactCatalogTests: XCTestCase {
    func testCatalogHasAtLeast150Entries() {
        XCTAssertGreaterThanOrEqual(
            NutritionFactCatalog.all.count,
            150,
            "Catalog must ship with at least 150 hand-curated facts."
        )
    }

    func testCatalogIdsAreUnique() {
        let ids = NutritionFactCatalog.all.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "Duplicate fact IDs are not allowed.")
    }

    func testAllFactsHaveNonEmptyTitleAndBody() {
        for fact in NutritionFactCatalog.all {
            XCTAssertFalse(fact.title.isEmpty, "Fact \(fact.id) has empty title")
            XCTAssertFalse(fact.body.isEmpty, "Fact \(fact.id) has empty body")
            XCTAssertFalse(fact.icon.isEmpty, "Fact \(fact.id) has empty icon")
        }
    }

    func testAllCategoriesAreCovered() {
        let covered = Set(NutritionFactCatalog.all.map(\.category))
        for category in NutritionFact.Category.allCases {
            XCTAssertTrue(
                covered.contains(category),
                "Category \(category.rawValue) has no facts"
            )
        }
    }
}

@MainActor
final class DailyFactSelectorTests: XCTestCase {
    private static func makeDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else {
            fatalError("Bad iso \(iso)")
        }
        return date
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else {
            fatalError("UTC missing")
        }
        calendar.timeZone = utc
        return calendar
    }

    func testFactForTodayIsDeterministicForFixedDate() {
        let fixedDate = Self.makeDate("2026-05-17T10:00:00Z")
        let cal = Self.utcCalendar()
        let selectorA = DailyFactSelector(calendar: cal, now: { fixedDate })
        let selectorB = DailyFactSelector(calendar: cal, now: { fixedDate })
        XCTAssertEqual(selectorA.factForToday()?.id, selectorB.factForToday()?.id)
    }

    func testFactChangesAcrossDays() {
        let cal = Self.utcCalendar()
        let selector = DailyFactSelector(calendar: cal, now: { Date() })
        // Same day across many runs returns same fact.
        let day1 = Self.makeDate("2026-05-17T08:00:00Z")
        let day1Later = Self.makeDate("2026-05-17T22:30:00Z")
        XCTAssertEqual(
            selector.fact(for: day1)?.id,
            selector.fact(for: day1Later)?.id,
            "Same calendar day must give same fact"
        )
        // Find at least one neighbouring day that picks a different fact.
        // Hash collisions are possible but extremely rare across the
        // catalog — checking 7 consecutive days makes this practically
        // certain.
        let baseDate = Self.makeDate("2026-05-17T00:00:00Z")
        var seenIds: Set<String> = []
        for offset in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: offset, to: baseDate),
                let fact = selector.fact(for: next) else { continue }
            seenIds.insert(fact.id)
        }
        XCTAssertGreaterThan(seenIds.count, 1, "Daily selector must rotate across the week")
    }

    func testEmptyCatalogReturnsNil() {
        let selector = DailyFactSelector(catalog: [], now: { Date() })
        XCTAssertNil(selector.factForToday())
    }
}
