import XCTest

final class MealgramUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cold launch: AuthView is the first surface for an unauthenticated
    /// user; the "Mealgram" wordmark renders at the top of it.
    func testColdLaunchShowsWordmark() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Mealgram"].waitForExistence(timeout: 8))
    }

    /// Tapping the Google button on a freshly installed app surfaces the
    /// "provider not configured" banner because no OAuth client ID is wired.
    func testGoogleSignInTapShowsNotConfiguredBanner() throws {
        let app = XCUIApplication()
        app.launch()

        let googleButton = app.buttons["auth.button.google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 8))
        googleButton.tap()

        let banner = app.otherElements["auth.error.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
    }

    /// Baseline launch performance. First measurement just establishes a
    /// floor — Milestone 4.8 will tighten the budget once we have a
    /// representative production build.
    func testColdLaunchPerformance() throws {
        if #available(iOS 18.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                app.launch()
                app.terminate()
            }
        }
    }
}
