import Foundation
import Testing

@testable import LexcalliCore

struct WritingExerciseTests {
    @Test func writingUsesMeaningAndReverseCard() throws {
        let note = Note(term: "καλημέρα σας", meaning: "good morning")
        let prompt = try #require(WritingExercise().prompt(for: note))
        #expect(prompt.cardID == Card.ID(noteID: note.id, direction: .reverse))
        #expect(prompt.question == "good morning")
        #expect(prompt.expectedAnswer == "καλημέρα σας")
        #expect(WritingExercise().prompt(for: Note(term: " \n", meaning: "hello")) == nil)
        #expect(WritingExercise().prompt(for: Note(term: "hello", meaning: "  ")) == nil)
    }

    @Test func canonicalEquivalenceAndGreekQuestionMarkMatch() {
        let result = WritingComparison.compare(expected: "ά;", response: "α\u{301}\u{37E}")
        #expect(result.allSatisfy { $0.kind == .match })
        #expect(result.map(\.response).joined() == "α\u{301}\u{37E}")
        for (expected, response) in [("τι;", "τι\u{37E}"), ("τι\u{37E}", "τι;")] {
            #expect(WritingComparison.compare(expected: expected, response: response).allSatisfy { $0.kind == .match })
        }
    }

    @Test func caseAndAccentDifferencesAreSoft() {
        let result = WritingComparison.compare(expected: "Άλφα", response: "αλφα")
        #expect(result.map(\.kind) == [.softDifference, .match, .match, .match])
    }

    @Test func accentsAndUnicodeCaseFoldingAreSoft() {
        for expected in ["ά", "α\u{301}"] {
            let result = WritingComparison.compare(expected: expected, response: "α")
            #expect(result.map(\.kind) == [.softDifference])
            #expect(result.map(\.response).joined() == "α")
        }
        // Unicode case folding treats Greek final sigma as the same letter as medial sigma.
        let sigma = WritingComparison.compare(expected: "λόγος", response: "λογοσ")
        #expect(sigma.map(\.kind) == [.match, .softDifference, .match, .match, .softDifference])
    }

    @Test func alignmentPrefersExactMatchToSoftMatch() {
        let parts = WritingComparison.compare(expected: "aA", response: "a")
        #expect(parts.map(\.kind) == [.match, .difference])
        #expect(parts.map(\.response).joined() == "a")
    }

    @Test func substitutionIsShownExplicitly() {
        let parts = WritingComparison.compare(expected: "cat", response: "cut")
        #expect(parts.map(\.kind) == [.match, .difference, .match])
        #expect(parts[1].expected == "a" && parts[1].response == "u")
    }

    @Test func editsPreserveBothTexts() {
        let result = WritingComparison.compare(expected: "a cat", response: "a cut!")
        #expect(result.map(\.expected).joined() == "a cat")
        #expect(result.map(\.response).joined() == "a cut!")
        #expect(result.contains { $0.kind == .difference })
        #expect(result.contains { $0.expected.isEmpty && $0.response == "!" })
        let deletion = WritingComparison.compare(expected: "abc", response: "ac")
        #expect(deletion.contains { $0.expected == "b" && $0.response.isEmpty })
    }

    @Test func responseMustNotBeBlankAndOuterWhitespaceIsIgnored() {
        let exercise = WritingExercise()
        #expect(!exercise.accepts(" \n"))
        #expect(exercise.accepts("  λέξη "))
        let result = WritingComparison.compare(expected: "λέξη", response: "  λέξη ")
        #expect(result.map(\.response).joined() == "λέξη")
        #expect(result.allSatisfy { $0.kind == .match })
    }

}
