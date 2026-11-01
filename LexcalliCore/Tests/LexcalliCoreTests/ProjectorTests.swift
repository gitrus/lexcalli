import Foundation
import Testing

@testable import LexcalliCore

struct ProjectorTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let cardID = Card.ID(noteID: UUID(), direction: .forward)
    let projector = Projector()

    /// Reviews over a few weeks, with two on the same day and a lapse.
    var history: [CardReviewEvent] {
        let ratings: [(days: Double, rating: Rating)] = [
            (0, .good), (0.01, .again), (1, .good), (3, .hard), (3.2, .good), (10, .easy), (30, .again), (31, .good),
        ]
        return ratings.map { review in
            CardReviewEvent(
                sessionID: UUID(), cardID: cardID, rating: review.rating,
                answeredAt: start.addingTimeInterval(review.days * 86_400 + 0.000_4))
        }
    }

    var new: CardProjection { CardProjection(cardID: cardID, baseline: .new(due: start)) }

    @Test func newCardHasNoCheckpoint() {
        #expect(new.checkpoint == nil)
        #expect(new.scheduling == .new(due: start))
    }

    @Test func incrementalApplicationEqualsRebuild() throws {
        let events = history
        let rebuilt = try projector.rebuild(cardID: cardID, baseline: .new(due: start), events: events)

        for split in 0...events.count {
            let first = try projector.project(new, events: Array(events.prefix(split)))
            let second = try projector.project(first, events: events.shuffled())
            #expect(second == rebuilt, "split at \(split)")
        }
        #expect(rebuilt.scheduling.reps == events.count)
        #expect(rebuilt.scheduling.lapses >= 1)
        #expect(
            rebuilt.checkpoint
                == ProjectionCheckpoint(position: events[events.count - 1].position, eventCount: events.count))
    }

    @Test func eventIsNeverAppliedTwice() throws {
        let events = history
        let once = try projector.project(new, events: events)
        let again = try projector.project(once, events: events)

        #expect(again == once)
    }

    @Test func detectsEventEarlierThanCheckpoint() throws {
        let events = history
        let projected = try projector.project(new, events: Array(events[1...]))
        // Answered before the checkpoint but delivered later, as import or sync could.
        #expect(throws: ProjectionError.outOfOrder(cardID)) {
            try projector.project(projected, events: events)
        }

        let recalculated = try projector.rebuild(cardID: cardID, baseline: projected.baseline, events: events)
        #expect(recalculated == (try projector.rebuild(cardID: cardID, baseline: .new(due: start), events: events)))
    }

    @Test func detectsMissingEventBeforeCheckpoint() throws {
        let events = history
        let projected = try projector.project(new, events: events)

        #expect(throws: ProjectionError.outOfOrder(cardID)) {
            try projector.project(projected, events: Array(events.dropFirst()))
        }
    }

    @Test func rejectsEventOfAnotherCard() throws {
        let other = CardReviewEvent(
            sessionID: nil, cardID: Card.ID(noteID: cardID.noteID, direction: .reverse), rating: .good,
            answeredAt: start)

        #expect(throws: ProjectionError.foreignEvent(other.idempotencyKey, expected: cardID)) {
            try projector.project(new, events: [other])
        }
    }

    @Test func baselineCoversImportedEvents() throws {
        let events = history
        let imported = Array(events.prefix(5))
        let importedState = try projector.project(new, events: imported).scheduling
        let baseline = SchedulingBaseline(
            scheduling: importedState,
            checkpoint: ProjectionCheckpoint(
                position: imported[imported.count - 1].position, eventCount: imported.count)
        )
        let start = CardProjection(cardID: cardID, baseline: baseline)

        let incremental = try projector.project(start, events: events)
        let rebuilt = try projector.rebuild(cardID: cardID, baseline: baseline, events: events)

        #expect(incremental == rebuilt)
        #expect(incremental.scheduling.reps == events.count)
        #expect(try projector.project(start, events: imported) == start)
    }

    @Test func orderTiesBreakByIdempotencyKey() throws {
        let time = start.addingTimeInterval(60)
        let a = CardReviewEvent(sessionID: nil, cardID: cardID, rating: .again, answeredAt: time)
        let b = CardReviewEvent(sessionID: nil, cardID: cardID, rating: .easy, answeredAt: time)

        #expect(try projector.project(new, events: [a, b]) == (try projector.project(new, events: [b, a])))
    }

    @Test func eventTimesKeepWholeMilliseconds() {
        let event = CardReviewEvent(
            sessionID: nil, cardID: cardID, rating: .good, answeredAt: Date(timeIntervalSince1970: 1.234_56))

        #expect(event.answeredAt == Date(milliseconds: 1_235))
        #expect(event.answeredAt.milliseconds == 1_235)
    }

    @Test func goodMovesNewCardIntoTheFuture() throws {
        let event = CardReviewEvent(sessionID: nil, cardID: cardID, rating: .good, answeredAt: start)
        let projected = try projector.project(new, events: [event])

        #expect(projected.scheduling.state != .new)
        #expect(projected.scheduling.due > start)
        #expect(projected.scheduling.lastReview == start)
    }
}
