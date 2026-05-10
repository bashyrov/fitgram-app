import XCTest

final class MealgramUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cold launch smoke: the welcome screen renders with the "Mealgram"
    /// wordmark. Replaced with proper onboarding flow assertions in
    /// Milestone 1.4.
    func testColdLaunchShowsWordmark() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Mealgram"].waitForExistence(timeout: 5))
    }
}
