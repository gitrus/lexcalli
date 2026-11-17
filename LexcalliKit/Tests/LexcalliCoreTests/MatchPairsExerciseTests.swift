import Foundation
import Testing

@testable import LexcalliCore

struct MatchPairsExerciseTests {
    let notes = [
        Note(term: "dog", meaning: "Hund"), Note(term: "cat", meaning: "Katze"),
        Note(term: "tree", meaning: "Baum"), Note(term: "bird", meaning: "Vogel"),
        Note(term: "house", meaning: "Haus"),
    ]

    func pairing(_ prompt: MatchPairsPrompt) -> [Note.ID: Note.ID] {
        Dictionary(uniqueKeysWithValues: prompt.left.map { ($0.noteID, $0.noteID) })
    }

    @Test func directionsTargetAndDeterminism() throws {
        let exercise = try #require(MatchPairsExercise())
        for direction in CardDirection.allCases {
            let card = Card.ID(noteID: notes[0].id, direction: direction)
            var first = PickOneExerciseTests.Seeded()
            var second = PickOneExerciseTests.Seeded()
            let prompt = try #require(exercise.prompt(for: card, in: notes, using: &first))
            #expect(prompt == exercise.prompt(for: card, in: notes, using: &second))
            #expect(prompt.isWellFormed)
            #expect(prompt.left.count == 4)
            let target = try #require(prompt.left.first { $0.noteID == notes[0].id })
            let partner = try #require(prompt.right.first { $0.noteID == notes[0].id })
            #expect(target.text == (direction == .forward ? "dog" : "Hund"))
            #expect(partner.text == (direction == .forward ? "Hund" : "dog"))
            for item in prompt.left {
                let note = try #require(notes.first { $0.id == item.noteID })
                #expect(item.text == (direction == .forward ? note.term : note.meaning))
            }
        }
    }

    @Test func countsAndInsufficientPool() throws {
        for count in [-1, 0, 1] { #expect(MatchPairsExercise(pairCount: count) == nil) }
        var random = PickOneExerciseTests.Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let two = try #require(MatchPairsExercise(pairCount: 2))
        #expect(two.prompt(for: card, in: Array(notes.prefix(2)), using: &random)?.left.count == 2)
        let four = try #require(MatchPairsExercise())
        #expect(four.prompt(for: card, in: Array(notes.prefix(3)), using: &random) == nil)
        #expect(four.prompt(for: card, in: [Note(term: "x", meaning: "y")] + notes.dropFirst(), using: &random) == nil)
    }

    @Test func bothColumnsStayUnambiguous() throws {
        let target = notes[0]
        let candidates = [
            target, Note(term: "DOG", meaning: "other"), Note(term: "other", meaning: " hund"),
            Note(term: "blank", meaning: "  "), Note(term: " ", meaning: "empty"), notes[1], notes[2],
        ]
        var random = PickOneExerciseTests.Seeded()
        let exercise = try #require(MatchPairsExercise(pairCount: 3))
        let card = Card.ID(noteID: target.id, direction: .forward)
        let prompt = try #require(exercise.prompt(for: card, in: candidates, using: &random))
        #expect(Set(prompt.left.map(\.noteID)) == [target.id, notes[1].id, notes[2].id])
        #expect(try #require(MatchPairsExercise(pairCount: 4)).prompt(for: card, in: candidates, using: &random) == nil)
    }

    @Test func wellFormedRejectsMismatchedColumnsDuplicatesAndMissingTarget() {
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let left = notes.prefix(2).map { MatchPairsItem(noteID: $0.id, text: $0.term) }
        let right = notes.prefix(2).map { MatchPairsItem(noteID: $0.id, text: $0.meaning) }
        #expect(MatchPairsPrompt(cardID: card, left: left, right: right).isWellFormed)
        #expect(!MatchPairsPrompt(cardID: card, left: left, right: Array(right.dropLast())).isWellFormed)
        let foreign = [right[0], MatchPairsItem(noteID: notes[2].id, text: "Baum")]
        #expect(!MatchPairsPrompt(cardID: card, left: left, right: foreign).isWellFormed)
        let duplicate = [right[0], MatchPairsItem(noteID: notes[1].id, text: " HUND ")]
        #expect(!MatchPairsPrompt(cardID: card, left: left, right: duplicate).isWellFormed)
        let other = Card.ID(noteID: notes[3].id, direction: .forward)
        #expect(!MatchPairsPrompt(cardID: other, left: left, right: right).isWellFormed)
        #expect(!MatchPairsPrompt(cardID: card, left: [left[0]], right: [right[0]]).isWellFormed)
    }

    @Test func evaluationNeedsACompleteOneToOnePairing() throws {
        let strategy = try #require(MatchPairsExercise(pairCount: 3))
        var random = PickOneExerciseTests.Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        let generated = try #require(strategy.generate(card: card, notes: notes, using: &random))
        guard case .matchPairs(let prompt) = generated else {
            Issue.record("Expected a Match pairs prompt")
            return
        }
        let correct = pairing(prompt)
        let feedback = try #require(strategy.evaluate(.matchPairs(correct), for: generated))
        guard case .matchPairs(let result) = feedback else {
            Issue.record("Expected Match pairs feedback")
            return
        }
        #expect(result.pairing == correct)
        #expect(result.correct == Set(prompt.left.map(\.noteID)))
        #expect(result.targetCorrect)

        let ids = prompt.left.map(\.noteID)
        let swapped = [ids[0]: ids[1], ids[1]: ids[0], ids[2]: ids[2]]
        guard case .matchPairs(let partial) = strategy.evaluate(.matchPairs(swapped), for: generated) else {
            Issue.record("Expected Match pairs feedback")
            return
        }
        #expect(partial.pairing == swapped)
        #expect(partial.correct == [ids[2]])
        #expect(partial.targetCorrect == (ids[2] == card.noteID))

        let rotated = [ids[0]: ids[1], ids[1]: ids[2], ids[2]: ids[0]]
        guard case .matchPairs(let wrong) = strategy.evaluate(.matchPairs(rotated), for: generated) else {
            Issue.record("Expected Match pairs feedback")
            return
        }
        #expect(wrong.pairing == rotated)
        #expect(wrong.correct.isEmpty)
        #expect(!wrong.targetCorrect)

        let incomplete = [ids[0]: ids[0], ids[1]: ids[1]]
        let reused = [ids[0]: ids[0], ids[1]: ids[0], ids[2]: ids[2]]
        let foreign = [ids[0]: ids[0], ids[1]: ids[1], ids[2]: UUID()]
        for invalid in [incomplete, reused, foreign] {
            #expect(strategy.evaluate(.matchPairs(invalid), for: generated) == nil)
        }
        #expect(strategy.evaluate(.pickOne(ids[0]), for: generated) == nil)
    }

    @Test(arguments: CardDirection.allCases, [true, false])
    func feedbackSeparatesTargetFromCompanions(direction: CardDirection, targetCorrect: Bool) throws {
        let card = Card.ID(noteID: notes[0].id, direction: direction)
        let candidates = notes.prefix(4)
        // Display order must not determine which pair is the target.
        let prompt = MatchPairsPrompt(
            cardID: card,
            left: candidates.reversed().map {
                MatchPairsItem(noteID: $0.id, text: direction == .forward ? $0.term : $0.meaning)
            },
            right: candidates.map {
                MatchPairsItem(noteID: $0.id, text: direction == .forward ? $0.meaning : $0.term)
            })
        var response = pairing(prompt)
        let swapped = targetCorrect ? [notes[1].id, notes[2].id] : [notes[0].id, notes[1].id]
        response[swapped[0]] = swapped[1]
        response[swapped[1]] = swapped[0]
        let attempt = try #require(ExerciseAttempt(prompt: .matchPairs(prompt), response: .matchPairs(response)))
        guard case .matchPairs(let result) = attempt.feedback else {
            Issue.record("Expected Match pairs feedback")
            return
        }
        #expect(result.pairing == response)
        #expect(result.correct == Set(candidates.map(\.id)).subtracting(swapped))
        #expect(result.targetCorrect == targetCorrect)
        #expect(result.correct.count == 2)  // Equal totals can have opposite target results.

        let session = PracticeSession(deckID: UUID(), mode: .mixed, openedAt: .now)
        var run = try PracticeRun(session: session, items: [PracticeItem(card: card, prompt: .matchPairs(prompt))])
        let submitted = run.answerExercise(.matchPairs(response), at: .now)
        let event = try #require(submitted)
        #expect(run.feedback == nil)
        run.acknowledge(event.id)
        #expect(run.feedback == attempt.feedback)
        #expect(run.currentPrompt == .matchPairs(prompt))
    }

    @Test func mixedOffersMatchPairsWhenTheDeckIsLargeEnough() {
        let engine = ExerciseEnginesByMode.standard.engine(for: .mixed)
        let card = Card.ID(noteID: notes[0].id, direction: .forward)
        var random = PickOneExerciseTests.Seeded()
        var kinds = Set<ExerciseKind>()
        for _ in 0..<80 { kinds.insert(engine.generate(card: card, notes: notes, using: &random).kind) }
        #expect(kinds.contains(.matchPairs))
        var small = Set<ExerciseKind>()
        for _ in 0..<40 { small.insert(engine.generate(card: card, notes: [notes[0]], using: &random).kind) }
        #expect(!small.contains(.matchPairs))
    }

    @Test func eventValidationChecksDeckMembershipAndPairing() throws {
        let session = PracticeSession(id: UUID(), deckID: UUID(), mode: .mixed, openedAt: .now)
        var random = PickOneExerciseTests.Seeded()
        let card = Card.ID(noteID: notes[0].id, direction: .reverse)
        let prompt = try #require(MatchPairsExercise()?.prompt(for: card, in: notes, using: &random))
        let deck = Set(notes.map(\.id))
        let event = ExerciseEvent(
            sessionID: session.id, answeredAt: .now, attempt: .matchPairs(prompt: prompt, pairing: pairing(prompt)))
        try event.validate(in: session, noteIDs: deck)
        let companion = try #require(prompt.left.first { $0.noteID != card.noteID }).noteID
        #expect(throws: ReviewStoreError.invalidExercise(event.id)) {
            try event.validate(in: session, noteIDs: deck.subtracting([companion]))
        }
        let ids = prompt.left.map(\.noteID)
        let incomplete = ExerciseEvent(
            sessionID: session.id, answeredAt: .now, attempt: .matchPairs(prompt: prompt, pairing: [ids[0]: ids[0]]))
        #expect(throws: ReviewStoreError.invalidExercise(incomplete.id)) {
            try incomplete.validate(in: session, noteIDs: deck)
        }
        #expect(ExerciseAttempt(prompt: .matchPairs(prompt), response: .matchPairs([ids[0]: ids[0]])) == nil)
    }
}
