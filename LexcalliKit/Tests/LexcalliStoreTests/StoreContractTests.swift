import Foundation
import LexcalliCore
import Synchronization
import Testing

/// Each test runs once per `StoreKind`.
@Suite struct StoreContractTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    let deck = Deck(
        name: "German",
        termLanguage: .init(identifier: "de"),
        meaningLanguage: .init(identifier: "en"),
        notes: [
            Note(term: "der Baum", meaning: "tree"),
            Note(term: "die Blume", meaning: "flower"),
        ]
    )

    @Test(arguments: StoreKind.allCases)
    func observesDeckSummaries(_ kind: StoreKind) async throws {
        let store = try kind.make()
        var summaries = store.deckSummaries().makeAsyncIterator()

        #expect(try await summaries.next() == [])

        try await store.save(deck, at: now)
        #expect(try await summaries.next() == [DeckSummary(deck)])

        var renamed = deck
        renamed.name = "Deutsch"
        try await store.save(renamed, at: now)
        #expect(try await summaries.next()?.map(\.name) == ["Deutsch"])
    }

    @Test(arguments: StoreKind.allCases)
    func summaryCountsCardsStudiedInEndedSessions(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        var summaries = store.deckSummaries().makeAsyncIterator()
        let fresh = try #require(try await summaries.next()?.first)
        #expect(fresh.cardCount == 4 && fresh.studiedCardCount == 0)

        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        _ = try await store.record(event(opened.queue[0], .good, in: opened.session, at: now))
        _ = try await store.endSession(opened.session.id, at: now)

        #expect(try await summaries.next()?.first?.studiedCardCount == 1)
    }

    @Test(arguments: StoreKind.allCases)
    func observesOneDeckWithoutUnrelatedChanges(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        var observed = store.deck(deck.id).makeAsyncIterator()
        #expect(try await observed.next() == deck)

        // Another deck's change doesn't reach this observer.
        let other = Deck(name: "Other", termLanguage: .init(identifier: "fr"), meaningLanguage: .init(identifier: "en"))
        try await store.save(other, at: now)
        var updated = deck
        updated.notes.append(Note(term: "der Vogel", meaning: "bird"))
        try await store.save(updated, at: now)

        #expect(try await observed.next() == updated)
    }

    @Test(arguments: StoreKind.allCases)
    func concurrentSavesReachObserversInCommitOrder(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let received = Mutex<[String]>([])
        let observer = Task {
            for try await summaries in store.deckSummaries() {
                received.withLock { $0.append(summaries.first?.name ?? "") }
            }
        }
        defer { observer.cancel() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                var renamed = deck
                renamed.name = "Deck \(index)"
                group.addTask { try await store.save(renamed, at: now) }
            }
            try await group.waitForAll()
        }
        var fresh = store.deckSummaries().makeAsyncIterator()
        let committed = try #require(try await fresh.next()?.first?.name)

        // The last value received is the last committed, not an earlier one delivered late.
        try await kind.waitUntil { received.withLock { $0.last } == committed }
        try await Task.sleep(for: .milliseconds(100))
        #expect(received.withLock { $0.last } == committed)
    }

    @Test(arguments: StoreKind.allCases)
    func notesKeepTheirOrderAndMediaAndCanMoveToAnotherDeck(_ kind: StoreKind) async throws {
        let store = try kind.make()
        var original = deck
        original.notes[1].image = MediaReference(hash: "ab12", filename: "blume.jpg")
        // Saved order, not filename order.
        original.notes[1].audio = [
            MediaReference(hash: "cd34", filename: "b.m4a"), MediaReference(hash: "ef56", filename: "a.m4a"),
        ]
        try await store.save(original, at: now)
        var saved = store.deck(original.id).makeAsyncIterator()
        #expect(try await saved.next() == original)

        let other = Deck(
            name: "Other", termLanguage: .init(identifier: "de"), meaningLanguage: .init(identifier: "en"),
            notes: [original.notes[0]])
        try await store.save(other, at: now)
        var remaining = original
        remaining.notes.removeFirst()
        var left = store.deck(original.id).makeAsyncIterator()
        var moved = store.deck(other.id).makeAsyncIterator()
        #expect(try await left.next() == remaining)
        #expect(try await moved.next() == other)
    }

    @Test(arguments: StoreKind.allCases)
    func missingDeckIsNil(_ kind: StoreKind) async throws {
        let store = try kind.make()
        var observed = store.deck(UUID()).makeAsyncIterator()

        #expect(try await observed.next() == .some(nil))
    }

    @Test(arguments: StoreKind.allCases)
    func cancellingObservationReleasesIt(_ kind: StoreKind) async throws {
        let store = try kind.make()
        let task = Task {
            for try await _ in store.deckSummaries() {}
        }
        try await kind.waitUntil { store.activeObservations == 1 }

        task.cancel()
        try await kind.waitUntil { store.activeObservations == 0 }
    }

    @Test(arguments: StoreKind.allCases)
    func savingKeepsExistingScheduling(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let card = deck.notes[0].cards[0].id
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        _ = try await store.record(event(card, .good, in: opened.session, at: now))
        _ = try await store.endSession(opened.session.id, at: now)
        let projected = try await store.projection(of: card)

        try await store.save(deck, at: now.addingTimeInterval(100))

        #expect(try await store.projection(of: card) == projected)
    }

    @Test(arguments: StoreKind.allCases)
    func queueHasOneDueCardPerNote(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)

        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)

        #expect(opened.session.status == .open)
        #expect(Set(opened.queue.map(\.noteID)) == Set(deck.notes.map(\.id)))
        #expect(opened.queue.count == deck.notes.count)
        #expect(opened.recovered == ProjectionReport())
    }

    @Test(arguments: StoreKind.allCases)
    func retryRecordsOnce(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        let answer = event(opened.queue[0], .good, in: opened.session, at: now)

        #expect(try await store.record(answer) == .recorded)
        #expect(try await store.record(answer) == .alreadyRecorded)
        #expect(try await store.reviewEvents(of: answer.cardID) == [answer])
    }

    @Test(arguments: StoreKind.allCases)
    func reusedKeyWithOtherContentIsRejected(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        let answer = event(opened.queue[0], .good, in: opened.session, at: now)
        _ = try await store.record(answer)

        let conflicting = CardReviewEvent(
            idempotencyKey: answer.idempotencyKey, sessionID: answer.sessionID, cardID: answer.cardID, rating: .again,
            answeredAt: answer.answeredAt)
        await #expect(throws: ReviewStoreError.idempotencyConflict(answer.idempotencyKey)) {
            try await store.record(conflicting)
        }
        #expect(try await store.reviewEvents(of: answer.cardID) == [answer])
    }

    @Test(arguments: StoreKind.allCases)
    func recordingIsValidated(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let other = Deck(
            name: "Other", termLanguage: .init(identifier: "fr"), meaningLanguage: .init(identifier: "en"),
            notes: [Note(term: "l'arbre", meaning: "tree")])
        try await store.save(other, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)

        let foreignCard = other.notes[0].cards[0].id
        await #expect(throws: ReviewStoreError.cardNotInSessionDeck(foreignCard)) {
            try await store.record(event(foreignCard, .good, in: opened.session, at: now))
        }
        let unknownCard = Card.ID(noteID: UUID(), direction: .forward)
        await #expect(throws: ReviewStoreError.unknownCard(unknownCard)) {
            try await store.record(event(unknownCard, .good, in: opened.session, at: now))
        }
        let unknownSession = PracticeSession(deckID: deck.id, openedAt: now)
        await #expect(throws: ReviewStoreError.unknownSession(unknownSession.id)) {
            try await store.record(event(opened.queue[0], .good, in: unknownSession, at: now))
        }

        _ = try await store.endSession(opened.session.id, at: now)
        await #expect(throws: ReviewStoreError.sessionNotOpen(opened.session.id)) {
            try await store.record(event(opened.queue[0], .good, in: opened.session, at: now))
        }
        #expect(try await store.reviewEvents(of: opened.queue[0]).isEmpty)
    }

    @Test(arguments: StoreKind.allCases)
    func retryAfterLostAcknowledgementOfLastAnswerSucceedsEvenOnceEnded(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        let answer = event(opened.queue[0], .good, in: opened.session, at: now)
        _ = try await store.record(answer)
        _ = try await store.endSession(opened.session.id, at: now)

        #expect(try await store.record(answer) == .alreadyRecorded)
    }

    @Test(arguments: StoreKind.allCases)
    func recordingDoesNotChangeScheduling(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        let card = opened.queue[0]
        let before = try await store.projection(of: card)

        _ = try await store.record(event(card, .easy, in: opened.session, at: now))

        #expect(try await store.projection(of: card) == before)
    }

    @Test(arguments: StoreKind.allCases)
    func endingProjectsOnce(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let opened = try await store.openSession(UUID(), deck: deck.id, at: now)
        let card = opened.queue[0]
        _ = try await store.record(event(card, .good, in: opened.session, at: now))

        let report = try await store.endSession(opened.session.id, at: now.addingTimeInterval(5))
        let projected = try #require(try await store.projection(of: card))

        #expect(report == ProjectionReport(endedSessions: [opened.session.id], projectedCards: [card]))
        #expect(projected.scheduling.reps == 1)
        #expect(projected.scheduling.due > now)
        #expect(try await store.session(opened.session.id)?.endedAt == now.addingTimeInterval(5))

        #expect(try await store.endSession(opened.session.id, at: now.addingTimeInterval(9)) == ProjectionReport())
        #expect(try await store.projection(of: card) == projected)
        #expect(try await store.session(opened.session.id)?.endedAt == now.addingTimeInterval(5))
    }

    @Test(arguments: StoreKind.allCases)
    func openingEndsSessionLeftOpenBeforeBuildingQueue(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let interrupted = try await store.openSession(UUID(), deck: deck.id, at: now)
        let card = interrupted.queue[0]
        _ = try await store.record(event(card, .easy, in: interrupted.session, at: now))

        // Terminated before Finish.
        let later = now.addingTimeInterval(60)
        let next = try await store.openSession(UUID(), deck: deck.id, at: later)

        #expect(next.recovered == ProjectionReport(endedSessions: [interrupted.session.id], projectedCards: [card]))
        #expect(try await store.session(interrupted.session.id)?.status == .ended)
        #expect(try await store.projection(of: card)?.scheduling.reps == 1)
        #expect(!next.queue.contains(card))
        // The answered note's other direction is due now.
        #expect(
            next.queue.contains(
                Card.ID(noteID: card.noteID, direction: card.direction == .forward ? .reverse : .forward)))
    }

    @Test(arguments: StoreKind.allCases)
    func retriedOpenReturnsSameSessionWithoutAnsweredCards(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let id = UUID()
        let opened = try await store.openSession(id, deck: deck.id, at: now)
        _ = try await store.record(event(opened.queue[0], .good, in: opened.session, at: now))

        let retried = try await store.openSession(id, deck: deck.id, at: now)

        #expect(retried.session == opened.session)
        #expect(retried.queue == Array(opened.queue.dropFirst()))
        #expect(retried.recovered == ProjectionReport())
        #expect(try await store.projection(of: opened.queue[0])?.scheduling.reps == 0)
    }

    @Test(arguments: StoreKind.allCases)
    func endedRepairsSurviveNewAndRetriedSessionsUntilRecalculated(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let first = try await store.openSession(UUID(), deck: deck.id, at: now)
        let card = first.queue[0]
        _ = try await store.record(event(card, .good, in: first.session, at: now))
        _ = try await store.endSession(first.session.id, at: now)
        let before = try #require(try await store.projection(of: card))

        let second = try await store.openSession(UUID(), deck: deck.id, at: now.addingTimeInterval(120))
        _ = try await store.record(event(card, .hard, in: second.session, at: now.addingTimeInterval(-60)))
        let failed = try await store.endSession(second.session.id, at: now.addingTimeInterval(130))
        #expect(failed.needsRecalculation == [card])
        #expect(try await store.session(second.session.id)?.status == .ended)
        #expect(try await store.projection(of: card) == before)

        let id = UUID()
        let next = try await store.openSession(id, deck: deck.id, at: now.addingTimeInterval(180))
        #expect(next.recovered.needsRecalculation == [card])
        #expect(!next.queue.contains(card))
        let retried = try await store.openSession(id, deck: deck.id, at: now.addingTimeInterval(180))
        #expect(retried.recovered.needsRecalculation == [card])
        #expect(retried.queue == next.queue)

        let rebuilt = try await store.recalculate(card)
        #expect(rebuilt.checkpoint?.eventCount == 2)
        #expect(rebuilt.scheduling.reps == 2)
        let repaired = try await store.openSession(id, deck: deck.id, at: now.addingTimeInterval(180))
        #expect(repaired.recovered == ProjectionReport())
    }

    @Test(arguments: StoreKind.allCases)
    func recalculationMatchesIncrementalProjection(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.save(deck, at: now)
        let card = deck.notes[0].cards[0].id
        for (day, rating) in [(0.0, Rating.good), (1, .again), (2, .good)] {
            let at = now.addingTimeInterval(day * 86_400)
            let opened = try await store.openSession(UUID(), deck: deck.id, at: at)
            _ = try await store.record(event(card, rating, in: opened.session, at: at))
            _ = try await store.endSession(opened.session.id, at: at)
        }
        let incremental = try await store.projection(of: card)

        #expect(try await store.recalculate(card) == incremental)
        #expect(incremental?.scheduling.reps == 3)
    }

    @Test(arguments: StoreKind.allCases)
    func unknownDeckAndSessionAreReported(_ kind: StoreKind) async throws {
        let store = try kind.make()
        let deckID = UUID()
        let sessionID = UUID()

        await #expect(throws: ReviewStoreError.unknownDeck(deckID)) {
            try await store.openSession(UUID(), deck: deckID, at: now)
        }
        await #expect(throws: ReviewStoreError.unknownSession(sessionID)) {
            try await store.endSession(sessionID, at: now)
        }
    }

    private func event(_ card: Card.ID, _ rating: Rating, in session: PracticeSession, at date: Date) -> CardReviewEvent
    {
        CardReviewEvent(sessionID: session.id, cardID: card, rating: rating, answeredAt: date)
    }
}
