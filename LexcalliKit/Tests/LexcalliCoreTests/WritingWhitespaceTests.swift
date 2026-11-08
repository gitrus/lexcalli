import Foundation
import Testing

@testable import LexcalliCore

struct WritingWhitespaceTests {
    @Test func surroundingWhitespaceOnBothSidesIsIgnored() {
        let parts = WritingComparison.compare(expected: "\t\n λέξη \u{00A0}", response: " \tλέξη\r\n")
        #expect(parts.map(\.expected).joined() == "λέξη")
        #expect(parts.map(\.response).joined() == "λέξη")
        #expect(parts.allSatisfy { $0.kind == .match })
    }

    @Test func internalWhitespaceStillProducesDifferences() {
        for response in ["two  words", "two\twords", "two\nwords"] {
            let parts = WritingComparison.compare(expected: " two words ", response: response)
            #expect(parts.contains { $0.kind == .difference })
            #expect(parts.map(\.response).joined() == response)
        }
    }

    @Test func promptSnapshotRetainsTheUntrimmedNote() throws {
        let note = Note(term: " \tλέξη\n", meaning: "word")
        let prompt = try #require(WritingExercise().prompt(for: note))
        #expect(note.term == " \tλέξη\n")
        #expect(prompt.expectedAnswer == note.term)
        #expect(
            WritingComparison.compare(expected: prompt.expectedAnswer, response: "λέξη").allSatisfy {
                $0.kind == .match
            })
    }
}
