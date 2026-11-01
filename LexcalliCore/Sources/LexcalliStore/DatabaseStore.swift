import Foundation
import GRDB
import LexcalliCore
import Synchronization

/// GRDB implementation of the store protocols. Each command is one synchronous write transaction on GRDB's queue,
/// so state and checkpoint are saved atomically and no transaction spans an `await`.
public final class DatabaseStore: DeckStore, ReviewStore {
    let writer: any DatabaseWriter
    let projector: Projector
    private let observationQueue = DispatchQueue(label: "dev.gitrus.lexcalli.store-observation")
    private let observations = Mutex(0)

    init(writer: any DatabaseWriter, projector: Projector = Projector()) {
        self.writer = writer
        self.projector = projector
    }

    public static func inMemory() throws -> DatabaseStore {
        let queue = try DatabaseQueue(configuration: configuration)
        try DatabaseMigrator.lexcalli.migrate(queue)
        return DatabaseStore(writer: queue)
    }

    static var configuration: Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return configuration
    }

    public var activeObservations: Int { observations.withLock { $0 } }

    func observe<Value: Equatable & Sendable>(_ fetch: @escaping @Sendable (Database) throws -> Value)
        -> AsyncThrowingStream<Value, any Error>
    {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Value.self, throwing: (any Error).self)
        let cancellable = ValueObservation.tracking(fetch)
            .removeDuplicates()
            .start(
                in: writer,
                scheduling: .async(onQueue: observationQueue),
                onError: { continuation.finish(throwing: $0) },
                onChange: { continuation.yield($0) }
            )
        observations.withLock { $0 += 1 }
        continuation.onTermination = { _ in
            cancellable.cancel()
            self.observations.withLock { $0 -= 1 }
        }
        return stream
    }

    public func deckSummaries() -> AsyncThrowingStream<[DeckSummary], any Error> {
        observe { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT deck.*, (SELECT COUNT(*) FROM note WHERE note.deck_id = deck.id) AS note_count
                    FROM deck ORDER BY name, id
                    """
            ).map { row in
                DeckSummary(
                    id: row["id"],
                    name: row["name"],
                    termLanguage: Locale.Language(identifier: row["term_language"]),
                    meaningLanguage: Locale.Language(identifier: row["meaning_language"]),
                    noteCount: row["note_count"]
                )
            }
        }
    }

    public func deck(_ id: Deck.ID) -> AsyncThrowingStream<Deck?, any Error> {
        observe { db in try Self.fetchDeck(id, db) }
    }

    public func save(_ deck: Deck, at date: Date) async throws {
        try await writer.write { db in try Self.save(deck, at: date, db) }
    }

    static func fetchDeck(_ id: Deck.ID, _ db: Database) throws -> Deck? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM deck WHERE id = ?", arguments: [id]) else {
            return nil
        }
        var media: [Note.ID: (image: MediaReference?, audio: [MediaReference])] = [:]
        let mediaRows = try Row.fetchAll(
            db,
            sql: """
                SELECT note_media.* FROM note_media JOIN note ON note.id = note_media.note_id
                WHERE note.deck_id = ? ORDER BY note_media.note_id, note_media.role, note_media.position
                """,
            arguments: [id]
        )
        for row in mediaRows {
            let reference = MediaReference(hash: row["hash"], filename: row["filename"])
            let noteID: UUID = row["note_id"]
            if row["role"] == "image" {
                media[noteID, default: (nil, [])].image = reference
            } else {
                media[noteID, default: (nil, [])].audio.append(reference)
            }
        }
        let notes = try Row.fetchAll(
            db, sql: "SELECT * FROM note WHERE deck_id = ? ORDER BY position", arguments: [id]
        ).map { row in
            let noteID: UUID = row["id"]
            return Note(
                id: noteID,
                term: row["term"],
                meaning: row["meaning"],
                transcription: row["transcription"],
                example: row["example"],
                image: media[noteID]?.image,
                audio: media[noteID]?.audio ?? []
            )
        }
        return Deck(
            id: id,
            name: row["name"],
            termLanguage: Locale.Language(identifier: row["term_language"]),
            meaningLanguage: Locale.Language(identifier: row["meaning_language"]),
            notes: notes
        )
    }

    static func save(_ deck: Deck, at date: Date, _ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO deck (id, name, term_language, meaning_language) VALUES (?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET
                    name = excluded.name, term_language = excluded.term_language,
                    meaning_language = excluded.meaning_language
                """,
            arguments: [
                deck.id, deck.name, deck.termLanguage.minimalIdentifier, deck.meaningLanguage.minimalIdentifier,
            ]
        )
        for note in deck.notes {
            try save(note, in: deck.id, at: date, db)
        }
    }

    static func save(_ note: Note, in deckID: Deck.ID, at date: Date, _ db: Database) throws {
        let current = try Row.fetchOne(db, sql: "SELECT deck_id, position FROM note WHERE id = ?", arguments: [note.id])
        let position: Int =
            if let current, current["deck_id"] == deckID {
                current["position"]
            } else {
                try Int.fetchOne(
                    db, sql: "SELECT COALESCE(MAX(position) + 1, 0) FROM note WHERE deck_id = ?", arguments: [deckID]
                ) ?? 0
            }
        try db.execute(
            sql: """
                INSERT INTO note (id, deck_id, position, term, meaning, transcription, example)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET
                    deck_id = excluded.deck_id, position = excluded.position, term = excluded.term,
                    meaning = excluded.meaning, transcription = excluded.transcription, example = excluded.example
                """,
            arguments: [note.id, deckID, position, note.term, note.meaning, note.transcription, note.example]
        )

        try db.execute(sql: "DELETE FROM note_media WHERE note_id = ?", arguments: [note.id])
        let media = (note.image.map { [("image", $0)] } ?? []) + note.audio.map { ("audio", $0) }
        for (index, (role, reference)) in media.enumerated() {
            try db.execute(
                sql: "INSERT INTO note_media (note_id, role, position, hash, filename) VALUES (?, ?, ?, ?, ?)",
                arguments: [note.id, role, index, reference.hash, reference.filename]
            )
        }

        for card in note.cards {
            try insertCardIfMissing(card.id, baseline: .new(due: date), db)
        }
    }

    /// Existing cards keep their scheduling and history.
    static func insertCardIfMissing(_ cardID: Card.ID, baseline: SchedulingBaseline, _ db: Database) throws {
        let exists =
            try Bool.fetchOne(
                db, sql: "SELECT EXISTS (SELECT 1 FROM card WHERE note_id = ? AND direction = ?)",
                arguments: cardID.arguments) ?? false
        guard !exists else { return }
        let key: [String: (any DatabaseValueConvertible)?] = [
            "note_id": cardID.noteID, "direction": cardID.direction.rawValue,
        ]
        try db.insert(
            into: "card",
            key.merging(baseline.scheduling.columns(prefix: "baseline_")) { $1 }
                .merging(baseline.checkpoint.columns(prefix: "baseline_")) { $1 }
        )
        try saveProjection(CardProjection(cardID: cardID, baseline: baseline), db)
    }

    static func saveProjection(_ projection: CardProjection, _ db: Database) throws {
        let key: [String: (any DatabaseValueConvertible)?] = [
            "note_id": projection.cardID.noteID, "direction": projection.cardID.direction.rawValue,
        ]
        try db.insert(
            into: "card_scheduling",
            key.merging(projection.scheduling.columns(prefix: "")) { $1 }
                .merging(projection.checkpoint.columns(prefix: "")) { $1 },
            orReplace: true
        )
    }
}
