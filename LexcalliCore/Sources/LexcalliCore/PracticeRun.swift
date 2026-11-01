import Foundation

/// Progress through a fixed queue. An answer becomes one event, returned again until acknowledged, so duplicate
/// taps and lost acknowledgements can't record a second review.
public struct PracticeRun: Hashable, Sendable {
    public let session: PracticeSession
    public let queue: [Card.ID]
    public private(set) var pending: CardReviewEvent?
    public private(set) var answeredCount = 0

    public init(session: PracticeSession, queue: [Card.ID]) {
        self.session = session
        self.queue = queue
    }

    public var current: Card.ID? { answeredCount < queue.count ? queue[answeredCount] : nil }

    public var isComplete: Bool { current == nil }

    /// While an answer is pending, returns that event and ignores `rating`.
    public mutating func answer(_ rating: Rating, at date: Date, idempotencyKey: UUID = UUID()) -> CardReviewEvent? {
        if let pending { return pending }
        guard let current else { return nil }
        let event = CardReviewEvent(
            idempotencyKey: idempotencyKey,
            sessionID: session.id,
            cardID: current,
            rating: rating,
            answeredAt: date
        )
        pending = event
        return event
    }

    /// Advances only for the pending event's key; late duplicates change nothing.
    @discardableResult
    public mutating func acknowledge(_ idempotencyKey: UUID) -> Bool {
        guard pending?.idempotencyKey == idempotencyKey else { return false }
        pending = nil
        answeredCount += 1
        return true
    }
}
