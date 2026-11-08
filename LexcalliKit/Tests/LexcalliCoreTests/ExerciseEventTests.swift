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
        #expect(event.attempt == .writing(prompt: prompt, response: "  λεξη "))
        #expect(event.attempt.cardID.direction == .reverse)
        #expect(event.answeredAt == Date(milliseconds: 123_457))
        #expect(event.version == 1)
    }

    // Byte-level retry identity is a storage concern: see `ExerciseEventPayloadTests`.

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
