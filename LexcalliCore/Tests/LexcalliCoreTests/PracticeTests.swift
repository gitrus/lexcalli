import Foundation
import Testing

@testable import LexcalliCore

struct CardTests {
    @Test func noteHasACardInEachDirection() {
        let note = Note(term: "der Baum", meaning: "tree")

        #expect(
            note.cards.map(\.id) == [
                .init(noteID: note.id, direction: .forward), .init(noteID: note.id, direction: .reverse),
            ])
        #expect(Set(note.cards.map(\.noteID)) == [note.id])
    }

    @Test func cardIdentityIsNoteAndDirection() {
        let noteID = UUID()

        #expect(Card(noteID: noteID, direction: .reverse).id == Card(noteID: noteID, direction: .reverse).id)
        #expect(Card(noteID: noteID, direction: .forward).id != Card(noteID: noteID, direction: .reverse).id)
        #expect(Card.ID(noteID: noteID, direction: .forward) < Card.ID(noteID: noteID, direction: .reverse))
    }
}

struct StudyQueueTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func takesDueCardsEarliestFirst() {
        let notes = (0..<3).map { _ in UUID() }
        let candidates = [
            QueueCandidate(cardID: .init(noteID: notes[0], direction: .forward), due: now.addingTimeInterval(-10)),
            QueueCandidate(cardID: .init(noteID: notes[1], direction: .forward), due: now.addingTimeInterval(-100)),
            QueueCandidate(cardID: .init(noteID: notes[2], direction: .forward), due: now.addingTimeInterval(1)),
        ]

        #expect(StudyQueue.build(from: candidates, now: now) == [candidates[1].cardID, candidates[0].cardID])
    }

    @Test func takesOneCardPerNote() {
        let note = UUID()
        let forward = Card.ID(noteID: note, direction: .forward)
        let reverse = Card.ID(noteID: note, direction: .reverse)

        #expect(
            StudyQueue.build(from: [.init(cardID: reverse, due: now), .init(cardID: forward, due: now)], now: now) == [
                forward
            ]
        )
        #expect(
            StudyQueue.build(
                from: [.init(cardID: forward, due: now), .init(cardID: reverse, due: now.addingTimeInterval(-1))],
                now: now)
                == [reverse]
        )
        // The sibling is studied once the other direction isn't due.
        #expect(
            StudyQueue.build(
                from: [.init(cardID: forward, due: now.addingTimeInterval(86_400)), .init(cardID: reverse, due: now)],
                now: now) == [reverse]
        )
    }

    @Test func emptyWhenNothingIsDue() {
        let candidate = QueueCandidate(
            cardID: .init(noteID: UUID(), direction: .forward), due: now.addingTimeInterval(1))

        #expect(StudyQueue.build(from: [candidate], now: now).isEmpty)
    }
}

struct PracticeSessionTests {
    @Test func opensAndEnds() {
        var session = PracticeSession(deckID: UUID(), openedAt: .now)
        #expect(session.status == .open)

        session.endedAt = .now
        #expect(session.status == .ended)
    }
}

struct PracticeRunTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let queue = (0..<2).map { _ in Card.ID(noteID: UUID(), direction: .forward) }

    var run: PracticeRun { PracticeRun(session: PracticeSession(deckID: UUID(), openedAt: now), queue: queue) }

    @Test func answerCreatesOneEventUntilAcknowledged() throws {
        var run = run
        let firstAnswer = run.answer(.good, at: now)
        let first = try #require(firstAnswer)
        // A duplicate tap or a retry resends the same event.
        let repeatedAnswer = run.answer(.again, at: now.addingTimeInterval(1))
        let repeated = try #require(repeatedAnswer)

        #expect(repeated == first)
        #expect(first.cardID == queue[0])
        #expect(first.sessionID == run.session.id)
        #expect(run.current == queue[0])
    }

    @Test func acknowledgementAdvances() throws {
        var run = run
        let firstAnswer = run.answer(.good, at: now)
        let first = try #require(firstAnswer)

        let advanced = run.acknowledge(first.idempotencyKey)
        #expect(advanced)
        #expect(run.current == queue[1])
        #expect(run.pending == nil)

        let secondAnswer = run.answer(.hard, at: now)
        let second = try #require(secondAnswer)
        #expect(second.idempotencyKey != first.idempotencyKey)
        #expect(second.cardID == queue[1])
    }

    @Test func lateAcknowledgementChangesNothing() throws {
        var run = run
        let firstAnswer = run.answer(.good, at: now)
        let first = try #require(firstAnswer)
        run.acknowledge(first.idempotencyKey)
        _ = run.answer(.easy, at: now)

        let advanced = run.acknowledge(first.idempotencyKey)
        #expect(!advanced)
        #expect(run.answeredCount == 1)
    }

    @Test func completesAfterLastCard() throws {
        var run = run
        for _ in queue {
            let eventAnswer = run.answer(.good, at: now)
            let event = try #require(eventAnswer)
            run.acknowledge(event.idempotencyKey)
        }

        #expect(run.isComplete)
        let extra = run.answer(.good, at: now)
        #expect(extra == nil)
    }
}
