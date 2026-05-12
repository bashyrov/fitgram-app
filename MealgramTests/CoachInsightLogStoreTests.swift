import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class CoachInsightLogStoreTests: XCTestCase {
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

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    private func makeDebrief(headline: String, body: String = "x") -> WeeklyDebrief {
        WeeklyDebrief(
            generatedAt: Date(),
            headline: headline,
            stats: [
                .init(kind: .avgCalories, value: "1800 kcal", caption: "średnio")
            ],
            insights: [
                CoachInsight(
                    tone: .celebration, headline: "Brawo!", body: body,
                    actionTitle: nil, actionKind: nil
                )
            ]
        )
    }

    // MARK: - Tests

    func testRecordPersistsWeeklyEntry() {
        let now = Self.date("2026-05-12T12:00:00Z")  // a Tuesday
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )
        store.record(makeDebrief(headline: "Solidny tydzień"), for: "u-x")

        let logs = store.recent(for: "u-x")
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.headline, "Solidny tydzień")
    }

    func testSecondRecordWithinSameWeekUpdatesRather() {
        let monday = Self.date("2026-05-11T08:00:00Z")
        let thursday = Self.date("2026-05-14T20:00:00Z")
        var now = monday
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )

        store.record(makeDebrief(headline: "Mieszany tydzień", body: "v1"), for: "u-x")
        now = thursday
        store.record(makeDebrief(headline: "Solidny tydzień", body: "v2"), for: "u-x")

        let logs = store.recent(for: "u-x")
        XCTAssertEqual(logs.count, 1, "Same week should update in place, not insert")
        XCTAssertEqual(logs.first?.headline, "Solidny tydzień")
        let decoded = store.decodeInsights(logs.first?.insightsJSON ?? "")
        XCTAssertEqual(decoded.first?.body, "v2")
    }

    func testDifferentWeeksProduceSeparateRows() {
        let calendar = Self.utcCalendar()
        let week1 = Self.date("2026-05-11T08:00:00Z")  // Mon
        let week2 = Self.date("2026-05-18T08:00:00Z")  // next Mon
        var now = week1
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: calendar,
            now: { now }
        )

        store.record(makeDebrief(headline: "Tydzień 1"), for: "u-x")
        now = week2
        store.record(makeDebrief(headline: "Tydzień 2"), for: "u-x")

        let logs = store.recent(for: "u-x")
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs.first?.headline, "Tydzień 2")  // newest first
        XCTAssertEqual(logs.last?.headline, "Tydzień 1")
    }

    func testLogsAreSegregatedPerUser() {
        let now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )
        store.record(makeDebrief(headline: "Anna's"), for: "u-a")
        store.record(makeDebrief(headline: "Bartek's"), for: "u-b")

        XCTAssertEqual(store.recent(for: "u-a").map(\.headline), ["Anna's"])
        XCTAssertEqual(store.recent(for: "u-b").map(\.headline), ["Bartek's"])
    }

    func testRecentRespectsLimit() {
        let calendar = Self.utcCalendar()
        var now = Self.date("2026-01-05T12:00:00Z")
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: calendar,
            now: { now }
        )
        for offset in 0..<5 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: offset, to: now) else {
                return XCTFail("calendar math")
            }
            now = date
            store.record(makeDebrief(headline: "W\(offset)"), for: "u-x")
        }
        XCTAssertEqual(store.recent(for: "u-x", limit: 3).count, 3)
    }

    func testDecodeInsightsRoundTrip() {
        let now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachInsightLogStore(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )
        store.record(makeDebrief(headline: "X", body: "Ola pisze tu coś"), for: "u-x")
        let log = store.recent(for: "u-x").first
        let decoded = store.decodeInsights(log?.insightsJSON ?? "")
        XCTAssertEqual(decoded.first?.body, "Ola pisze tu coś")
        XCTAssertEqual(decoded.first?.tone, "celebration")
    }
}
