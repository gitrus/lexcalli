import Foundation
import GRDB
import LexcalliCore

// Domain types get no GRDB conformances: each record mirrors one table and converts to and from the domain.

struct DeckRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "deck"

    var id: UUID
    var name: String
    var termLanguage: String
    var meaningLanguage: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case termLanguage = "term_language"
        case meaningLanguage = "meaning_language"
    }
}

extension DeckRecord {
    init(_ deck: Deck) {
        self.init(
            id: deck.id, name: deck.name, termLanguage: deck.termLanguage.minimalIdentifier,
            meaningLanguage: deck.meaningLanguage.minimalIdentifier)
    }

    func deck(notes: [Note]) -> Deck {
        Deck(
            id: id, name: name, termLanguage: Locale.Language(identifier: termLanguage),
            meaningLanguage: Locale.Language(identifier: meaningLanguage), notes: notes)
    }
}

struct NoteRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "note"
    static let media = hasMany(NoteMediaRecord.self).forKey("media")

    var id: UUID
    var deckID: UUID
    var position: Int
    var term: String
    var meaning: String
    var transcription: String?
    var example: String?

    enum CodingKeys: String, CodingKey {
        case id, position, term, meaning, transcription, example
        case deckID = "deck_id"
    }

    enum Columns {
        static let deckID = Column(CodingKeys.deckID)
        static let position = Column(CodingKeys.position)
    }
}

extension NoteRecord {
    init(_ note: Note, deckID: Deck.ID, position: Int) {
        self.init(
            id: note.id, deckID: deckID, position: position, term: note.term, meaning: note.meaning,
            transcription: note.transcription, example: note.example)
    }
}

/// A note with its media, in the order they were saved.
struct NoteWithMedia: Decodable, FetchableRecord {
    var note: NoteRecord
    var media: [NoteMediaRecord]

    var domain: Note {
        Note(
            id: note.id, term: note.term, meaning: note.meaning, transcription: note.transcription,
            example: note.example, image: media.first { $0.role == .image }?.reference,
            audio: media.filter { $0.role == .audio }.map(\.reference))
    }
}

/// Relative references; files live in the media library.
struct NoteMediaRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "note_media"

    enum Role: String, Codable {
        case image, audio
    }

    var noteID: UUID
    var role: Role
    var position: Int
    var hash: String
    var filename: String

    var reference: MediaReference { MediaReference(hash: hash, filename: filename) }

    enum CodingKeys: String, CodingKey {
        case role, position, hash, filename
        case noteID = "note_id"
    }

    enum Columns {
        static let noteID = Column(CodingKeys.noteID)
        static let role = Column(CodingKeys.role)
        static let position = Column(CodingKeys.position)
    }
}

/// A card and its baseline, where rebuilding starts.
struct CardRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "card"

    var cardID: Card.ID
    var baseline: SchedulingBaseline

    init(cardID: Card.ID, baseline: SchedulingBaseline) {
        self.cardID = cardID
        self.baseline = baseline
    }

    init(row: Row) throws {
        cardID = try Card.ID(row: row)
        baseline = SchedulingBaseline(
            scheduling: CardScheduling(row: row, prefix: "baseline_"),
            checkpoint: ProjectionCheckpoint(row: row, prefix: "baseline_"))
    }

    func encode(to container: inout PersistenceContainer) {
        cardID.encode(to: &container)
        baseline.scheduling.encode(to: &container, prefix: "baseline_")
        baseline.checkpoint.encode(to: &container, prefix: "baseline_")
    }
}

/// Recomputable from the baseline and the events.
struct CardSchedulingRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "card_scheduling"
    static let note = belongsTo(NoteRecord.self, using: ForeignKey([Card.ID.Columns.noteID]))

    var cardID: Card.ID
    var scheduling: CardScheduling
    var checkpoint: ProjectionCheckpoint?

    init(_ projection: CardProjection) {
        cardID = projection.cardID
        scheduling = projection.scheduling
        checkpoint = projection.checkpoint
    }

    init(row: Row) throws {
        cardID = try Card.ID(row: row)
        scheduling = CardScheduling(row: row, prefix: "")
        checkpoint = ProjectionCheckpoint(row: row, prefix: "")
    }

    func encode(to container: inout PersistenceContainer) {
        cardID.encode(to: &container)
        scheduling.encode(to: &container, prefix: "")
        checkpoint.encode(to: &container, prefix: "")
    }

    func projection(baseline: SchedulingBaseline) -> CardProjection {
        CardProjection(cardID: cardID, baseline: baseline, scheduling: scheduling, checkpoint: checkpoint)
    }
}

struct PracticeSessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "practice_session"

    var id: UUID
    var deckID: UUID
    var openedAt: Int64
    var endedAt: Int64?
    var mode: PracticeMode

    enum CodingKeys: String, CodingKey {
        case id, mode
        case deckID = "deck_id"
        case openedAt = "opened_at"
        case endedAt = "ended_at"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let openedAt = Column(CodingKeys.openedAt)
        static let endedAt = Column(CodingKeys.endedAt)
    }
}

extension PracticeSessionRecord {
    init(_ session: PracticeSession) {
        self.init(
            id: session.id, deckID: session.deckID, openedAt: session.openedAt.milliseconds,
            endedAt: session.endedAt?.milliseconds, mode: session.mode)
    }

    var session: PracticeSession {
        PracticeSession(
            id: id, deckID: deckID, mode: mode, openedAt: Date(milliseconds: openedAt),
            endedAt: endedAt.map(Date.init(milliseconds:)))
    }
}

/// Append-only.
struct CardReviewEventRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "card_review_event"

    var idempotencyKey: UUID
    var practiceSessionID: UUID?
    var noteID: UUID
    var direction: Int
    var rating: Int
    var answeredAt: Int64

    enum CodingKeys: String, CodingKey {
        case direction, rating
        case idempotencyKey = "idempotency_key"
        case practiceSessionID = "practice_session_id"
        case noteID = "note_id"
        case answeredAt = "answered_at"
    }

    enum Columns {
        static let practiceSessionID = Column(CodingKeys.practiceSessionID)
    }
}

extension CardReviewEventRecord {
    init(_ event: CardReviewEvent) {
        self.init(
            idempotencyKey: event.idempotencyKey, practiceSessionID: event.sessionID, noteID: event.cardID.noteID,
            direction: event.cardID.direction.rawValue, rating: event.rating.rawValue,
            answeredAt: event.answeredAt.milliseconds)
    }

    func event() throws -> CardReviewEvent {
        guard let rating = Rating(rawValue: rating), let direction = CardDirection(rawValue: direction) else {
            throw StoreError.corruptRow(Self.databaseTableName)
        }
        return CardReviewEvent(
            idempotencyKey: idempotencyKey, sessionID: practiceSessionID,
            cardID: Card.ID(noteID: noteID, direction: direction), rating: rating,
            answeredAt: Date(milliseconds: answeredAt))
    }
}

extension Card.ID {
    /// The key of `card`, `card_scheduling`, and a card's events.
    enum Columns {
        static let noteID = Column("note_id")
        static let direction = Column("direction")
    }

    init(row: Row) throws {
        guard let direction = CardDirection(rawValue: row[Columns.direction]) else {
            throw StoreError.corruptRow("card")
        }
        self.init(noteID: row[Columns.noteID], direction: direction)
    }

    var key: [String: (any DatabaseValueConvertible)?] {
        [Columns.noteID.name: noteID, Columns.direction.name: direction.rawValue]
    }

    /// Matches this card's rows in any table keyed by card.
    var filter: SQLExpression {
        Columns.noteID == noteID && Columns.direction == direction.rawValue
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.noteID] = noteID
        container[Columns.direction] = direction.rawValue
    }
}

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

    func encode(to container: inout PersistenceContainer, prefix: String) {
        container[prefix + "state"] = state.rawValue
        container[prefix + "due"] = due.timeIntervalSince1970
        container[prefix + "stability"] = stability
        container[prefix + "difficulty"] = difficulty
        container[prefix + "elapsed_days"] = elapsedDays
        container[prefix + "scheduled_days"] = scheduledDays
        container[prefix + "learning_steps"] = learningSteps
        container[prefix + "reps"] = reps
        container[prefix + "lapses"] = lapses
        container[prefix + "last_review"] = lastReview?.timeIntervalSince1970
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
    func encode(to container: inout PersistenceContainer, prefix: String) {
        container[prefix + "checkpoint_answered_at"] = self?.position.answeredAt.milliseconds
        container[prefix + "checkpoint_key"] = self?.position.idempotencyKey
        container[prefix + "checkpoint_count"] = self?.eventCount
    }
}

public enum StoreError: Error, Hashable, Sendable {
    case corruptRow(String)
}
