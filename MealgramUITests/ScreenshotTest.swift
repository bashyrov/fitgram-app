import XCTest

/// Navigation harness for App Store screenshot capture. The test
/// **sleeps between steps** so an external `xcrun simctl io booted
/// screenshot` runner can capture each tab at known offsets. See
/// `scripts/capture-screenshots.sh` for the matching runner.
final class ScreenshotTest: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_captureEveryTab() {
        let app = XCUIApplication()
        app.launch()

        // 0..5s: splash + onboarding-bypass + Today renders.
        sleep(5)
        snap("today")

        tap(label: "Week", in: app)
        sleep(3)
        snap("week")

        tap(label: "Friends", in: app)
        sleep(3)
        snap("friends")

        tap(label: "Profile", in: app)
        sleep(3)
        snap("profile")

        if app.buttons["Settings"].waitForExistence(timeout: 2) {
            app.buttons["Settings"].tap()
            sleep(3)
            snap("settings")
            if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            } else if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }

        tap(label: "Today", in: app)
        sleep(1)
        tap(label: "Add", in: app)
        sleep(3)
        snap("add-meal")

        app.swipeDown(velocity: .fast)
        sleep(1)
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(label: String, in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        if tabBar.buttons[label].waitForExistence(timeout: 3) {
            tabBar.buttons[label].tap()
            return
        }
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 3) {
            button.tap()
        }
    }
}
