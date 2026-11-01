import Foundation
import GRDB
import LexcalliCore

// Domain types get no GRDB conformances; rows are mapped here.

extension CardScheduling {
    init(row: Row, prefix: String) {
        self.init(
            state: CardState(rawValue: row[prefix + "state"]) ?? .new,
            due: Date(timeIntervalSince1970: row[prefix + "due"]),
            stability: row[prefix + "stability"],
            difficulty: row[prefix + "difficulty"],
            elapsedDays: row[prefix + "elapsed_days"],
            scheduledDays: row[prefix + "scheduled_days"],
            learningSteps: row[prefix + "learning_steps"],
            reps: row[prefix + "reps"],
            lapses: row[prefix + "lapses"],
            lastReview: (row[prefix + "last_review"] as Double?).map(Date.init(timeIntervalSince1970:))
        )
    }

    func columns(prefix: String) -> [String: (any DatabaseValueConvertible)?] {
        [
            prefix + "state": state.rawValue,
            prefix + "due": due.timeIntervalSince1970,
            prefix + "stability": stability,
            prefix + "difficulty": difficulty,
            prefix + "elapsed_days": elapsedDays,
            prefix + "scheduled_days": scheduledDays,
            prefix + "learning_steps": learningSteps,
            prefix + "reps": reps,
            prefix + "lapses": lapses,
            prefix + "last_review": lastReview?.timeIntervalSince1970,
        ]
    }
}

extension ProjectionCheckpoint {
    init?(row: Row, prefix: String) {
        guard let milliseconds: Int64 = row[prefix + "checkpoint_answered_at"],
            let key: UUID = row[prefix + "checkpoint_key"],
            let count: Int = row[prefix + "checkpoint_count"]
        else { return nil }
        self.init(
            position: ReviewPosition(answeredAt: Date(milliseconds: milliseconds), idempotencyKey: key),
            eventCount: count)
    }
}

extension Optional where Wrapped == ProjectionCheckpoint {
    func columns(prefix: String) -> [String: (any DatabaseValueConvertible)?] {
        [
            prefix + "checkpoint_answered_at": self?.position.answeredAt.milliseconds,
            prefix + "checkpoint_key": self?.position.idempotencyKey,
            prefix + "checkpoint_count": self?.eventCount,
        ]
    }
}

extension CardReviewEvent {
    init(row: Row) throws {
        guard let rating = Rating(rawValue: row["rating"]), let direction = CardDirection(rawValue: row["direction"])
        else { throw StoreError.corruptRow("card_review_event") }
        self.init(
            idempotencyKey: row["idempotency_key"],
            sessionID: row["practice_session_id"],
            cardID: Card.ID(noteID: row["note_id"], direction: direction),
            rating: rating,
            answeredAt: Date(milliseconds: row["answered_at"])
        )
    }
}

extension PracticeSession {
    init(row: Row) {
        self.init(
            id: row["id"],
            deckID: row["deck_id"],
            openedAt: Date(milliseconds: row["opened_at"]),
            endedAt: (row["ended_at"] as Int64?).map(Date.init(milliseconds:))
        )
    }
}

extension Card.ID {
    init(row: Row) throws {
        guard let direction = CardDirection(rawValue: row["direction"]) else { throw StoreError.corruptRow("card") }
        self.init(noteID: row["note_id"], direction: direction)
    }

    var arguments: StatementArguments { [noteID, direction.rawValue] }
}

extension Database {
    func insert(into table: String, _ columns: [String: (any DatabaseValueConvertible)?], orReplace: Bool = false)
        throws
    {
        let names = Array(columns.keys)
        let sql = """
            INSERT \(orReplace ? "OR REPLACE " : "")INTO \(table) (\(names.joined(separator: ", ")))
            VALUES (\(names.map { _ in "?" }.joined(separator: ", ")))
            """
        try execute(sql: sql, arguments: StatementArguments(names.map { columns[$0]! }))
    }
}

public enum StoreError: Error, Hashable, Sendable {
    case corruptRow(String)
}
