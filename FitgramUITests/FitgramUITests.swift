import XCTest

@MainActor
final class FitgramUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cold launch: AuthView is the first surface for an unauthenticated
    /// user; the "Fitgram" wordmark renders at the top of it.
    func testColdLaunchShowsWordmark() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Fitgram"].waitForExistence(timeout: 8))
    }

    /// The Google sign-in entry point is visible and enabled on a fresh
    /// install. Google OAuth is configured, so tapping it would start the
    /// real web sign-in; that flow is covered manually on device.
    func testGoogleSignInButtonIsAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        // Identifier must match A11yID.Auth.googleButton.
        let googleButton = app.buttons["auth.button.google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 8))
        XCTAssertTrue(googleButton.isEnabled)
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
