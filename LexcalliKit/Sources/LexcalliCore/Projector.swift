import FSRS
import Foundation

/// Applies card review events through FSRS-6. Pure: applying from a checkpoint equals rebuilding.
/// The only file using swift-fsrs types; `FSRS::` tells them apart from this module's.
public struct Projector: Sendable {
    private let scheduler: FSRS::FSRS

    public init(parameters: FSRSParameters = SchedulerDefaults.parameters) {
        scheduler = FSRS::FSRS(parameters: parameters)
    }

    /// Applies events after the checkpoint; throws `.outOfOrder` if earlier history changed, then `rebuild`.
    public func project(_ projection: CardProjection, events: [CardReviewEvent]) throws(ProjectionError)
        -> CardProjection
    {
        let history = try sorted(events, of: projection.cardID)
        var applied = 0
        if let checkpoint = projection.checkpoint {
            applied = history.prefix { $0.position <= checkpoint.position }.count
            guard applied == checkpoint.eventCount else { throw .outOfOrder(projection.cardID) }
        }
        return try apply(history, from: applied, to: projection)
    }

    /// Skips events the baseline covers and applies the rest.
    public func rebuild(cardID: Card.ID, baseline: SchedulingBaseline, events: [CardReviewEvent])
        throws(ProjectionError) -> CardProjection
    {
        let history = try sorted(events, of: cardID)
        let covered = baseline.checkpoint.map { checkpoint in
            history.prefix { $0.position <= checkpoint.position }.count
        }
        let start = CardProjection(
            cardID: cardID,
            baseline: baseline,
            scheduling: baseline.scheduling,
            checkpoint: baseline.checkpoint.map {
                ProjectionCheckpoint(position: $0.position, eventCount: covered ?? 0)
            }
        )
        return try apply(history, from: covered ?? 0, to: start)
    }

    private func sorted(_ events: [CardReviewEvent], of cardID: Card.ID) throws(ProjectionError) -> [CardReviewEvent] {
        if let foreign = events.first(where: { $0.cardID != cardID }) {
            throw .foreignEvent(foreign.idempotencyKey, expected: cardID)
        }
        return events.sorted { $0.position < $1.position }
    }

    private func apply(_ history: [CardReviewEvent], from index: Int, to projection: CardProjection)
        throws(ProjectionError) -> CardProjection
    {
        guard index < history.count else { return projection }
        var card = FSRS::Card(projection.scheduling)
        for event in history[index...] {
            do {
                card = try scheduler.next(card: card, now: event.answeredAt, grade: FSRS::Rating(event.rating)).card
            } catch {
                throw .scheduler(event.idempotencyKey, String(describing: error))
            }
        }
        return CardProjection(
            cardID: projection.cardID,
            baseline: projection.baseline,
            scheduling: CardScheduling(card),
            checkpoint: ProjectionCheckpoint(position: history[history.count - 1].position, eventCount: history.count)
        )
    }
}

public enum ProjectionError: Error, Hashable, Sendable {
    /// History changed before the checkpoint; rebuild the card.
    case outOfOrder(Card.ID)
    case foreignEvent(UUID, expected: Card.ID)
    case scheduler(UUID, String)
}

extension FSRS::Rating {
    init(_ rating: Rating) {
        switch rating {
        case .again: self = .again
        case .hard: self = .hard
        case .good: self = .good
        case .easy: self = .easy
        }
    }
}

extension FSRS::CardState {
    init(_ state: CardState) {
        switch state {
        case .new: self = .new
        case .learning: self = .learning
        case .review: self = .review
        case .relearning: self = .relearning
        }
    }
}

extension CardState {
    init(_ state: FSRS::CardState) {
        switch state {
        case .new: self = .new
        case .learning: self = .learning
        case .review: self = .review
        case .relearning: self = .relearning
        }
    }
}

extension FSRS::Card {
    init(_ scheduling: CardScheduling) {
        self.init(
            due: scheduling.due,
            stability: scheduling.stability,
            difficulty: scheduling.difficulty,
            elapsedDays: scheduling.elapsedDays,
            scheduledDays: scheduling.scheduledDays,
            learningSteps: scheduling.learningSteps,
            reps: scheduling.reps,
            lapses: scheduling.lapses,
            state: FSRS::CardState(scheduling.state),
            lastReview: scheduling.lastReview
        )
    }
}

extension CardScheduling {
    init(_ card: FSRS::Card) {
        self.init(
            state: CardState(card.state),
            due: card.due,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsedDays: card.elapsedDays,
            scheduledDays: card.scheduledDays,
            learningSteps: card.learningSteps,
            reps: card.reps,
            lapses: card.lapses,
            lastReview: card.lastReview
        )
    }
}
