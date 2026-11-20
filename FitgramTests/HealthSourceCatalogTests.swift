import XCTest

@testable import Fitgram

/// App Review guideline 1.4.1: every health number or tip the app shows
/// must point at a real, linkable source.
final class HealthSourceCatalogTests: XCTestCase {
    func testEverySourceHasAUniqueIdAndAnHTTPSLink() {
        let all = HealthSourceCatalog.all
        XCTAssertGreaterThanOrEqual(all.count, 10)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        for source in all {
            XCTAssertEqual(source.url.scheme, "https", source.id)
            XCTAssertNotNil(source.url.host(), source.id)
            XCTAssertFalse(source.title.isEmpty, source.id)
            XCTAssertTrue((1990...2030).contains(source.year), source.id)
        }
    }

    func testEveryTopicAndFactCategoryIsCited() {
        for topic in HealthTopic.allCases {
            XCTAssertFalse(topic.sources.isEmpty, topic.rawValue)
        }
        for category in NutritionFact.Category.allCases {
            XCTAssertFalse(HealthSourceCatalog.topics(for: category).isEmpty, category.rawValue)
        }
    }

    func testCalorieGoalCitesTheEquationItUses() {
        XCTAssertTrue(HealthTopic.energy.sources.contains(HealthSourceCatalog.mifflin))
    }
}
