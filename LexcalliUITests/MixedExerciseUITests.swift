import XCTest

@MainActor
final class MixedExerciseUITests: XCTestCase {
    private let library = "UITest-Mixed-\(UUID().uuidString)"
    private let germanID = "5A3B6C1E-0D2F-4E11-9C1A-000000000001"
    private let fixtureID = "6A3B6C1E-0D2F-4E11-9C1A-000000000001"

    override func setUp() async throws { continueAfterFailure = false }

    func testMixedUnlocksAfterSavedReviewAndRelaunch() {
        var app = launch()
        showPractice(app)
        let flashcards = app.buttons["practice.flashcards.\(germanID)"]
        let lockedMixed = app.buttons["practice.mixed.\(germanID)"]
        XCTAssertTrue(flashcards.waitForExistence(timeout: 10))
        XCTAssertTrue(lockedMixed.waitForExistence(timeout: 10))
        XCTAssertTrue(flashcards.isEnabled)
        XCTAssertFalse(lockedMixed.isEnabled)
        XCTAssertLessThan(flashcards.frame.minX, lockedMixed.frame.minX)
        XCTAssertEqual(flashcards.frame.minY, lockedMixed.frame.minY, accuracy: 1)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "German Basics")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Complete a flashcard review to unlock Mixed."].firstMatch.exists)
        screenshot("Practice modes before first review", app)
        flashcards.tap()
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Show Answer"].tap()
        app.buttons["Good"].tap()
        XCTAssertTrue(app.staticTexts["2 of 4"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["Finish"].tap()
        let unlocked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: lockedMixed)
        wait(for: [unlocked], timeout: 10)
        app.terminate()
        app = launch()
        showPractice(app)
        let mixed = app.buttons["practice.mixed.\(germanID)"]
        XCTAssertTrue(mixed.waitForExistence(timeout: 10))
        XCTAssertTrue(mixed.isEnabled)
        mixed.tap()
        XCTAssertTrue(app.staticTexts["1 of 4"].waitForExistence(timeout: 10))
    }

    func testWritingRetryRetainsFinalFeedbackAndSurvivesRelaunch() {
        var app = launch(fixture: "writing", failOnce: true)
        startMixed(app)
        let field = app.descendants(matching: .any)["writing.response"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Greek"].exists)
        XCTAssertFalse(app.staticTexts["Expected"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["writing.expected"].exists)
        XCTAssertFalse(app.staticTexts["πώς σε λένε;"].exists)
        XCTAssertFalse(app.buttons["Show Answer"].exists)
        XCTAssertFalse(app.buttons["Check Answer"].isEnabled)
        field.tap()
        field.typeText("  wrong answer ")
        XCTAssertEqual(field.value as? String, "  wrong answer ")
        // Keyboard submission uses exactly the same confirmation path as the button.
        field.typeText("\n")
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(field.isEnabled, app.debugDescription)
        XCTAssertEqual(field.value as? String, "  wrong answer ")
        XCTAssertFalse(app.buttons["Menu"].exists)
        XCTAssertFalse(app.buttons["Continue"].exists)
        XCTAssertFalse(app.staticTexts["Expected"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["writing.expected"].exists)
        app.buttons["Try Again"].tap()
        XCTAssertTrue(app.staticTexts["Expected"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Actual"].exists)
        let actual = app.descendants(matching: .any)["writing.actual"].firstMatch
        let expected = app.descendants(matching: .any)["writing.expected"].firstMatch
        XCTAssertTrue(actual.exists)
        XCTAssertTrue(expected.exists)
        XCTAssertEqual(actual.label, "wrong answer")
        XCTAssertEqual(field.value as? String, "  wrong answer ")
        XCTAssertLessThan(actual.frame.minX, app.staticTexts["Actual"].frame.minX)
        XCTAssertLessThan(expected.frame.minX, app.staticTexts["Expected"].frame.minX)
        XCTAssertTrue(app.staticTexts["1 of 1"].exists)
        XCTAssertFalse(app.staticTexts["Session Complete"].exists)
        let differences = app.descendants(matching: .any)["writing.differences"].firstMatch
        XCTAssertFalse(differences.exists)
        screenshot("Writing feedback after lost acknowledgement", app)
        app.buttons["writing.comparisonInfo"].tap()
        XCTAssertTrue(differences.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(differences.label.contains("Different text"), differences.label)
        XCTAssertTrue(differences.label.contains("Entered:"), differences.label)
        XCTAssertTrue(differences.label.contains("Expected:"), differences.label)
        screenshot("Writing comparison information", app)
        closeComparisonInfo(app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Session Complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Exercises completed: 1"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Flashcards reviewed: 0"].exists, app.debugDescription)
        app.buttons["Done"].tap()
        app.terminate()
        app = launch(fixture: "writing")
        startMixed(app)
        // Exercise-only work remains due, and saved history still unlocks Mixed.
        XCTAssertTrue(app.staticTexts["1 of 1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["writing.response"].exists)
        XCTAssertFalse(app.staticTexts["Expected"].exists)
    }

    func testPickOneSelectionIsPrivateUntilConfirmationAndFinishSaves() {
        var app = launch(fixture: "pickOne")
        startMixed(app)
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pick.option."))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(options.count, 4)
        XCTAssertTrue(app.staticTexts["Pick from 4"].exists)
        XCTAssertFalse(app.buttons["Check Answer"].isEnabled)
        for option in options.allElementsBoundByIndex {
            XCTAssertTrue(option.isEnabled)
            XCTAssertGreaterThanOrEqual(option.frame.height, 44)
            XCTAssertFalse((option.value as? String ?? "").contains("Correct"))
        }
        assertNoPickOneAudio(app)
        screenshot("Pick-one neutral options", app)
        app.buttons["tree"].tap()
        XCTAssertEqual(app.buttons["tree"].value as? String, "Selected")
        XCTAssertFalse(app.staticTexts["Correct answer"].exists)
        XCTAssertFalse(app.staticTexts["Your selection"].exists)
        app.buttons["house"].tap()
        XCTAssertEqual(app.buttons["house"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["tree"].value as? String ?? "", "")
        assertNoPickOneAudio(app)
        screenshot("Pick-one selected option", app)
        app.buttons["Check Answer"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        let checked = app.buttons["house"].value as? String ?? ""
        XCTAssertTrue(checked.contains("Correct answer"), checked)
        XCTAssertTrue(checked.contains("Your selection"), checked)
        for option in options.allElementsBoundByIndex {
            XCTAssertFalse(option.isEnabled)
        }
        XCTAssertTrue(app.staticTexts["1 of 4"].exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
        assertLearnedWordAudio(app)
        screenshot("Confirmed Pick-one", app)
        app.navigationBars.buttons["Finish"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
        app.terminate()
        app = launch(fixture: "pickOne")
        startMixed(app)
        XCTAssertTrue(app.staticTexts["1 of 4"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pick.option.")).count, 4)
        XCTAssertFalse(app.staticTexts["Correct answer"].exists)
        assertNoPickOneAudio(app)
    }

    func testPickOneWrongAnswerRetryPreservesSelectionAndFeedback() {
        let app = launch(fixture: "pickOne", failOnce: true)
        startMixed(app)
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pick.option."))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 10))
        app.buttons["tree"].tap()
        app.buttons["Check Answer"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.buttons["tree"].value as? String, "Selected")
        XCTAssertFalse(app.buttons["Continue"].exists)
        assertNoPickOneAudio(app)
        for option in options.allElementsBoundByIndex {
            XCTAssertFalse(option.isEnabled)
            XCTAssertFalse((option.value as? String ?? "").contains("Correct answer"))
        }
        app.buttons["Try Again"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["tree"].value as? String, "Your selection. Not the expected answer")
        XCTAssertEqual(app.buttons["house"].value as? String, "Correct answer")
        for option in options.allElementsBoundByIndex {
            XCTAssertFalse(option.isEnabled)
        }
        assertLearnedWordAudio(app)
        screenshot("Pick-one wrong answer after retry", app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["2 of 4"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Check Answer"].isEnabled)
        assertNoPickOneAudio(app)
        for option in options.allElementsBoundByIndex {
            XCTAssertTrue(option.isEnabled)
            XCTAssertEqual(option.value as? String ?? "", "")
        }
    }

    func testPickOneAtAccessibilitySizeKeepsFeedbackAndContinueReachable() {
        assertPickOneFeedbackIsShownAutomatically(answer: "house", status: "Your selection. Correct answer")
    }

    func testPickOneWrongAnswerAtAccessibilitySizeShowsCorrectFeedback() {
        assertPickOneFeedbackIsShownAutomatically(answer: "tree", status: "Your selection. Not the expected answer")
    }

    func testPickOneReverseAudioAppearsOnlyAfterSavedRetry() {
        let app = launch(fixture: "pickOneReverse", failOnce: true)
        startMixed(app)
        XCTAssertTrue(app.buttons["Haus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["house"].exists)
        assertNoPickOneAudio(app)
        app.buttons["Baum"].tap()
        app.buttons["Check Answer"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10))
        assertNoPickOneAudio(app)
        app.buttons["Try Again"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        assertLearnedWordAudio(app, onQuestion: false)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["2 of 4"].waitForExistence(timeout: 10))
        assertNoPickOneAudio(app)
    }

    func testPickOneReverseAtAccessibilitySizeKeepsAnswerAudioReachable() {
        assertPickOneFeedbackIsShownAutomatically(
            answer: "Haus", status: "Your selection. Correct answer", reverse: true)
    }

    private func assertPickOneFeedbackIsShownAutomatically(answer: String, status: String, reverse: Bool = false) {
        let app = launch(fixture: reverse ? "pickOneReverse" : "pickOne", largeText: true)
        startMixed(app)
        let selected = app.buttons[answer]
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if selected.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(selected.isHittable)
        selected.tap()
        XCTAssertTrue(app.buttons["Check Answer"].isHittable)
        app.buttons["Check Answer"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        let scrollView = app.scrollViews.firstMatch
        let audio = app.buttons[reverse ? "pick.correctAudio" : "pick.questionAudio"]
        XCTAssertTrue(audio.waitForExistence(timeout: 10))
        // No swipe after confirmation: the app must bring the learned word's speaker into view itself.
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: audio)
        wait(for: [visible], timeout: 10)
        assertLearnedWordAudio(app, onQuestion: !reverse)
        XCTAssertTrue(scrollView.frame.contains(audio.frame), "The speaker must be fully visible")
        if reverse {
            XCTAssertTrue(scrollView.frame.contains(app.buttons["Haus"].frame), "Correct answer must be fully visible")
        } else {
            XCTAssertTrue(scrollView.frame.contains(app.staticTexts["Haus"].frame), "Question must be fully visible")
        }
        XCTAssertTrue(app.buttons["Continue"].isHittable)
        XCTAssertFalse(selected.isEnabled)
        XCTAssertEqual(selected.value as? String, status)
        screenshot("Pick-one \(answer) feedback shown automatically at accessibility size", app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["2 of 4"].waitForExistence(timeout: 10))
    }

    private func assertNoPickOneAudio(_ app: XCUIApplication) {
        XCTAssertFalse(app.buttons["pick.correctAudio"].exists)
        XCTAssertFalse(app.buttons["pick.questionAudio"].exists)
    }

    private func assertLearnedWordAudio(_ app: XCUIApplication, onQuestion: Bool = true) {
        let identifier = onQuestion ? "pick.questionAudio" : "pick.correctAudio"
        let audio = app.buttons[identifier]
        let correct = app.buttons[onQuestion ? "house" : "Haus"]
        let container = onQuestion ? app.descendants(matching: .any)["pick.question"].firstMatch : correct
        XCTAssertTrue(audio.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1)
        XCTAssertFalse(app.buttons[onQuestion ? "pick.correctAudio" : "pick.questionAudio"].exists)
        XCTAssertTrue(audio.isEnabled)
        XCTAssertTrue(audio.isHittable)
        XCTAssertEqual(audio.label, onQuestion ? "Listen to question: Haus" : "Listen to correct answer: Haus")
        screenshot("Pick-one audio geometry: \(identifier)", app)
        let geometry = "container \(container.frame), audio \(audio.frame), question \(app.staticTexts["Haus"].frame)"
        XCTAssertTrue(container.frame.contains(audio.frame), geometry)
        XCTAssertGreaterThan(audio.frame.midX, container.frame.midX, geometry)
        XCTAssertGreaterThanOrEqual(audio.frame.width, 44)
        XCTAssertGreaterThanOrEqual(audio.frame.height, 44)
        XCTAssertFalse(app.staticTexts["Your selection"].exists)
        XCTAssertFalse(app.staticTexts["Correct answer"].exists)
        XCTAssertFalse(app.staticTexts["Not the expected answer"].exists)
        audio.tap()
        XCTAssertTrue(app.buttons["Continue"].exists)
        XCTAssertFalse(correct.isEnabled)
        XCTAssertTrue((correct.value as? String ?? "").contains("Correct answer"))
    }

    func testInsufficientChoicesUseFlashcardFallback() {
        let app = launch(fixture: "smallDeck")
        startMixed(app)
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Check Answer"].exists)
        app.buttons["Show Answer"].tap()
        app.buttons["Good"].tap()
        XCTAssertTrue(app.staticTexts["Session Complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Flashcards reviewed: 1"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Exercises completed: 0"].exists, app.debugDescription)
    }

    func testWritingAtAccessibilitySizeKeepsConfirmationReachable() {
        let app = launch(fixture: "writingLatin", largeText: true)
        showPractice(app)
        let flashcards = app.buttons["practice.flashcards.\(fixtureID)"]
        let mixed = app.buttons["practice.mixed.\(fixtureID)"]
        XCTAssertTrue(flashcards.waitForExistence(timeout: 10))
        XCTAssertTrue(flashcards.isHittable)
        for _ in 0..<4 {
            if mixed.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(mixed.isHittable)
        screenshot("Practice modes at accessibility size", app)
        mixed.tap()
        let field = app.descendants(matching: .any)["writing.response"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("a long phrase with several words and punctuation;")
        let check = app.buttons["Check Answer"]
        XCTAssertTrue(check.isHittable)
        check.tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Continue"].isHittable)
        let info = app.buttons["writing.comparisonInfo"]
        for _ in 0..<4 {
            if info.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(info.isHittable)
        screenshot("Writing at accessibility size", app)
        let differences = app.descendants(matching: .any)["writing.differences"].firstMatch
        XCTAssertFalse(differences.exists)
        info.tap()
        XCTAssertTrue(differences.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(differences.label.contains("Case or accent difference"), differences.label)
        XCTAssertTrue(differences.label.contains("LATIN SMALL LETTER A"), differences.label)
        XCTAssertTrue(differences.label.contains("LATIN CAPITAL LETTER A"), differences.label)
        screenshot("Comparison information at accessibility size", app)
        closeComparisonInfo(app)
        XCTAssertTrue(app.buttons["Continue"].isHittable)
    }

    private func closeComparisonInfo(_ app: XCUIApplication) {
        let close = app.buttons["writing.comparisonInfo.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    }

    private func launch(fixture: String? = nil, failOnce: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["LEXCALLI_LIBRARY": library, "LEXCALLI_SEED_SAMPLES": "1"]
        if let fixture { app.launchEnvironment["LEXCALLI_EXERCISE_FIXTURE"] = fixture }
        if failOnce { app.launchEnvironment["LEXCALLI_FAIL_EXERCISE_ACK_ONCE"] = "1" }
        if largeText {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func showPractice(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 10))
        app.buttons["Menu"].tap()
        app.buttons["Practice"].tap()
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 10))
    }

    private func startMixed(_ app: XCUIApplication) {
        showPractice(app)
        let mixed = app.buttons["practice.mixed.\(fixtureID)"]
        XCTAssertTrue(mixed.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if mixed.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(mixed.isHittable)
        mixed.tap()
    }

    private func screenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
