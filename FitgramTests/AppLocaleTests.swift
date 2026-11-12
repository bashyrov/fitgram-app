import XCTest

@testable import Fitgram

final class AppLocaleTests: XCTestCase {
    private let key = "app.language"
    private var saved: String?

    override func setUp() {
        super.setUp()
        saved = UserDefaults.standard.string(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.set(saved, forKey: key)
        super.tearDown()
    }

    /// Post dates ("wczoraj", "3 dni temu") follow the language chosen in the
    /// app, not the iPhone's language.
    func testRelativeDatesFollowAppLanguage() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        UserDefaults.standard.set("pl", forKey: key)
        XCTAssertEqual(Locale.app.identifier, "pl")
        let polish = yesterday.formatted(.relative(presentation: .named).locale(.app))
        UserDefaults.standard.set("ru", forKey: key)
        let russian = yesterday.formatted(.relative(presentation: .named).locale(.app))
        XCTAssertEqual(polish, "wczoraj")
        XCTAssertEqual(russian, "вчера")
    }
}
