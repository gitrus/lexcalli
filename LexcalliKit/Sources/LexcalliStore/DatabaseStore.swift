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

    /// For previews and tests; `decks` are saved before it returns.
    public static func inMemory(decks: [Deck] = [], at date: Date = .now) throws -> DatabaseStore {
        let queue = try DatabaseQueue(configuration: configuration)
        try DatabaseMigrator.lexcalli.migrate(queue)
        try queue.write { db in
            for deck in decks { try save(deck, at: date, db) }
        }
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
                    SELECT deck.*,
                        (SELECT COUNT(*) FROM note WHERE note.deck_id = deck.id) AS note_count,
                        (SELECT COUNT(*) FROM card JOIN note ON note.id = card.note_id
                            WHERE note.deck_id = deck.id) AS card_count,
                        (SELECT COUNT(*) FROM card_scheduling JOIN note ON note.id = card_scheduling.note_id
                            WHERE note.deck_id = deck.id AND card_scheduling.state != \(CardState.new.rawValue)) AS studied_card_count,
                        \(Self.deckHasSavedCardReviewSQL(deckIDExpression: "deck.id")) AS has_card_reviews
                    FROM deck ORDER BY name, id
                    """
            ).map { row in
                DeckSummary(
                    id: row["id"],
                    name: row["name"],
                    termLanguage: Locale.Language(identifier: row["term_language"]),
                    meaningLanguage: Locale.Language(identifier: row["meaning_language"]),
                    noteCount: row["note_count"],
                    cardCount: row["card_count"],
                    studiedCardCount: row["studied_card_count"],
                    hasCardReviews: row["has_card_reviews"]
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
        guard let deck = try DeckRecord.fetchOne(db, key: id) else { return nil }
        let notes =
            try NoteRecord
            .filter { $0.deckID == id }
            .order(\.position)
            .including(all: NoteRecord.media.order(NoteMediaRecord.Columns.role, NoteMediaRecord.Columns.position))
            .asRequest(of: NoteWithMedia.self)
            .fetchAll(db)
        return deck.deck(notes: notes.map(\.domain))
    }

    static func save(_ deck: Deck, at date: Date, _ db: Database) throws {
        try DeckRecord(deck).upsert(db)
        for note in deck.notes {
            try save(note, in: deck.id, at: date, db)
        }
    }

    static func save(_ note: Note, in deckID: Deck.ID, at date: Date, _ db: Database) throws {
        let position: Int =
            if let current = try NoteRecord.fetchOne(db, key: note.id), current.deckID == deckID {
                current.position
            } else {
                try NoteRecord.filter { $0.deckID == deckID }
                    .select(max(NoteRecord.Columns.position) + 1, as: Int.self)
                    .fetchOne(db) ?? 0
            }
        try NoteRecord(note, deckID: deckID, position: position).upsert(db)

        try NoteMediaRecord.filter { $0.noteID == note.id }.deleteAll(db)
        let media = (note.image.map { [(NoteMediaRecord.Role.image, $0)] } ?? []) + note.audio.map { (.audio, $0) }
        for (index, (role, reference)) in media.enumerated() {
            try NoteMediaRecord(
                noteID: note.id, role: role, position: index, hash: reference.hash, filename: reference.filename
            ).insert(db)
        }

        for card in note.cards {
            try insertCardIfMissing(card.id, baseline: .new(due: date), db)
        }
    }

    /// Existing cards keep their scheduling and history.
    static func insertCardIfMissing(_ cardID: Card.ID, baseline: SchedulingBaseline, _ db: Database) throws {
        guard try !CardRecord.exists(db, key: cardID.key) else { return }
        try CardRecord(cardID: cardID, baseline: baseline).insert(db)
        try saveProjection(CardProjection(cardID: cardID, baseline: baseline), db)
    }

    static func saveProjection(_ projection: CardProjection, _ db: Database) throws {
        try CardSchedulingRecord(projection).upsert(db)
    }
}
