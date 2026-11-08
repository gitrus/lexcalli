import Foundation
import Testing

@testable import LexcalliCore

struct MixedPracticeRunTests {
    let note = Note(term: "λέξη", meaning: "word")
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func writingRun() throws -> PracticeRun {
        let session = PracticeSession(deckID: UUID(), mode: .mixed, openedAt: now)
        let queued = Card.ID(noteID: note.id, direction: .forward)
        let prompt = try #require(WritingExercise().prompt(for: note))
        return try PracticeRun(session: session, items: [PracticeItem(card: queued, prompt: .writing(prompt))])
    }

    @Test func duplicateConfirmationAndLostAcknowledgementRetainEvent() throws {
        var run = try writingRun()
        let submitted = run.answerExercise(.writing(" λεξη "), at: now)
        let first = try #require(submitted)
        let retry = run.answerExercise(.writing("different"), at: now.addingTimeInterval(50))
        #expect(retry == first)
        #expect(first.attempt.cardID.direction == .reverse)
        #expect(run.pending == .exercise(first))
        #expect(run.answer(.good, at: now) == nil)
        let continued = run.continueAfterFeedback()
        #expect(!continued)
        #expect(run.answeredCount == 0 && run.feedback == nil)
    }

    @Test func lastFeedbackRemainsUntilContinueAndSavedCountsAreAccurate() throws {
        var run = try writingRun()
        let frozen = run.currentPrompt
        let submitted = run.answerExercise(.writing("λεξη"), at: now)
        let event = try #require(submitted)
        let wrongKey = run.acknowledge(UUID())
        let accepted = run.acknowledge(event.id)
        let duplicate = run.acknowledge(event.id)
        #expect(!wrongKey && accepted && !duplicate)
        #expect(run.currentPrompt == frozen)
        #expect(run.feedback != nil && !run.isComplete)
        #expect(run.position == 0)  // The last prompt still displays as 1 of 1 during feedback.
        #expect(run.answeredCount == 1 && run.exercisesCompleted == 1 && run.flashcardsReviewed == 0)
        #expect(run.answerExercise(.writing("second"), at: now) == nil)
        let continued = run.continueAfterFeedback()
        #expect(continued)
        #expect(run.isComplete && run.feedback == nil && run.position == 1)
        let duplicateContinue = run.continueAfterFeedback()
        #expect(!duplicateContinue)
        #expect(run.answeredCount == 1)
    }

    @Test func mismatchedItemsAndModeFailWithoutCrashing() throws {
        let session = PracticeSession(deckID: UUID(), openedAt: now)
        let prompt = try #require(WritingExercise().prompt(for: note))
        let card = Card.ID(noteID: note.id, direction: .forward)
        #expect(throws: PracticeRunError.self) {
            try PracticeRun(session: session, items: [PracticeItem(card: card, prompt: .writing(prompt))])
        }
        let foreign = Card.ID(noteID: UUID(), direction: .reverse)
        #expect(throws: PracticeRunError.self) {
            try PracticeRun(session: session, items: [PracticeItem(card: card, prompt: .flashcard(foreign))])
        }
    }

    @Test func invalidResponseDoesNotCreatePendingEvent() throws {
        var run = try writingRun()
        #expect(run.answerExercise(.writing(" \n"), at: now) == nil)
        #expect(run.answerExercise(.pickOne(UUID()), at: now) == nil)
        #expect(run.pending == nil)
    }

    @Test func mixedFlashcardAdvancesImmediatelyAndCountsSeparately() throws {
        let session = PracticeSession(deckID: UUID(), mode: .mixed, openedAt: now)
        let card = Card.ID(noteID: note.id, direction: .forward)
        var run = PracticeRun(session: session, queue: [card])
        let submitted = run.answer(.good, at: now)
        let event = try #require(submitted)
        let accepted = run.acknowledge(event.id)
        #expect(accepted)
        #expect(run.isComplete && run.feedback == nil)
        #expect(run.flashcardsReviewed == 1 && run.exercisesCompleted == 0 && run.answeredCount == 1)
    }

    @Test func choiceFeedbackPreservesSelectionAndCorrectIdentity() throws {
        let session = PracticeSession(deckID: UUID(), mode: .mixed, openedAt: now)
        let card = Card.ID(noteID: note.id, direction: .forward)
        let other = Note(term: "tree", meaning: "δέντρο")
        var random = PickOneExerciseTests.Seeded()
        let exercise = try #require(PickOneExercise(optionCount: 2))
        let prompt = try #require(exercise.prompt(for: card, in: [note, other], using: &random))
        var run = try PracticeRun(session: session, items: [PracticeItem(card: card, prompt: .pickOne(prompt))])
        let submitted = run.answerExercise(.pickOne(other.id), at: now)
        let event = try #require(submitted)
        #expect(run.feedback == nil)
        run.acknowledge(event.id)
        #expect(run.feedback == .pickOne(selected: other.id, correct: note.id))
        #expect(run.currentPrompt == .pickOne(prompt))
    }

    @Test func everyModeBuildsItsRunThroughThePlan() throws {
        let card = Card.ID(noteID: note.id, direction: .forward)
        func opened(_ mode: PracticeMode) -> OpenedSession {
            OpenedSession(
                session: PracticeSession(deckID: UUID(), mode: mode, openedAt: now), queue: [card],
                recovered: ProjectionReport())
        }
        var random = PickOneExerciseTests.Seeded()

        let flashcards = try PracticeRun(
            opened: opened(.flashcards), notes: [note], engine: ExerciseEnginesByMode.standard.engine(for: .flashcards),
            using: &random)
        #expect(flashcards.items == [PracticeItem(card: card, prompt: .flashcard(card))])

        let writingOnly = ExerciseEnginesByMode([.mixed: [WritingExercise()]])
        let mixed = try PracticeRun(
            opened: opened(.mixed), notes: [note], engine: writingOnly.engine(for: .mixed), using: &random)
        let prompt = try #require(WritingExercise().prompt(for: note))
        #expect(mixed.items == [PracticeItem(card: card, prompt: .writing(prompt))])

        // A plan cannot smuggle exercise prompts into a Flashcards session.
        let misconfigured = ExerciseEnginesByMode([.flashcards: [WritingExercise()]])
        #expect(throws: PracticeRunError.invalidPrompt) {
            try PracticeRun(
                opened: opened(.flashcards), notes: [note], engine: misconfigured.engine(for: .flashcards),
                using: &random)
        }
    }
}
