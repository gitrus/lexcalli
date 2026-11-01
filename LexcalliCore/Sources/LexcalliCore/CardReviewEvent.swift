import Foundation

/// Anki's revlog `ease` numbering.
public enum Rating: Int, CaseIterable, Hashable, Sendable, Codable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// Anki's card `type` numbering.
public enum CardState: Int, CaseIterable, Hashable, Sendable, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// One scheduled review in the card review log, projected into scheduling later.
public struct CardReviewEvent: Identifiable, Hashable, Sendable {
    /// Reused on every retry, so a retried write is recorded once.
    public let idempotencyKey: UUID
    /// `nil` for imported history.
    public let sessionID: PracticeSession.ID?
    public let cardID: Card.ID
    public let rating: Rating
    /// Whole milliseconds, as stored, so replays match before and after saving.
    public let answeredAt: Date

    public var id: UUID { idempotencyKey }

    public var position: ReviewPosition { ReviewPosition(answeredAt: answeredAt, idempotencyKey: idempotencyKey) }

    public init(
        idempotencyKey: UUID = UUID(),
        sessionID: PracticeSession.ID?,
        cardID: Card.ID,
        rating: Rating,
        answeredAt: Date
    ) {
        self.idempotencyKey = idempotencyKey
        self.sessionID = sessionID
        self.cardID = cardID
        self.rating = rating
        self.answeredAt = Date(milliseconds: answeredAt.milliseconds)
    }
}

/// Replay order: answer time, then idempotency key, so every device replays identically.
public struct ReviewPosition: Hashable, Comparable, Sendable {
    public let answeredAt: Date
    public let idempotencyKey: UUID

    public init(answeredAt: Date, idempotencyKey: UUID) {
        self.answeredAt = answeredAt
        self.idempotencyKey = idempotencyKey
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.answeredAt != rhs.answeredAt { return lhs.answeredAt < rhs.answeredAt }
        return lhs.idempotencyKey.uuidString < rhs.idempotencyKey.uuidString
    }
}

extension Date {
    /// Milliseconds since 1970, as in Anki's revlog ids.
    public var milliseconds: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    public init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}
