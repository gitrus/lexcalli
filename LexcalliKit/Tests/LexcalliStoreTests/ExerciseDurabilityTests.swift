import Foundation
import GRDB
import LexcalliCore
import Testing

@testable import LexcalliStore

struct ExerciseDurabilityTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let directory: TemporaryDirectory
    let deck = Deck(
        name: "Greek", termLanguage: .init(identifier: "el"), meaningLanguage: .init(identifier: "en"),
        notes: [
            Note(term: "λέξη", meaning: "word", image: MediaReference(hash: "image", filename: "word.jpg")),
            Note(term: "δέντρο", meaning: "tree", audio: [MediaReference(hash: "audio", filename: "tree.m4a")]),
        ])

    init() throws { directory = try TemporaryDirectory() }
    var url: URL { directory.url.appending(path: "Lexcalli.sqlite") }

    @Test func realV1MigrationPreservesContentHistorySchedulingAndBackup() async throws {
        let original = try DatabaseStore.open(at: url, migrator: .v1Fixture)
        try await original.save(deck, at: now)
        let session = UUID()
        let card = deck.notes[0].cards[0].id
        let event = CardReviewEvent(sessionID: session, cardID: card, rating: .good, answeredAt: now)
        try await original.writer.write { database in
            try database.execute(
                sql: "INSERT INTO practice_session (id, deck_id, opened_at, ended_at) VALUES (?, ?, ?, ?)",
                arguments: [session, deck.id, now.milliseconds, now.milliseconds])
            try CardReviewEventRecord(event).insert(database)
            _ = try DatabaseStore.project([card], projector: Projector(), database)
        }
        let projection = try await original.projection(of: card)
        try original.close()

        let upgraded = try DatabaseStore.open(at: url)
        var content = upgraded.deck(deck.id).makeAsyncIterator()
        #expect(try await content.next() == deck)
        #expect(try await upgraded.reviewEvents(of: card) == [event])
        #expect(try await upgraded.projection(of: card) == projection)
        #expect(try await upgraded.session(session)?.mode == .flashcards)
        var summaries = upgraded.deckSummaries().makeAsyncIterator()
        #expect(try await summaries.next()?.first { $0.id == deck.id }?.hasCardReviews == true)
        let mixed = try await upgraded.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        #expect(mixed.session.mode == .mixed)
        let backup = try DatabaseQueue(path: DatabaseStore.snapshotURL(for: url).path())
        #expect(try await backup.read { try $0.tableExists("exercise_event") } == false)
        #expect(
            try await backup.read { try $0.columns(in: "practice_session").contains { $0.name == "mode" } } == false)
        #expect(try await backup.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM card_review_event") } == 1)
        try backup.close()
        try upgraded.close()
    }

    @Test func failedRealMigrationLeavesV1AndBackupUntouched() async throws {
        let original = try DatabaseStore.open(at: url, migrator: .v1Fixture)
        try await original.save(deck, at: now)
        // A conflicting object makes the actual v2 migration fail after ALTER TABLE, inside the copy.
        try await original.writer.write { try $0.create(table: "exercise_event") { $0.column("collision") } }
        try original.close()
        #expect {
            try DatabaseStore.open(at: url)
        } throws: { error in
            guard case StoreOpenError.migrationFailed = error else { return false }
            return true
        }
        for file in [url, DatabaseStore.snapshotURL(for: url)] {
            let database = try DatabaseQueue(path: file.path())
            #expect(
                try await database.read { try $0.columns(in: "practice_session").contains { $0.name == "mode" } }
                    == false)
            #expect(
                try await database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM note") } == deck.notes.count)
            try database.close()
        }
    }

    @Test func exerciseSnapshotsAndUnlockSurviveRecoveryWithoutSchedulingCredit() async throws {
        let store = try DatabaseStore.open(at: url)
        try await store.save(deck, at: now)
        let first = try await store.openSession(UUID(), deck: deck.id, at: now)
        _ = try await store.record(
            CardReviewEvent(
                sessionID: first.session.id, cardID: first.queue[0], rating: .good, answeredAt: now))
        let mixed = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        var before: [Card.ID: CardProjection] = [:]
        var history: [Card.ID: [CardReviewEvent]] = [:]
        for card in deck.notes.flatMap(\.cards) {
            before[card.id] = try await store.projection(of: card.id)
            history[card.id] = try await store.reviewEvents(of: card.id)
        }
        let prompt = try #require(WritingExercise().prompt(for: deck.notes[0]))
        let event = ExerciseEvent(
            sessionID: mixed.session.id, answeredAt: now, attempt: .writing(prompt: prompt, response: "  λεξη "))
        _ = try await store.record(event)
        let choice = PickOnePrompt(
            cardID: deck.notes[1].cards[0].id, question: deck.notes[1].term, expectedAnswer: deck.notes[1].meaning,
            options: deck.notes.map { PickOneOption(noteID: $0.id, answer: $0.meaning) })
        let choiceEvent = ExerciseEvent(
            sessionID: mixed.session.id, answeredAt: now.addingTimeInterval(1),
            attempt: .pickOne(prompt: choice, selected: deck.notes[0].id))
        _ = try await store.record(choiceEvent)
        var changed = deck
        changed.notes[0].term = "edited after confirmation"
        try await store.save(changed, at: now)
        try store.close()

        let reopened = try DatabaseStore.open(at: url)
        #expect(try await reopened.exerciseEvents(in: mixed.session.id) == [event, choiceEvent])
        var summaries = reopened.deckSummaries().makeAsyncIterator()
        #expect(try await summaries.next()?.first { $0.id == deck.id }?.hasCardReviews == true)
        let recovery = try await reopened.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        #expect(recovery.recovered.endedSessions == [mixed.session.id])
        #expect(recovery.recovered.projectedCards.isEmpty && !recovery.recovered.needsRepair)
        #expect(try await reopened.record(event) == .alreadyRecorded)
        for card in deck.notes.flatMap(\.cards) {
            #expect(try await reopened.projection(of: card.id) == before[card.id])
            #expect(try await reopened.reviewEvents(of: card.id) == history[card.id])
        }
        try reopened.close()
    }
}
