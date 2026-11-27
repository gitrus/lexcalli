import Foundation
import LexcalliCore
import Testing

struct RoundLimitTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: StoreKind.allCases, [PracticeMode.flashcards, .mixed])
    func retriesKeepTheLimitAndOverflowStaysDue(_ kind: StoreKind, _ mode: PracticeMode) async throws {
        let store = try kind.make()
        let deck = Deck(
            name: "Round limit", termLanguage: .init(identifier: "en"), meaningLanguage: .init(identifier: "en"),
            notes: (0..<44).map { Note(term: "Term \($0)", meaning: "Meaning \($0)") })
        try await store.save(deck, at: now)
        // A saved review unlocks Mixed; the note's other direction remains due.
        let warmup = try await store.openSession(UUID(), deck: deck.id, at: now)
        _ = try await store.record(review(warmup.queue[0], in: warmup.session))
        _ = try await store.endSession(warmup.session.id, at: now)

        let opened = try await store.openSession(UUID(), deck: deck.id, mode: mode, at: now)
        #expect(opened.queue.count == 22)
        let includedNotes = Set(opened.queue.map(\.noteID))
        let skipped = try #require(deck.notes.first { !includedNotes.contains($0.id) }).cards[0].id
        let before = try await store.projection(of: skipped)

        for (index, card) in opened.queue.enumerated() {
            if mode == .mixed {
                let note = try #require(deck.notes.first { $0.id == card.noteID })
                let prompt = try #require(WritingExercise().prompt(for: note))
                _ = try await store.record(
                    ExerciseEvent(
                        sessionID: opened.session.id, answeredAt: now,
                        attempt: .writing(prompt: prompt, response: note.term)))
            } else {
                _ = try await store.record(review(card, in: opened.session))
            }
            if index == 0 {
                let retried = try await store.openSession(opened.session.id, deck: deck.id, mode: mode, at: now)
                #expect(retried.queue == Array(opened.queue.dropFirst()))
            }
        }
        let exhausted = try await store.openSession(opened.session.id, deck: deck.id, mode: mode, at: now)
        #expect(exhausted.queue.isEmpty)
        _ = try await store.endSession(opened.session.id, at: now)
        #expect(try await store.projection(of: skipped) == before)
        let next = try await store.openSession(UUID(), deck: deck.id, mode: mode, at: now)
        #expect(next.queue.count == 22)
        if mode == .mixed {
            #expect(next.queue == opened.queue)
        }
    }

    private func review(_ card: Card.ID, in session: PracticeSession) -> CardReviewEvent {
        CardReviewEvent(sessionID: session.id, cardID: card, rating: .good, answeredAt: now)
    }
}
