import Foundation
import Testing

@testable import LexcalliCore

struct ExerciseEngineTests {
    @Test func writingEvaluatesWithoutGradingAndRejectsBlank() throws {
        let note = Note(term: "γειά", meaning: "hello")
        let strategy = WritingExercise()
        var random = PickOneExerciseTests.Seeded()
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
        var random = PickOneExerciseTests.Seeded()
        #expect(engine.generate(card: card, notes: [note], using: &random) == .flashcard(card))
        #expect(engine.evaluate(.flashcard(.good), for: .flashcard(card)) == .flashcard(.good))
    }

    @Test func uniformSelectionUsesDistinctEligibleKindsAndIsReproducible() throws {
        let notes = [Note(term: "one", meaning: "uno"), Note(term: "two", meaning: "dos")]
        let choice = try #require(PickOneExercise(optionCount: 2))
        let engine = ExerciseEngine(strategies: [FlashcardExercise(), WritingExercise(), WritingExercise(), choice])
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        var first = PickOneExerciseTests.Seeded()
        var repeated = PickOneExerciseTests.Seeded()
        var counts: [ExerciseKind: Int] = [:]
        for _ in 0..<900 {
            let prompt = engine.generate(card: card, notes: notes, using: &first)
            #expect(prompt == engine.generate(card: card, notes: notes, using: &repeated))
            counts[prompt.kind, default: 0] += 1
            if prompt.kind == .writing { #expect(prompt.cardID.direction == .reverse) }
        }
        for kind in [ExerciseKind.flashcard, .writing, .pickOne] {
            #expect((200...400).contains(counts[kind, default: 0]))
        }
    }

    @Test func unavailableChoiceLeavesWritingAndFlashcardAndFixtureCanForceWriting() {
        let note = Note(term: "word", meaning: "meaning")
        let card = Card.ID(noteID: note.id, direction: .forward)
        let strategies: [any ExerciseStrategy] = [FlashcardExercise(), WritingExercise(), PickOneExercise()!]
        let engine = ExerciseEngine(strategies: strategies)
        var random = PickOneExerciseTests.Seeded()
        var kinds = Set<ExerciseKind>()
        for _ in 0..<40 { kinds.insert(engine.generate(card: card, notes: [note], using: &random).kind) }
        #expect(kinds == [.writing, .flashcard])
        let fixture = ExerciseEngine(strategies: [WritingExercise()])
        for _ in 0..<10 { #expect(fixture.generate(card: card, notes: [note], using: &random).kind == .writing) }
    }

    @Test func choiceEvaluationUsesExplicitOptionIdentity() throws {
        let first = Note(term: "one", meaning: "uno")
        let second = Note(term: "two", meaning: "dos")
        let strategy = try #require(PickOneExercise(optionCount: 2))
        var random = PickOneExerciseTests.Seeded()
        let card = Card.ID(noteID: first.id, direction: .forward)
        let prompt = try #require(strategy.generate(card: card, notes: [first, second], using: &random))
        #expect(strategy.evaluate(.pickOne(second.id), for: prompt) == .pickOne(selected: second.id, correct: first.id))
        #expect(strategy.evaluate(.pickOne(UUID()), for: prompt) == nil)
    }
}
