import XCTest

@MainActor
final class NavigationUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testEverySettingsPageOpens() {
        let app = XCUIApplication()
        app.launchEnvironment = ["LEXCALLI_LIBRARY": "UITest-\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))

        app.buttons["Menu"].tap()
        app.buttons["Settings"].tap()
        for page in ["Cards", "Appearance", "About"] {
            let row = app.buttons[page]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "No Settings row \(page)")
            row.tap()
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 5), "\(page) page didn't open")
            app.navigationBars[page].buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }

        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    }
}
