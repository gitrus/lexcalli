import Foundation
import LexcalliCore
import Synchronization

@testable import LexcalliStore

/// A second implementation of the store contract, so the contract tests don't only describe `DatabaseStore`.
/// Observers are notified under the change's lock, so they see changes in commit order.
final class ReferenceStore: TestableStore {
    private let state = Mutex(State())
    private let projector: Projector

    init(projector: Projector = Projector()) {
        self.projector = projector
    }

    convenience init(decks: [Deck], at date: Date = .now) {
        self.init()
        state.withLock { state in
            for deck in decks { state.save(deck, at: date) }
        }
    }

    func deckSummaries() -> AsyncThrowingStream<[DeckSummary], any Error> {
        observe { .summaries($0) }
    }

    func deck(_ id: Deck.ID) -> AsyncThrowingStream<Deck?, any Error> {
        observe { .deck(id, $0) }
    }

    @concurrent func record(_ event: ExerciseEvent) async throws -> RecordOutcome {
        let payload = try ExerciseEventPayload(event).encoded()
        return try state.withLock { state in
            guard state.events[event.id] == nil else { throw ReviewStoreError.idempotencyConflict(event.id) }
            if let saved = state.exerciseEvents[event.id] {
                guard try ExerciseEventPayload(saved).encoded() == payload else {
                    throw ReviewStoreError.idempotencyConflict(event.id)
                }
                return .alreadyRecorded
            }
            guard let session = state.sessions[event.sessionID] else {
                throw ReviewStoreError.unknownSession(event.sessionID)
            }
            try event.validate(in: session, noteIDs: Set(state.decks[session.deckID]?.notes.map(\.id) ?? []))
            state.exerciseEvents[event.id] = event
            return .recorded
        }
    }

    @concurrent func exerciseEvents(in session: PracticeSession.ID) async throws -> [ExerciseEvent] {
        state.withLock { state in
            state.exerciseEvents.values.filter { $0.sessionID == session }.sorted {
                ($0.answeredAt, $0.id.uuidString) < ($1.answeredAt, $1.id.uuidString)
            }
        }
    }

    @concurrent func save(_ deck: Deck, at date: Date) async throws {
        state.withLock { state in
            state.save(deck, at: date)
            state.notifyObservers()
        }
    }

    @concurrent func openSession(
        _ id: PracticeSession.ID, deck deckID: Deck.ID, mode: PracticeMode, at date: Date
    ) async throws -> OpenedSession {
        try state.withLock { state throws(ReviewStoreError) in
            guard state.decks[deckID] != nil else { throw .unknownDeck(deckID) }
            if let existing = state.sessions[id] {
                // A retried open after a lost acknowledgement: same session, minus notes already answered.
                guard existing.status == .open else { throw .sessionNotOpen(id) }
                guard existing.deckID == deckID, existing.mode == mode else { throw .incompatibleSession(id) }
                return OpenedSession(
                    session: existing, queue: state.queue(for: existing, at: date),
                    recovered: ProjectionReport(needsRecalculation: state.pendingRepairs))
            }
            guard mode != .mixed || state.hasCardReviews(deck: deckID) else { throw .mixedLocked(deckID) }
            var report = ProjectionReport()
            let open = state.sessions.values.filter { $0.status == .open }
                .sorted { ($0.openedAt, $0.id.uuidString) < ($1.openedAt, $1.id.uuidString) }
            for open in open {
                report.merge(state.end(open.id, at: date, projector: projector))
            }
            let reported = Set(report.needsRecalculation + report.failedCards)
            report.needsRecalculation += state.pendingRepairs.filter { !reported.contains($0) }
            state.notifyObservers()
            let session = PracticeSession(id: id, deckID: deckID, mode: mode, openedAt: date)
            state.sessions[id] = session
            return OpenedSession(session: session, queue: state.queue(for: session, at: date), recovered: report)
        }
    }

    @concurrent func record(_ event: CardReviewEvent) async throws -> RecordOutcome {
        try state.withLock { state throws(ReviewStoreError) in
            guard state.exerciseEvents[event.idempotencyKey] == nil else {
                throw .idempotencyConflict(event.idempotencyKey)
            }
            if let saved = state.events[event.idempotencyKey] {
                guard saved == event else { throw .idempotencyConflict(event.idempotencyKey) }
                return .alreadyRecorded
            }
            guard let sessionID = event.sessionID else { throw .eventWithoutSession(event.idempotencyKey) }
            guard let session = state.sessions[sessionID] else { throw .unknownSession(sessionID) }
            guard session.status == .open else { throw .sessionNotOpen(sessionID) }
            guard state.projections[event.cardID] != nil else { throw .unknownCard(event.cardID) }
            guard state.noteDecks[event.cardID.noteID] == session.deckID else {
                throw .cardNotInSessionDeck(event.cardID)
            }
            state.events[event.idempotencyKey] = event
            state.eventKeys[event.cardID, default: []].append(event.idempotencyKey)
            state.notifyObservers()
            return .recorded
        }
    }

    @concurrent func endSession(_ id: PracticeSession.ID, at date: Date) async throws -> ProjectionReport {
        try state.withLock { state throws(ReviewStoreError) in
            guard state.sessions[id] != nil else { throw .unknownSession(id) }
            let report = state.end(id, at: date, projector: projector)
            state.notifyObservers()
            return report
        }
    }

    @concurrent func recalculate(_ cardID: Card.ID) async throws -> CardProjection {
        try state.withLock { state throws(any Error) in
            guard let projection = state.projections[cardID] else { throw ReviewStoreError.unknownCard(cardID) }
            let rebuilt = try projector.rebuild(
                cardID: cardID, baseline: projection.baseline, events: state.events(of: cardID))
            state.projections[cardID] = rebuilt
            state.notifyObservers()
            return rebuilt
        }
    }

    @concurrent func session(_ id: PracticeSession.ID) async throws -> PracticeSession? {
        state.withLock { $0.sessions[id] }
    }

    @concurrent func projection(of cardID: Card.ID) async throws -> CardProjection? {
        state.withLock { $0.projections[cardID] }
    }

    @concurrent func reviewEvents(of cardID: Card.ID) async throws -> [CardReviewEvent] {
        state.withLock { $0.events(of: cardID).sorted { $0.position < $1.position } }
    }

    private func observe<Element: Sendable>(
        _ makeObserver: (AsyncThrowingStream<Element, any Error>.Continuation) -> Observer
    ) -> AsyncThrowingStream<Element, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Element.self, throwing: (any Error).self)
        let id = UUID()
        state.withLock { state in
            state.observers[id] = makeObserver(continuation)
            state.notifyObserver(id)
        }
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.observers.removeValue(forKey: id) }
        }
        return stream
    }

    var activeObservations: Int { state.withLock { $0.observers.count } }
}

private enum Observer: Sendable {
    case summaries(AsyncThrowingStream<[DeckSummary], any Error>.Continuation, last: [DeckSummary]? = nil)
    case deck(Deck.ID, AsyncThrowingStream<Deck?, any Error>.Continuation, last: Deck?? = nil)
}

private struct State: Sendable {
    var decks: [Deck.ID: Deck] = [:]
    var noteDecks: [Note.ID: Deck.ID] = [:]
    var projections: [Card.ID: CardProjection] = [:]
    var events: [UUID: CardReviewEvent] = [:]
    var exerciseEvents: [UUID: ExerciseEvent] = [:]
    var eventKeys: [Card.ID: [UUID]] = [:]
    var sessions: [PracticeSession.ID: PracticeSession] = [:]
    var observers: [UUID: Observer] = [:]

    mutating func save(_ deck: Deck, at date: Date) {
        var stored =
            decks[deck.id]
            ?? Deck(
                id: deck.id, name: deck.name, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
        stored.name = deck.name
        stored.termLanguage = deck.termLanguage
        stored.meaningLanguage = deck.meaningLanguage
        for note in deck.notes {
            if let index = stored.notes.firstIndex(where: { $0.id == note.id }) {
                stored.notes[index] = note
            } else {
                if let previous = noteDecks[note.id], previous != deck.id {
                    decks[previous]?.notes.removeAll { $0.id == note.id }
                }
                stored.notes.append(note)
                noteDecks[note.id] = deck.id
            }
            for card in note.cards where projections[card.id] == nil {
                projections[card.id] = CardProjection(cardID: card.id, baseline: .new(due: date))
            }
        }
        decks[deck.id] = stored
    }

    func events(of cardID: Card.ID) -> [CardReviewEvent] {
        eventKeys[cardID, default: []].compactMap { events[$0] }
    }

    func hasCardReviews(deck: Deck.ID) -> Bool {
        events.values.contains { event in
            if let session = event.sessionID { return sessions[session]?.deckID == deck }
            return noteDecks[event.cardID.noteID] == deck
        }
    }

    var pendingRepairs: [Card.ID] {
        eventKeys.keys.filter { card in
            let endedCount = events(of: card).count { event in
                event.sessionID.map { sessions[$0]?.status == .ended } ?? true
            }
            return endedCount > (projections[card]?.checkpoint?.eventCount ?? 0)
        }.sorted()
    }

    func queue(for session: PracticeSession, at date: Date) -> [Card.ID] {
        let pending = Set(pendingRepairs)
        // One card per note per session.
        let answered = Set(events.values.filter { $0.sessionID == session.id }.map(\.cardID.noteID))
            .union(exerciseEvents.values.filter { $0.sessionID == session.id }.map(\.attempt.cardID.noteID))
        let candidates = (decks[session.deckID]?.notes ?? []).flatMap(\.cards).compactMap { card in
            answered.contains(card.noteID) || pending.contains(card.id)
                ? nil : projections[card.id].map { QueueCandidate(cardID: card.id, due: $0.scheduling.due) }
        }
        return StudyQueue.build(from: candidates, now: date)
    }

    mutating func end(_ id: PracticeSession.ID, at date: Date, projector: Projector) -> ProjectionReport {
        var report = ProjectionReport()
        if sessions[id]?.status == .open {
            sessions[id]?.endedAt = Date(milliseconds: date.milliseconds)
            report.endedSessions.append(id)
        }
        let cards = Set(events.values.filter { $0.sessionID == id }.map(\.cardID)).sorted()
        for cardID in cards {
            guard let projection = projections[cardID] else { continue }
            do {
                let projected = try projector.project(projection, events: events(of: cardID))
                if projected != projection {
                    projections[cardID] = projected
                    report.projectedCards.append(cardID)
                }
            } catch .outOfOrder {
                report.needsRecalculation.append(cardID)
            } catch {
                report.failedCards.append(cardID)
            }
        }
        return report
    }

    mutating func notifyObservers() {
        for id in observers.keys { notifyObserver(id) }
    }

    mutating func notifyObserver(_ id: UUID) {
        switch observers[id] {
        case .summaries(let continuation, let last):
            let summaries = decks.values.map { deck in
                DeckSummary(
                    deck,
                    studiedCardCount: deck.notes.flatMap(\.cards).count {
                        projections[$0.id]?.scheduling.state != .new
                    },
                    hasCardReviews: hasCardReviews(deck: deck.id)
                )
            }
            .sorted {
                ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)
            }
            guard summaries != last else { return }
            observers[id] = .summaries(continuation, last: summaries)
            continuation.yield(summaries)
        case .deck(let deckID, let continuation, let last):
            let deck = decks[deckID]
            guard last == nil || last! != deck else { return }
            observers[id] = .deck(deckID, continuation, last: .some(deck))
            continuation.yield(deck)
        case nil:
            break
        }
    }
}
