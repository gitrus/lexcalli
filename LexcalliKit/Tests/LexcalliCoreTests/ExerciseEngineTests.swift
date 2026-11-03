import Foundation
import Testing

@testable import LexcalliCore

struct ExerciseEngineTests {
    @Test func writingEvaluatesWithoutGradingAndRejectsBlank() throws {
        let note = Note(term: "γειά", meaning: "hello")
        let strategy = WritingExercise()
        var random = SystemRandomNumberGenerator()
        let card = Card.ID(noteID: note.id, direction: .forward)
        let prompt = try #require(strategy.generate(card: card, notes: [note], using: &random))
        #expect(strategy.evaluate(.writing(" \n"), for: prompt) == nil)
        guard case .writing(let parts) = strategy.evaluate(.writing("γεια"), for: prompt) else {
            Issue.record("Expected a comparison")
            return
        }
        #expect(parts.contains { $0.kind == .softDifference })
        #expect(parts.map(\.response).joined() == "γεια")
        #expect(strategy.evaluate(.flashcard(.good), for: prompt) == nil)
    }

    @Test func mixedHasFlashcardFallbackForBlankNote() {
        let note = Note(term: "", meaning: "")
        let card = Card.ID(noteID: note.id, direction: .forward)
        let engine = ExerciseEngine(strategies: [WritingExercise(), PickOneExercise()!])
        var random = SystemRandomNumberGenerator()
        #expect(engine.generate(card: card, notes: [note], using: &random) == .flashcard(card))
    }

    @Test func choiceEvaluationUsesExplicitOptionIdentity() throws {
        let first = Note(term: "one", meaning: "uno")
        let second = Note(term: "two", meaning: "dos")
        let strategy = try #require(PickOneExercise(optionCount: 2))
        var random = SystemRandomNumberGenerator()
        let card = Card.ID(noteID: first.id, direction: .forward)
        let prompt = try #require(strategy.generate(card: card, notes: [first, second], using: &random))
        #expect(strategy.evaluate(.pickOne(second.id), for: prompt) == .pickOne(selected: second.id, correct: first.id))
        #expect(strategy.evaluate(.pickOne(UUID()), for: prompt) == nil)
    }
}
