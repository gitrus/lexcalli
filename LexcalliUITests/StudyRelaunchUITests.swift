import XCTest

/// Seeded study, then termination and relaunch: history and due dates must be unchanged.
@MainActor
final class StudyRelaunchUITests: XCTestCase {
    private let library = "UITest-\(UUID().uuidString)"

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testSpeakerPressKeepsCircularTargetAndDoesNotFlipCard() {
        let app = launch()
        show("Practice", in: app)
        // This deck has no recorded audio, so the button exercises the system read-aloud voice.
        tap(containing: "Japanese Nature", in: app)
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 10))
        let speaker = app.buttons["Speak"].firstMatch
        XCTAssertTrue(speaker.waitForExistence(timeout: 10))
        XCTAssertTrue(speaker.isHittable)
        XCTAssertGreaterThanOrEqual(speaker.frame.width, 44)
        XCTAssertEqual(speaker.frame.width, speaker.frame.height, accuracy: 1)
        attachScreenshot("Speaker before press", app)
        // Also marks the hold for a simultaneous simulator screenshot of the pressed platter.
        NSLog("LEXCALLI_SPEAKER_HOLD_BEGIN")
        speaker.press(forDuration: 6)
        XCTAssertTrue(app.buttons["Show Answer"].exists)
        XCTAssertFalse(app.buttons["Good"].exists)
        attachScreenshot("Speaker after press", app)
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
        // Anywhere on the card flips it, not only its text: here, the blank band near its top.
        let card = app.descendants(matching: .any)["flashCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("die Blume"), card.label)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.buttons["Easy"].waitForExistence(timeout: 5))
        // Only the shown side is accessible.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "flashCard").count, 1)
        XCTAssertFalse(card.label.contains("die Blume"), card.label)
        app.buttons["Easy"].tap()
        XCTAssertTrue(app.staticTexts["3 of 4"].waitForExistence(timeout: 10))

        // Finish leaves at once, back to the deck chooser.
        app.navigationBars.buttons["Finish"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))

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

    func testAnsweringLastCardEndsSession() throws {
        let app = launch()
        show("Practice", in: app)
        tap(containing: "Japanese Nature", in: app)

        for position in 1...3 {
            XCTAssertTrue(app.staticTexts["\(position) of 3"].waitForExistence(timeout: 10))
            app.buttons["Show Answer"].tap()
            app.buttons["Good"].tap()
        }

        XCTAssertTrue(app.staticTexts["Session Complete"].waitForExistence(timeout: 10))
        attachScreenshot("Session complete", app)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["3 of 6 cards studied"].waitForExistence(timeout: 10))
        attachScreenshot("Practice decks", app)
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
