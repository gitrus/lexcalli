import Foundation
import Testing

@testable import LexcalliCore
@testable import LexcalliStore

struct ExerciseStoreTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let deck = Deck(
        name: "Greek", termLanguage: .init(identifier: "el"), meaningLanguage: .init(identifier: "en"),
        notes: [Note(term: "λέξη", meaning: "word"), Note(term: "δέντρο", meaning: "tree")])

    func unlock(_ store: any TestableStore) async throws {
        try await store.save(deck, at: now)
        let session = try await store.openSession(UUID(), deck: deck.id, at: now)
        _ = try await store.record(
            CardReviewEvent(
                sessionID: session.session.id, cardID: session.queue[0], rating: .good, answeredAt: now))
    }

    func writing(_ session: PracticeSession, note: Note, key: UUID = UUID(), response: String = " λεξη ") throws
        -> ExerciseEvent
    {
        let prompt = try #require(WritingExercise().prompt(for: note))
        return ExerciseEvent(
            idempotencyKey: key, sessionID: session.id, answeredAt: now,
            attempt: .writing(prompt: prompt, response: response))
    }

    @Test(arguments: StoreKind.allCases)
    func unlocksFromSavedReviewBeforeProjection(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        var availability = store.hasCardReviews(deck: deck.id).makeAsyncIterator()
        #expect(try await availability.next() == false)
        await #expect(throws: ReviewStoreError.mixedLocked(deck.id)) {
            _ = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        }
        let session = try await store.openSession(UUID(), deck: deck.id, at: now)
        let before = try await store.projection(of: session.queue[0])
        _ = try await store.record(
            CardReviewEvent(
                sessionID: session.session.id, cardID: session.queue[0], rating: .good, answeredAt: now))
        #expect(try await availability.next() == true)
        #expect(try await store.projection(of: session.queue[0]) == before)
    }

    @Test(arguments: StoreKind.allCases)
    func exerciseRetryFeedbackHistoryAndNoScheduling(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        let target = try #require(opened.queue.first)
        let note = try #require(deck.notes.first { $0.id == target.noteID })
        let before = try await store.projection(of: Card.ID(noteID: note.id, direction: .reverse))
        let event = try writing(opened.session, note: note)
        #expect(try await store.record(event) == .recorded)
        #expect(try await store.record(event) == .alreadyRecorded)
        let retry = try await store.openSession(opened.session.id, deck: deck.id, mode: .mixed, at: now)
        #expect(!retry.queue.contains { $0.noteID == note.id })
        _ = try await store.endSession(opened.session.id, at: now)
        #expect(try await store.record(event) == .alreadyRecorded)
        #expect(try await store.exerciseEvents(in: opened.session.id) == [event])
        #expect(try await store.projection(of: event.attempt.cardID) == before)
        #expect(try await store.reviewEvents(of: event.attempt.cardID).isEmpty)
        let conflict = try writing(opened.session, note: note, key: event.id, response: "different")
        await #expect(throws: ReviewStoreError.idempotencyConflict(event.id)) { _ = try await store.record(conflict) }
    }

    @Test(arguments: StoreKind.allCases)
    func rejectsIncompatibleModeAndInvalidAttempt(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        await #expect(throws: ReviewStoreError.incompatibleSession(opened.session.id)) {
            _ = try await store.openSession(opened.session.id, deck: deck.id, at: now)
        }
        let otherDeck = Deck(
            name: "Other", termLanguage: .init(identifier: "en"), meaningLanguage: .init(identifier: "el"))
        try await store.save(otherDeck, at: now)
        await #expect(throws: ReviewStoreError.incompatibleSession(opened.session.id)) {
            _ = try await store.openSession(opened.session.id, deck: otherDeck.id, mode: .mixed, at: now)
        }
        let invalid = try writing(opened.session, note: deck.notes[0], response: " \n")
        await #expect(throws: ReviewStoreError.invalidExercise(invalid.id)) { _ = try await store.record(invalid) }
        let foreign = try writing(opened.session, note: Note(term: "foreign", meaning: "outside"))
        await #expect(throws: ReviewStoreError.cardNotInSessionDeck(foreign.attempt.cardID)) {
            _ = try await store.record(foreign)
        }
        _ = try await store.endSession(opened.session.id, at: now)
        let fresh = try writing(opened.session, note: deck.notes[0])
        await #expect(throws: ReviewStoreError.sessionNotOpen(opened.session.id)) { _ = try await store.record(fresh) }
    }

    @Test(arguments: StoreKind.allCases)
    func canonicallyEquivalentButDifferentPayloadConflicts(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        let first = try writing(opened.session, note: deck.notes[0], response: "ά")
        let different = try writing(opened.session, note: deck.notes[0], key: first.id, response: "α\u{301}")
        _ = try await store.record(first)
        await #expect(throws: ReviewStoreError.idempotencyConflict(first.id)) {
            _ = try await store.record(different)
        }
        let history = try await store.exerciseEvents(in: opened.session.id)
        #expect(history.count == 1)
        #expect(try ExerciseEventPayload(history[0]).encoded() == ExerciseEventPayload(first).encoded())
    }

    @Test(arguments: StoreKind.allCases)
    func choiceSnapshotsAreImmutableAndInvalidOptionsAreAtomic(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        let card = Card.ID(noteID: deck.notes[0].id, direction: .forward)
        let prompt = PickOnePrompt(
            cardID: card, question: deck.notes[0].term, expectedAnswer: deck.notes[0].meaning,
            options: deck.notes.map { PickOneOption(noteID: $0.id, answer: $0.meaning) })
        let event = ExerciseEvent(
            sessionID: opened.session.id, answeredAt: now,
            attempt: .pickOne(prompt: prompt, selected: deck.notes[1].id))
        #expect(try await store.record(event) == .recorded)
        var edited = deck
        edited.notes[0].meaning = "edited"
        try await store.save(edited, at: now)
        #expect(try await store.exerciseEvents(in: opened.session.id) == [event])
        let duplicate = PickOnePrompt(
            cardID: card, question: "prompt", expectedAnswer: "same",
            options: deck.notes.map { PickOneOption(noteID: $0.id, answer: "same") })
        let invalid = ExerciseEvent(
            sessionID: opened.session.id, answeredAt: now,
            attempt: .pickOne(prompt: duplicate, selected: deck.notes[0].id))
        await #expect(throws: ReviewStoreError.invalidExercise(invalid.id)) { _ = try await store.record(invalid) }
        #expect(try await store.exerciseEvents(in: opened.session.id) == [event])
    }

    @Test(arguments: StoreKind.allCases)
    func mixedCardReviewsProjectOnceAndKeysCannotCrossLogs(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        let card = try #require(opened.queue.first)
        let review = CardReviewEvent(sessionID: opened.session.id, cardID: card, rating: .good, answeredAt: now)
        let before = try #require(try await store.projection(of: card))
        #expect(try await store.record(review) == .recorded)
        #expect(try await store.record(review) == .alreadyRecorded)
        let exercise = try writing(opened.session, note: deck.notes[0], key: review.id)
        await #expect(throws: ReviewStoreError.idempotencyConflict(review.id)) { _ = try await store.record(exercise) }
        let savedExercise = try writing(opened.session, note: deck.notes[1])
        _ = try await store.record(savedExercise)
        let collision = CardReviewEvent(
            idempotencyKey: savedExercise.id, sessionID: opened.session.id, cardID: card, rating: .easy, answeredAt: now
        )
        await #expect(throws: ReviewStoreError.idempotencyConflict(savedExercise.id)) {
            _ = try await store.record(collision)
        }
        _ = try await store.endSession(opened.session.id, at: now)
        let projected = try #require(try await store.projection(of: card))
        #expect(projected.scheduling.reps == before.scheduling.reps + 1)
        _ = try await store.endSession(opened.session.id, at: now)
        #expect(try await store.projection(of: card) == projected)
        #expect(try await store.record(review) == .alreadyRecorded)
    }
}
