import Foundation
import GRDB
import LexcalliCore

extension DatabaseStore {
    /// The Mixed unlock rule, shared by the deck summaries and by opening a Mixed session.
    /// `deckIDExpression` is `deck.id` inside the summaries query, or `?` for a bound deck ID (bound twice).
    static func deckHasSavedCardReviewSQL(deckIDExpression: String) -> String {
        """
        (
            -- Reviewed in a session on this deck. Going by the session keeps the unlock if a note later moves.
            EXISTS (
                SELECT 1 FROM practice_session
                JOIN card_review_event ON card_review_event.practice_session_id = practice_session.id
                WHERE practice_session.deck_id = \(deckIDExpression)
            )
            -- Imported history has no session, so it counts for the note's current deck.
            OR EXISTS (
                SELECT 1 FROM note
                JOIN card_review_event ON card_review_event.note_id = note.id
                WHERE note.deck_id = \(deckIDExpression) AND card_review_event.practice_session_id IS NULL
            )
        )
        """
    }

    static func deckHasSavedCardReview(_ deck: Deck.ID, _ db: Database) throws -> Bool {
        try Bool.fetchOne(
            db, sql: "SELECT \(deckHasSavedCardReviewSQL(deckIDExpression: "?"))", arguments: [deck, deck]) ?? false
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
