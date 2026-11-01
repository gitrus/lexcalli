import Foundation
import GRDB
import LexcalliCore

extension DatabaseStore {
    public func openSession(_ id: PracticeSession.ID, deck deckID: Deck.ID, at date: Date) async throws
        -> OpenedSession
    {
        try await writer.write { [projector] db in
            guard
                try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 FROM deck WHERE id = ?)", arguments: [deckID])
                    == true
            else { throw ReviewStoreError.unknownDeck(deckID) }

            if let existing = try Self.fetchSession(id, db) {
                // A retried open after a lost acknowledgement: same session, minus notes already answered.
                guard existing.status == .open, existing.deckID == deckID else {
                    throw ReviewStoreError.sessionNotOpen(id)
                }
                return OpenedSession(
                    session: existing, queue: try Self.queue(for: existing, at: date, db), recovered: .init())
            }

            var report = ProjectionReport()
            let open = try Row.fetchAll(
                db, sql: "SELECT * FROM practice_session WHERE ended_at IS NULL ORDER BY opened_at, id"
            ).map(PracticeSession.init(row:))
            for session in open {
                report.merge(try Self.end(session.id, at: date, projector: projector, db))
            }

            let session = PracticeSession(id: id, deckID: deckID, openedAt: date)
            try db.execute(
                sql: "INSERT INTO practice_session (id, deck_id, opened_at) VALUES (?, ?, ?)",
                arguments: [session.id, deckID, session.openedAt.milliseconds]
            )
            return OpenedSession(session: session, queue: try Self.queue(for: session, at: date, db), recovered: report)
        }
    }

    public func record(_ event: CardReviewEvent) async throws -> RecordOutcome {
        try await writer.write { db in
            if let saved = try Row.fetchOne(
                db, sql: "SELECT * FROM card_review_event WHERE idempotency_key = ?",
                arguments: [event.idempotencyKey])
            {
                guard try CardReviewEvent(row: saved) == event else {
                    throw ReviewStoreError.idempotencyConflict(event.idempotencyKey)
                }
                return .alreadyRecorded
            }
            guard let sessionID = event.sessionID else {
                throw ReviewStoreError.eventWithoutSession(event.idempotencyKey)
            }
            guard let session = try Self.fetchSession(sessionID, db) else {
                throw ReviewStoreError.unknownSession(sessionID)
            }
            guard session.status == .open else { throw ReviewStoreError.sessionNotOpen(sessionID) }
            guard
                let deckID = try UUID.fetchOne(
                    db,
                    sql: """
                        SELECT note.deck_id FROM card JOIN note ON note.id = card.note_id
                        WHERE card.note_id = ? AND card.direction = ?
                        """,
                    arguments: event.cardID.arguments)
            else { throw ReviewStoreError.unknownCard(event.cardID) }
            guard deckID == session.deckID else { throw ReviewStoreError.cardNotInSessionDeck(event.cardID) }

            try Self.insert(event, db)
            return .recorded
        }
    }

    public func endSession(_ id: PracticeSession.ID, at date: Date) async throws -> ProjectionReport {
        try await writer.write { [projector] db in
            guard try Self.fetchSession(id, db) != nil else { throw ReviewStoreError.unknownSession(id) }
            return try Self.end(id, at: date, projector: projector, db)
        }
    }

    public func recalculate(_ cardID: Card.ID) async throws -> CardProjection {
        try await writer.write { [projector] db in
            guard let projection = try Self.fetchProjection(cardID, db) else {
                throw ReviewStoreError.unknownCard(cardID)
            }
            let rebuilt = try projector.rebuild(
                cardID: cardID, baseline: projection.baseline, events: try Self.fetchEvents(cardID, db))
            try Self.saveProjection(rebuilt, db)
            return rebuilt
        }
    }

    public func session(_ id: PracticeSession.ID) async throws -> PracticeSession? {
        try await writer.read { db in try Self.fetchSession(id, db) }
    }

    public func projection(of cardID: Card.ID) async throws -> CardProjection? {
        try await writer.read { db in try Self.fetchProjection(cardID, db) }
    }

    public func reviewEvents(of cardID: Card.ID) async throws -> [CardReviewEvent] {
        try await writer.read { db in try Self.fetchEvents(cardID, db) }
    }

    static func insert(_ event: CardReviewEvent, _ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO card_review_event
                    (idempotency_key, practice_session_id, note_id, direction, rating, answered_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                event.idempotencyKey, event.sessionID, event.cardID.noteID, event.cardID.direction.rawValue,
                event.rating.rawValue, event.answeredAt.milliseconds,
            ]
        )
    }

    static func end(_ id: PracticeSession.ID, at date: Date, projector: Projector, _ db: Database) throws
        -> ProjectionReport
    {
        var report = ProjectionReport()
        try db.execute(
            sql: "UPDATE practice_session SET ended_at = ? WHERE id = ? AND ended_at IS NULL",
            arguments: [date.milliseconds, id]
        )
        if db.changesCount > 0 { report.endedSessions.append(id) }

        let cards = try Row.fetchAll(
            db, sql: "SELECT DISTINCT note_id, direction FROM card_review_event WHERE practice_session_id = ?",
            arguments: [id]
        ).map(Card.ID.init(row:)).sorted()
        report.merge(try project(cards, projector: projector, db))
        return report
    }

    /// Runs in the caller's transaction, saving each state with its checkpoint.
    static func project(_ cards: [Card.ID], projector: Projector, _ db: Database) throws -> ProjectionReport {
        var report = ProjectionReport()
        for cardID in cards {
            guard let projection = try fetchProjection(cardID, db) else { continue }
            do {
                let projected = try projector.project(projection, events: try fetchEvents(cardID, db))
                if projected != projection {
                    try saveProjection(projected, db)
                    report.projectedCards.append(cardID)
                }
            } catch ProjectionError.outOfOrder {
                report.needsRecalculation.append(cardID)
            } catch is ProjectionError {
                report.failedCards.append(cardID)
            }
        }
        return report
    }

    static func queue(for session: PracticeSession, at date: Date, _ db: Database) throws -> [Card.ID] {
        // One card per note per session.
        let candidates = try Row.fetchAll(
            db,
            sql: """
                SELECT card_scheduling.note_id, card_scheduling.direction, card_scheduling.due
                FROM card_scheduling JOIN note ON note.id = card_scheduling.note_id
                WHERE note.deck_id = ? AND note.id NOT IN (
                    SELECT note_id FROM card_review_event WHERE practice_session_id = ?)
                """,
            arguments: [session.deckID, session.id]
        ).map { row in
            QueueCandidate(cardID: try Card.ID(row: row), due: Date(timeIntervalSince1970: row["due"]))
        }
        return StudyQueue.build(from: candidates, now: date)
    }

    static func fetchSession(_ id: PracticeSession.ID, _ db: Database) throws -> PracticeSession? {
        try Row.fetchOne(db, sql: "SELECT * FROM practice_session WHERE id = ?", arguments: [id])
            .map(PracticeSession.init(row:))
    }

    static func fetchEvents(_ cardID: Card.ID, _ db: Database) throws -> [CardReviewEvent] {
        try Row.fetchAll(
            db, sql: "SELECT * FROM card_review_event WHERE note_id = ? AND direction = ?", arguments: cardID.arguments
        ).map(CardReviewEvent.init(row:)).sorted { $0.position < $1.position }
    }

    static func fetchProjection(_ cardID: Card.ID, _ db: Database) throws -> CardProjection? {
        guard
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT card.*, card_scheduling.* FROM card
                    JOIN card_scheduling USING (note_id, direction)
                    WHERE note_id = ? AND direction = ?
                    """,
                arguments: cardID.arguments)
        else { return nil }
        return CardProjection(
            cardID: cardID,
            baseline: SchedulingBaseline(
                scheduling: CardScheduling(row: row, prefix: "baseline_"),
                checkpoint: ProjectionCheckpoint(row: row, prefix: "baseline_")
            ),
            scheduling: CardScheduling(row: row, prefix: ""),
            checkpoint: ProjectionCheckpoint(row: row, prefix: "")
        )
    }
}
