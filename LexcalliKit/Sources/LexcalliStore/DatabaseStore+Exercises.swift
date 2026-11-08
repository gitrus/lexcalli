import Foundation
import GRDB
import LexcalliCore

extension DatabaseStore {
    public func hasCardReviews(deck: Deck.ID) -> AsyncThrowingStream<Bool, any Error> {
        observe { db in try Self.hasCardReviews(deck: deck, db) }
    }

    static func hasCardReviews(deck: Deck.ID, _ db: Database) throws -> Bool {
        // Session membership retains the original deck's unlock if a note is later moved.
        try Bool.fetchOne(
            db,
            sql: """
                SELECT EXISTS (
                    SELECT 1 FROM practice_session p WHERE p.deck_id = ?
                    AND EXISTS (SELECT 1 FROM card_review_event e WHERE e.practice_session_id = p.id)
                ) OR EXISTS (
                    SELECT 1 FROM note n WHERE n.deck_id = ?
                    AND EXISTS (SELECT 1 FROM card_review_event e
                        WHERE e.note_id = n.id AND e.practice_session_id IS NULL)
                )
                """, arguments: [deck, deck]) ?? false
    }

    public func record(_ event: ExerciseEvent) async throws -> RecordOutcome {
        let payload = try ExerciseEventPayload(event).encoded()
        return try await writer.write { db in
            if try CardReviewEventRecord.exists(db, key: event.id) {
                throw ReviewStoreError.idempotencyConflict(event.id)
            }
            if let saved = try Data.fetchOne(
                db, sql: "SELECT payload FROM exercise_event WHERE idempotency_key = ?",
                arguments: [event.id])
            {
                guard saved == payload else {
                    throw ReviewStoreError.idempotencyConflict(event.id)
                }
                return .alreadyRecorded
            }
            guard let session = try Self.fetchSession(event.sessionID, db) else {
                throw ReviewStoreError.unknownSession(event.sessionID)
            }
            let noteIDs = Set(
                try UUID.fetchAll(db, sql: "SELECT id FROM note WHERE deck_id = ?", arguments: [session.deckID]))
            try event.validate(in: session, noteIDs: noteIDs)
            try db.execute(
                sql: """
                    INSERT INTO exercise_event
                    (idempotency_key, practice_session_id, note_id, direction, answered_at, payload)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    event.id, event.sessionID, event.attempt.cardID.noteID, event.attempt.cardID.direction.rawValue,
                    event.answeredAt.milliseconds, payload,
                ])
            return .recorded
        }
    }

    public func exerciseEvents(in session: PracticeSession.ID) async throws -> [ExerciseEvent] {
        try await writer.read { db in
            try Data.fetchAll(
                db,
                sql:
                    "SELECT payload FROM exercise_event WHERE practice_session_id = ? ORDER BY answered_at, idempotency_key",
                arguments: [session]
            )
            .map(ExerciseEventPayload.event(from:))
        }
    }
}
