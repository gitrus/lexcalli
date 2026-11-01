import Foundation

/// A deck as the list shows it, without its notes.
public struct DeckSummary: Identifiable, Hashable, Sendable {
    public let id: Deck.ID
    public var name: String
    public var termLanguage: Locale.Language
    public var meaningLanguage: Locale.Language
    public var noteCount: Int

    public init(
        id: Deck.ID, name: String, termLanguage: Locale.Language, meaningLanguage: Locale.Language, noteCount: Int
    ) {
        self.id = id
        self.name = name
        self.termLanguage = termLanguage
        self.meaningLanguage = meaningLanguage
        self.noteCount = noteCount
    }

    public init(_ deck: Deck) {
        self.init(
            id: deck.id,
            name: deck.name,
            termLanguage: deck.termLanguage,
            meaningLanguage: deck.meaningLanguage,
            noteCount: deck.notes.count
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
    /// Result of ending the sessions an earlier launch left open.
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
    /// History changed before the checkpoint, e.g. through import; state is kept until recalculated.
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

public enum ReviewStoreError: Error, Hashable, Sendable {
    case unknownDeck(Deck.ID)
    case unknownSession(PracticeSession.ID)
    case sessionNotOpen(PracticeSession.ID)
    /// Imported history arrives through import, not `record`.
    case eventWithoutSession(UUID)
    case unknownCard(Card.ID)
    case cardNotInSessionDeck(Card.ID)
    case idempotencyConflict(UUID)
}

/// Recording only appends; ending a session, or opening the next one, projects events into scheduling.
public protocol ReviewStore: Sendable {
    /// Ends and projects open sessions, then opens this one and builds its queue, in one write.
    func openSession(_ id: PracticeSession.ID, deck: Deck.ID, at date: Date) async throws -> OpenedSession

    /// Returns `.alreadyRecorded` for a retried event.
    func record(_ event: CardReviewEvent) async throws -> RecordOutcome

    /// Ends the session and projects its events in one write. Idempotent.
    func endSession(_ id: PracticeSession.ID, at date: Date) async throws -> ProjectionReport

    func recalculate(_ card: Card.ID) async throws -> CardProjection

    func session(_ id: PracticeSession.ID) async throws -> PracticeSession?
    func projection(of card: Card.ID) async throws -> CardProjection?
    func reviewEvents(of card: Card.ID) async throws -> [CardReviewEvent]
}
