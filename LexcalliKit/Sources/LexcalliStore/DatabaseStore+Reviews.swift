import Foundation
import GRDB
import LexcalliCore

extension DatabaseStore {
    public func openSession(
        _ id: PracticeSession.ID, deck deckID: Deck.ID, mode: PracticeMode, at date: Date
    ) async throws -> OpenedSession {
        try await writer.write { [projector] db in
            guard try DeckRecord.exists(db, key: deckID) else { throw ReviewStoreError.unknownDeck(deckID) }

            if let existing = try Self.fetchSession(id, db) {
                // A retried open after a lost acknowledgement: same session, minus notes already answered.
                guard existing.status == .open else { throw ReviewStoreError.sessionNotOpen(id) }
                guard existing.deckID == deckID, existing.mode == mode else {
                    throw ReviewStoreError.incompatibleSession(id)
                }
                return OpenedSession(
                    session: existing, queue: try Self.queue(for: existing, at: date, db),
                    recovered: ProjectionReport(needsRecalculation: try Self.pendingRepairs(db)))
            }

            if mode == .mixed, try !Self.hasCardReviews(deck: deckID, db) {
                throw ReviewStoreError.mixedLocked(deckID)
            }
            var report = ProjectionReport()
            let open = try PracticeSessionRecord.filter { $0.endedAt == nil }
                .order { [$0.openedAt, $0.id] }
                .fetchAll(db)
            for session in open {
                report.merge(try Self.end(session.id, at: date, projector: projector, db))
            }

            let reported = Set(report.needsRecalculation + report.failedCards)
            report.needsRecalculation += try Self.pendingRepairs(db).filter { !reported.contains($0) }

            let session = PracticeSession(id: id, deckID: deckID, mode: mode, openedAt: date)
            try PracticeSessionRecord(session).insert(db)
            return OpenedSession(session: session, queue: try Self.queue(for: session, at: date, db), recovered: report)
        }
    }

    public func record(_ event: CardReviewEvent) async throws -> RecordOutcome {
        try await writer.write { db in
            if try Bool.fetchOne(
                db, sql: "SELECT EXISTS (SELECT 1 FROM exercise_event WHERE idempotency_key = ?)",
                arguments: [event.idempotencyKey]) == true
            {
                throw ReviewStoreError.idempotencyConflict(event.idempotencyKey)
            }
            if let saved = try CardReviewEventRecord.fetchOne(db, key: event.idempotencyKey) {
                guard try saved.event() == event else {
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
            guard try CardRecord.exists(db, key: event.cardID.key),
                let note = try NoteRecord.fetchOne(db, key: event.cardID.noteID)
            else { throw ReviewStoreError.unknownCard(event.cardID) }
            guard note.deckID == session.deckID else { throw ReviewStoreError.cardNotInSessionDeck(event.cardID) }

            try CardReviewEventRecord(event).insert(db)
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

    static func end(_ id: PracticeSession.ID, at date: Date, projector: Projector, _ db: Database) throws
        -> ProjectionReport
    {
        var report = ProjectionReport()
        let ended = try PracticeSessionRecord.filter { $0.id == id && $0.endedAt == nil }
            .updateAll(db) { $0.endedAt.set(to: date.milliseconds) }
        if ended > 0 { report.endedSessions.append(id) }

        let cards = try CardReviewEventRecord.filter { $0.practiceSessionID == id }
            .select(Card.ID.Columns.noteID, Card.ID.Columns.direction).distinct()
            .asRequest(of: Row.self).fetchAll(db)
            .map(Card.ID.init(row:)).sorted()
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

    /// Append-only history makes the checkpoint count a durable repair marker, even after a session ends.
    static func pendingRepairs(_ db: Database) throws -> [Card.ID] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT e.note_id, e.direction
                FROM card_review_event e
                JOIN card_scheduling s ON s.note_id = e.note_id AND s.direction = e.direction
                LEFT JOIN practice_session p ON p.id = e.practice_session_id
                WHERE e.practice_session_id IS NULL OR p.ended_at IS NOT NULL
                GROUP BY e.note_id, e.direction
                HAVING COUNT(*) > COALESCE(s.checkpoint_count, 0)
                ORDER BY e.note_id, e.direction
                """
        ).map(Card.ID.init(row:)).sorted()
    }

    static func queue(for session: PracticeSession, at date: Date, _ db: Database) throws -> [Card.ID] {
        let pending = Set(try pendingRepairs(db))
        // One card per note per session.
        let answered = Set(
            try UUID.fetchAll(
                db,
                sql: """
                    SELECT note_id FROM card_review_event WHERE practice_session_id = ?
                    UNION SELECT note_id FROM exercise_event WHERE practice_session_id = ?
                    """, arguments: [session.id, session.id]))
        let candidates =
            try CardSchedulingRecord
            .joining(required: CardSchedulingRecord.note.filter { $0.deckID == session.deckID })
            .fetchAll(db)
            .filter { !pending.contains($0.cardID) && !answered.contains($0.cardID.noteID) }
            .map { QueueCandidate(cardID: $0.cardID, due: $0.scheduling.due) }
        return StudyQueue.build(from: candidates, now: date)
    }

    static func fetchSession(_ id: PracticeSession.ID, _ db: Database) throws -> PracticeSession? {
        try PracticeSessionRecord.fetchOne(db, key: id)?.session
    }

    static func fetchEvents(_ cardID: Card.ID, _ db: Database) throws -> [CardReviewEvent] {
        try CardReviewEventRecord.filter(cardID.filter).fetchAll(db)
            .map { try $0.event() }.sorted { $0.position < $1.position }
    }

    static func fetchProjection(_ cardID: Card.ID, _ db: Database) throws -> CardProjection? {
        guard let card = try CardRecord.fetchOne(db, key: cardID.key),
            let scheduling = try CardSchedulingRecord.fetchOne(db, key: cardID.key)
        else { return nil }
        return scheduling.projection(baseline: card.baseline)
    }
}
