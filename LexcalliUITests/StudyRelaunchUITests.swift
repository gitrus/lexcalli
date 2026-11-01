import XCTest

/// Seeded study, then termination and relaunch: history and due dates must be unchanged.
@MainActor
final class StudyRelaunchUITests: XCTestCase {
    private let library = "UITest-\(UUID().uuidString)"

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testReviewHistoryAndDueDatesSurviveTermination() throws {
        var app = launch()

        // Notes are due together; one card per note, in a fixed order.
        show("Practice", in: app)
        tap(containing: "German Basics", in: app)
        XCTAssertTrue(app.staticTexts["1 of 4"].waitForExistence(timeout: 10))
        // Before reveal: nothing to rate, and the answer hidden from accessibility.
        XCTAssertFalse(app.buttons["Good"].exists)
        XCTAssertFalse(app.staticTexts["butterfly"].exists)

        app.buttons["Show Answer"].tap()
        XCTAssertTrue(app.buttons["Good"].waitForExistence(timeout: 5))
        attachScreenshot("Revealed card", app)
        app.buttons["Good"].tap()

        XCTAssertTrue(app.staticTexts["2 of 4"].waitForExistence(timeout: 10))
        app.buttons["Show Answer"].tap()
        app.buttons["Easy"].tap()
        XCTAssertTrue(app.staticTexts["3 of 4"].waitForExistence(timeout: 10))

        app.navigationBars.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["Session Complete"].waitForExistence(timeout: 10))
        attachScreenshot("Session complete", app)
        app.buttons["Done"].tap()

        let before = statuses(of: "der Schmetterling", in: app)
        XCTAssertTrue(before.forward.contains("1 review"), before.forward)
        XCTAssertTrue(before.reverse.contains("0 reviews"), before.reverse)
        attachScreenshot("Word after review", app)

        // A real process termination, then a cold launch on the same library.
        app.terminate()
        app = launch()

        let after = statuses(of: "der Schmetterling", in: app)
        XCTAssertEqual(after.forward, before.forward)
        XCTAssertEqual(after.reverse, before.reverse)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["LEXCALLI_LIBRARY": library, "LEXCALLI_SEED_SAMPLES": "1"]
        app.launch()
        return app
    }

    private func show(_ section: String, in app: XCUIApplication) {
        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let row = app.buttons[section]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    private func tap(containing label: String, in app: XCUIApplication) {
        let button = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "No button containing \(label)")
        button.tap()
    }

    private func statuses(of word: String, in app: XCUIApplication) -> (forward: String, reverse: String) {
        show("Decks", in: app)
        tap(containing: "German Basics", in: app)
        tap(containing: word, in: app)
        let forward = app.descendants(matching: .any)["cardStatus.forward"]
        let reverse = app.descendants(matching: .any)["cardStatus.reverse"]
        XCTAssertTrue(forward.waitForExistence(timeout: 10))
        XCTAssertTrue(reverse.waitForExistence(timeout: 10))
        return (forward.label, reverse.label)
    }

    private func attachScreenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
