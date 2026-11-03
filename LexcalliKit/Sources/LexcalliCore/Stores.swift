import Foundation

/// A deck as the list shows it, without its notes.
public struct DeckSummary: Identifiable, Hashable, Sendable {
    public let id: Deck.ID
    public var name: String
    public var termLanguage: Locale.Language
    public var meaningLanguage: Locale.Language
    public var noteCount: Int
    public var cardCount: Int
    /// Cards no longer new, from ended sessions or an imported history.
    public var studiedCardCount: Int

    public init(
        id: Deck.ID, name: String, termLanguage: Locale.Language, meaningLanguage: Locale.Language, noteCount: Int,
        cardCount: Int, studiedCardCount: Int
    ) {
        self.id = id
        self.name = name
        self.termLanguage = termLanguage
        self.meaningLanguage = meaningLanguage
        self.noteCount = noteCount
        self.cardCount = cardCount
        self.studiedCardCount = studiedCardCount
    }

    public init(_ deck: Deck, studiedCardCount: Int = 0) {
        self.init(
            id: deck.id,
            name: deck.name,
            termLanguage: deck.termLanguage,
            meaningLanguage: deck.meaningLanguage,
            noteCount: deck.notes.count,
            cardCount: deck.notes.reduce(0) { $0 + $1.cards.count },
            studiedCardCount: studiedCardCount
        )
    }
}

/// Observing methods yield the current value, then each change; cancelling the consumer stops observation.
public protocol DeckStore: Sendable {
    func deckSummaries() -> AsyncThrowingStream<[DeckSummary], any Error>

    /// Yields `nil` while the deck doesn't exist.
    func deck(_ id: Deck.ID) -> AsyncThrowingStream<Deck?, any Error>

    /// Upserts the deck and its notes. New notes get cards due from `date`; existing cards keep their history.
    func save(_ deck: Deck, at date: Date) async throws
}

public struct OpenedSession: Hashable, Sendable {
    public let session: PracticeSession
    public let queue: [Card.ID]
    /// Recovery of unfinished sessions and ended history still awaiting recalculation.
    public let recovered: ProjectionReport

    public init(session: PracticeSession, queue: [Card.ID], recovered: ProjectionReport) {
        self.session = session
        self.queue = queue
        self.recovered = recovered
    }
}

public struct ProjectionReport: Hashable, Sendable {
    public var endedSessions: [PracticeSession.ID] = []
    public var projectedCards: [Card.ID] = []
    /// Ended history is ahead of the checkpoint or changed before it; state is kept until recalculated.
    public var needsRecalculation: [Card.ID] = []
    /// The projector failed unexpectedly, e.g. FSRS rejected an event; state is kept.
    public var failedCards: [Card.ID] = []

    public var needsRepair: Bool { !needsRecalculation.isEmpty || !failedCards.isEmpty }

    public init(
        endedSessions: [PracticeSession.ID] = [],
        projectedCards: [Card.ID] = [],
        needsRecalculation: [Card.ID] = [],
        failedCards: [Card.ID] = []
    ) {
        self.endedSessions = endedSessions
        self.projectedCards = projectedCards
        self.needsRecalculation = needsRecalculation
        self.failedCards = failedCards
    }

    public mutating func merge(_ other: ProjectionReport) {
        endedSessions += other.endedSessions
        projectedCards += other.projectedCards
        needsRecalculation += other.needsRecalculation
        failedCards += other.failedCards
    }
}

public enum RecordOutcome: Hashable, Sendable {
    case recorded
    /// Same key and content already saved: the retry is acknowledged.
    case alreadyRecorded
}

/// One immutable write command, whichever log owns its event.
public enum PendingAttempt: Hashable, Sendable {
    case card(CardReviewEvent)
    case exercise(ExerciseEvent)

    public var id: UUID {
        switch self {
        case .card(let event): event.id
        case .exercise(let event): event.id
        }
    }
}

public enum ReviewStoreError: Error, Hashable, Sendable {
    case unknownDeck(Deck.ID)
    case unknownSession(PracticeSession.ID)
    case sessionNotOpen(PracticeSession.ID)
    /// Imported history arrives through import, not `record`.
    case eventWithoutSession(UUID)
    case unknownCard(Card.ID)
    case cardNotInSessionDeck(Card.ID)
    case idempotencyConflict(UUID)
    case incompatibleSession(PracticeSession.ID)
    case mixedLocked(Deck.ID)
    case invalidExercise(UUID)
}

/// Recording only appends; ending a session, or opening the next one, projects events into scheduling.
public protocol ReviewStore: Sendable {
    /// Ends and projects open sessions, then opens this one in one write. Reports pending repairs,
    /// including on retry, and excludes those cards from the queue until recalculated.
    func openSession(
        _ id: PracticeSession.ID, deck: Deck.ID, mode: PracticeMode, at date: Date
    ) async throws -> OpenedSession

    /// Current durable review availability, followed by changes (independent of scheduling projection).
    func hasCardReviews(deck: Deck.ID) -> AsyncThrowingStream<Bool, any Error>

    func record(_ event: ExerciseEvent) async throws -> RecordOutcome
    /// Durable history/verification read; currently exercised by shared store and relaunch tests.
    func exerciseEvents(in session: PracticeSession.ID) async throws -> [ExerciseEvent]

    /// Returns `.alreadyRecorded` for a retried event.
    func record(_ event: CardReviewEvent) async throws -> RecordOutcome

    /// Ends the session and projects its events in one write. Idempotent.
    func endSession(_ id: PracticeSession.ID, at date: Date) async throws -> ProjectionReport

    func recalculate(_ card: Card.ID) async throws -> CardProjection

    func session(_ id: PracticeSession.ID) async throws -> PracticeSession?
    func projection(of card: Card.ID) async throws -> CardProjection?
    func reviewEvents(of card: Card.ID) async throws -> [CardReviewEvent]
}

extension ReviewStore {
    public func record(_ attempt: PendingAttempt) async throws -> RecordOutcome {
        switch attempt {
        case .card(let event): try await record(event)
        case .exercise(let event): try await record(event)
        }
    }

    /// Existing callers continue to open Flashcards sessions.
    public func openSession(_ id: PracticeSession.ID, deck: Deck.ID, at date: Date) async throws -> OpenedSession {
        try await openSession(id, deck: deck, mode: .flashcards, at: date)
    }
}
