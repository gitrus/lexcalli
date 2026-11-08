#if DEBUG
    import Foundation
    import LexcalliCore

    /// Deterministic test dependencies, restricted to isolated UITest libraries; never learner settings.
    nonisolated enum ExerciseUITestFixture: String {
        case writing, writingLatin, pickOne, smallDeck

        private var isWriting: Bool { self == .writing || self == .writingLatin }

        /// Mixed offers only the fixture's exercise type, so a journey never depends on random choice.
        var exerciseEngines: ExerciseEnginesByMode {
            let mixed: [any ExerciseStrategy] = isWriting ? [WritingExercise()] : PickOneExercise().map { [$0] } ?? []
            return ExerciseEnginesByMode([.flashcards: [FlashcardExercise()], .mixed: mixed])
        }

        func seedIfEmpty(_ library: Library) async throws {
            var summaries = library.decks.deckSummaries().makeAsyncIterator()
            guard try await summaries.next()?.isEmpty ?? true else { return }
            let notes = zip(["Haus", "Baum", "Blume", "Vogel"], ["house", "tree", "flower", "bird"])
                .enumerated().map { index, pair in
                    Note(
                        id: UUID(uuidString: "6A3B6C1E-0D2F-4E11-9C1A-00000000010\(index)")!,
                        term: pair.0, meaning: pair.1)
                }
            let writing = Note(
                id: notes[0].id,
                term: self == .writing ? "πώς σε λένε;" : "A long phrase with several words and punctuation;",
                meaning: self == .writing ? "what is your name?" : "Write this long phrase")
            let deck = Deck(
                id: UUID(uuidString: "6A3B6C1E-0D2F-4E11-9C1A-000000000001")!, name: "Exercise Fixture",
                termLanguage: .init(identifier: isWriting ? (self == .writing ? "el" : "en") : "de"),
                meaningLanguage: .init(identifier: "en"),
                notes: isWriting ? [writing] : self == .smallDeck ? [notes[0]] : notes)
            let date = Date.now.addingTimeInterval(-60)
            try await library.decks.save(deck, at: date)
            let opened = try await library.reviews.openSession(UUID(), deck: deck.id, at: date)
            // Unlock through a real saved card event; leave the first forward card due.
            _ = try await library.reviews.record(
                CardReviewEvent(
                    sessionID: opened.session.id, cardID: Card.ID(noteID: deck.notes[0].id, direction: .reverse),
                    rating: .good, answeredAt: date))
            _ = try await library.reviews.endSession(opened.session.id, at: date)
        }
    }

    /// Simulates a committed write whose acknowledgement was lost, not an alternative store implementation.
    actor LostExerciseAcknowledgement: ReviewStore {
        let base: any ReviewStore
        private var didFail = false
        init(base: any ReviewStore) { self.base = base }

        func record(_ event: ExerciseEvent) async throws -> RecordOutcome {
            let outcome = try await base.record(event)
            if !didFail {
                didFail = true
                throw CocoaError(.fileWriteUnknown)
            }
            return outcome
        }
        func record(_ event: CardReviewEvent) async throws -> RecordOutcome { try await base.record(event) }
        func openSession(_ id: PracticeSession.ID, deck: Deck.ID, mode: PracticeMode, at date: Date) async throws
            -> OpenedSession
        {
            try await base.openSession(id, deck: deck, mode: mode, at: date)
        }
        func endSession(_ id: PracticeSession.ID, at date: Date) async throws -> ProjectionReport {
            try await base.endSession(id, at: date)
        }
        func exerciseEvents(in session: PracticeSession.ID) async throws -> [ExerciseEvent] {
            try await base.exerciseEvents(in: session)
        }
        func session(_ id: PracticeSession.ID) async throws -> PracticeSession? { try await base.session(id) }
        func projection(of card: Card.ID) async throws -> CardProjection? { try await base.projection(of: card) }
        func reviewEvents(of card: Card.ID) async throws -> [CardReviewEvent] { try await base.reviewEvents(of: card) }
        func recalculate(_ card: Card.ID) async throws -> CardProjection { try await base.recalculate(card) }
    }
#endif
