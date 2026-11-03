import Foundation
import Testing

@testable import LexcalliCore

struct ExerciseEventTests {
    @Test func writingEventKeepsRawResponseAndSnapshots() throws {
        let note = Note(term: "λέξη", meaning: "word")
        let prompt = try #require(WritingExercise().prompt(for: note))
        let attempt = try #require(ExerciseAttempt(prompt: .writing(prompt), response: .writing("  λεξη ")))
        let event = ExerciseEvent(
            sessionID: UUID(), answeredAt: Date(timeIntervalSince1970: 123.4567), attempt: attempt)
        let restored = try JSONDecoder().decode(ExerciseEvent.self, from: JSONEncoder().encode(event))
        #expect(restored == event)
        #expect(restored.attempt == .writing(prompt: prompt, response: "  λεξη "))
        #expect(restored.attempt.cardID.direction == .reverse)
        #expect(restored.version == 1)
    }

    @Test func retryIdentityDistinguishesCanonicallyEquivalentRawText() throws {
        let card = Card.ID(noteID: UUID(), direction: .reverse)
        let prompt = WritingPrompt(cardID: card, question: "word", expectedAnswer: "ά")
        let first = ExerciseEvent(sessionID: UUID(), answeredAt: .now, attempt: .writing(prompt: prompt, response: "ά"))
        let different = ExerciseEvent(
            idempotencyKey: first.id, sessionID: first.sessionID, answeredAt: first.answeredAt,
            attempt: .writing(prompt: prompt, response: "α\u{301}"))
        #expect(try first.encodedPayload() != different.encodedPayload())
        let restored = try JSONDecoder().decode(ExerciseEvent.self, from: JSONEncoder().encode(different))
        #expect(try restored.encodedPayload() == different.encodedPayload())
        guard case .writing(_, let response) = restored.attempt else { return }
        #expect(Array(response.utf8) == Array("α\u{301}".utf8))
    }

    @Test func retryIdentityIncludesOrderedOptionSnapshots() throws {
        let card = Card.ID(noteID: UUID(), direction: .forward)
        let target = PickOneOption(noteID: card.noteID, answer: "ά")
        let other = PickOneOption(noteID: UUID(), answer: "β")
        let prompt = PickOnePrompt(cardID: card, question: "term", expectedAnswer: "ά", options: [target, other])
        let first = ExerciseEvent(
            sessionID: UUID(), answeredAt: .now, attempt: .pickOne(prompt: prompt, selected: other.noteID))
        let changed = PickOnePrompt(
            cardID: card, question: "term", expectedAnswer: "ά",
            options: [PickOneOption(noteID: card.noteID, answer: "α\u{301}"), other])
        let different = ExerciseEvent(
            idempotencyKey: first.id, sessionID: first.sessionID, answeredAt: first.answeredAt,
            attempt: .pickOne(prompt: changed, selected: other.noteID))
        #expect(try first.encodedPayload() != different.encodedPayload())
        let reordered = PickOnePrompt(cardID: card, question: "term", expectedAnswer: "ά", options: [other, target])
        let reorderedEvent = ExerciseEvent(
            idempotencyKey: first.id, sessionID: first.sessionID, answeredAt: first.answeredAt,
            attempt: .pickOne(prompt: reordered, selected: other.noteID))
        #expect(try first.encodedPayload() != reorderedEvent.encodedPayload())
    }

    @Test func rejectsBlankWritingAndForeignSelection() throws {
        let note = Note(term: "word", meaning: "meaning")
        let writing = try #require(WritingExercise().prompt(for: note))
        #expect(ExerciseAttempt(prompt: .writing(writing), response: .writing("  ")) == nil)
        let other = Note(term: "other", meaning: "second")
        let choice = try #require(PickOneExercise(optionCount: 2))
        var random = SystemRandomNumberGenerator()
        let card = Card.ID(noteID: note.id, direction: .forward)
        let prompt = try #require(choice.prompt(for: card, in: [note, other], using: &random))
        #expect(ExerciseAttempt(prompt: .pickOne(prompt), response: .pickOne(UUID())) == nil)
    }
}
