import Foundation
import Testing

@testable import LexcalliCore

struct PickOneExerciseTests {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64 = 1
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return state
        }
    }

    let notes = [
        Note(term: "dog", meaning: "Hund"), Note(term: "cat", meaning: "Katze"),
        Note(term: "tree", meaning: "Baum"), Note(term: "bird", meaning: "Vogel"),
        Note(term: "house", meaning: "Haus"),
    ]

    @Test func directionsAndDeterminism() throws {
        let exercise = try #require(PickOneExercise())
        for direction in CardDirection.allCases {
            let card = Card.ID(noteID: notes[0].id, direction: direction)
            var first = Seeded()
            var second = Seeded()
            let prompt = try #require(exercise.prompt(for: card, in: notes, using: &first))
            #expect(prompt == exercise.prompt(for: card, in: notes, using: &second))
            #expect(prompt.question == (direction == .forward ? "dog" : "Hund"))
            #expect(prompt.expectedAnswer == (direction == .forward ? "Hund" : "dog"))
            #expect(prompt.options.count == 4)
            #expect(prompt.options.filter { $0.noteID == notes[0].id }.count == 1)
            #expect(prompt.options.filter { $0.answer == prompt.expectedAnswer }.count == 1)
            #expect(Set(prompt.options.map(\.answer)).count == 4)
        }
    }

    @Test func configurableCountsAndInsufficientPool() throws {
        for count in [-1, 0, 1] { #expect(PickOneExercise(optionCount: count)?.optionCount == nil) }
        var random = Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let two = try #require(PickOneExercise(optionCount: 2))
        #expect(two.prompt(for: card, in: Array(notes.prefix(2)), using: &random)?.options.count == 2)
        for count in [3, 5] {
            let exercise = try #require(PickOneExercise(optionCount: count))
            #expect(exercise.prompt(for: card, in: notes, using: &random)?.options.count == count)
        }
        let four = try #require(PickOneExercise())
        #expect(four.prompt(for: card, in: Array(notes.prefix(3)), using: &random) == nil)
    }

    @Test func excludesDuplicatePromptAndAnswerAndBlank() throws {
        let target = notes[0]
        let candidates = [
            target, Note(term: "DOG", meaning: "other"), Note(term: "other", meaning: "hund"),
            Note(term: "blank", meaning: "  "), notes[1],
        ]
        var random = Seeded()
        let exercise = try #require(PickOneExercise(optionCount: 2))
        let card = Card.ID(noteID: target.id, direction: .forward)
        let prompt = try #require(exercise.prompt(for: card, in: candidates, using: &random))
        #expect(Set(prompt.options.map(\.noteID)) == [target.id, notes[1].id])
        let three = try #require(PickOneExercise(optionCount: 3))
        #expect(three.prompt(for: card, in: candidates, using: &random) == nil)
    }

    @Test func similarityRanksWordCountBeforeLengthAndRelaxes() throws {
        let target = Note(term: "target", meaning: "abcd")
        let closest = Note(term: "close", meaning: "abcde")
        let longer = Note(term: "long", meaning: "abcdefgh")
        let otherWords = Note(term: "two", meaning: "a bc")
        let card = Card.ID(noteID: target.id, direction: .forward)
        var random = Seeded()
        let two = try #require(PickOneExercise(optionCount: 2))
        let preferred = try #require(two.prompt(for: card, in: [target, closest, longer, otherWords], using: &random))
        #expect(preferred.options.contains { $0.noteID == closest.id })
        let three = try #require(PickOneExercise(optionCount: 3))
        let broadened = try #require(three.prompt(for: card, in: [target, closest, otherWords], using: &random))
        #expect(Set(broadened.options.map(\.noteID)) == [target.id, closest.id, otherWords.id])
    }

    @Test func equalPreferencesAreRandomizedWithSeededRandomness() throws {
        let target = Note(term: "target", meaning: "aaaa")
        let left = Note(term: "left", meaning: "bbbb")
        let right = Note(term: "right", meaning: "cccc")
        let card = Card.ID(noteID: target.id, direction: .forward)
        let exercise = try #require(PickOneExercise(optionCount: 2))
        var selected = Set<Note.ID>()
        for seed in 1...64 {
            var random = Seeded(state: UInt64(seed))
            let prompt = try #require(exercise.prompt(for: card, in: [target, left, right], using: &random))
            selected.formUnion(prompt.options.map(\.noteID).filter { $0 != target.id })
        }
        #expect(selected == [left.id, right.id])
    }

    @Test func customStagesComposeInOrderAndMayFilter() throws {
        let first = DistractorStage { candidates, _ in candidates.filter { $0.answer != "Katze" } }
        let second = DistractorStage { candidates, _ in
            candidates.contains { $0.answer == "Katze" } ? [] : Array(candidates.prefix(1))
        }
        let exercise = try #require(PickOneExercise(optionCount: 2, stages: [first, second]))
        var random = Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let prompt = try #require(exercise.prompt(for: card, in: notes, using: &random))
        #expect(!prompt.options.contains { $0.answer == "Katze" })
        let reversed = try #require(PickOneExercise(optionCount: 2, stages: [second, first]))
        #expect(reversed.prompt(for: card, in: notes, using: &random) == nil)
        let drop = DistractorStage { _, _ in [] }
        let empty = try #require(PickOneExercise(optionCount: 2, stages: [drop]))
        #expect(empty.prompt(for: card, in: notes, using: &random) == nil)
    }

    @Test func reverseDirectionDeduplicatesDisplayedAnswers() throws {
        let target = Note(term: "dog", meaning: "Hund")
        let duplicate = Note(term: "DOG", meaning: "anderer Hund")
        let other = Note(term: "cat", meaning: "Katze")
        let card = Card.ID(noteID: target.id, direction: .reverse)
        let exercise = try #require(PickOneExercise(optionCount: 3))
        var random = Seeded()
        #expect(exercise.prompt(for: card, in: [target, duplicate, other], using: &random) == nil)
    }

    @Test func customStagesCannotInjectForeignCandidates() throws {
        let foreign = DistractorCandidate(noteID: UUID(), prompt: "outside", answer: "foreign")
        let inject = DistractorStage { candidates, _ in [foreign] + candidates + candidates }
        let exercise = try #require(PickOneExercise(optionCount: 3, stages: [inject]))
        var random = Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let prompt = try #require(exercise.prompt(for: card, in: notes, using: &random))
        #expect(!prompt.options.contains { $0.noteID == foreign.noteID })
        #expect(Set(prompt.options.map(\.answer)).count == 3)
    }
}
