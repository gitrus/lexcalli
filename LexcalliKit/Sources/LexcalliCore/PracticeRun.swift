import Foundation

public struct PracticeItem: Hashable, Sendable {
    public let card: Card.ID
    public let prompt: ExercisePrompt

    public init(card: Card.ID, prompt: ExercisePrompt) {
        self.card = card
        self.prompt = prompt
    }
}

public enum PracticeRunError: Error {
    case invalidPrompt
}

/// Progress through frozen items. Saved exercise feedback stays until explicitly continued.
public struct PracticeRun: Hashable, Sendable {
    public let session: PracticeSession
    public let items: [PracticeItem]
    public private(set) var pending: PendingAttempt?
    public private(set) var feedback: ExerciseFeedback?
    public private(set) var flashcardsReviewed = 0
    public private(set) var exercisesCompleted = 0
    /// Zero-based presentation position, independent of saved attempts while feedback is visible.
    public private(set) var position = 0

    /// Existing Flashcards callers need no prompt generation.
    public init(session: PracticeSession, queue: [Card.ID]) {
        self.session = session
        self.items = queue.map { PracticeItem(card: $0, prompt: .flashcard($0)) }
    }

    /// Every mode builds its run here: the engine freezes one prompt per queued card.
    public init<R: RandomNumberGenerator>(
        opened: OpenedSession, notes: [Note], engine: ExerciseEngine, using random: inout R
    ) throws {
        let items = opened.queue.map { card in
            PracticeItem(card: card, prompt: engine.generate(card: card, notes: notes, using: &random))
        }
        try self.init(session: opened.session, items: items)
    }

    public init(session: PracticeSession, items: [PracticeItem]) throws {
        guard items.allSatisfy({ $0.card.noteID == $0.prompt.cardID.noteID }),
            session.mode == .mixed || items.allSatisfy({ $0.prompt.kind == .flashcard })
        else { throw PracticeRunError.invalidPrompt }
        self.session = session
        self.items = items
    }

    public var queue: [Card.ID] { items.map(\.card) }
    public var answeredCount: Int { flashcardsReviewed + exercisesCompleted }
    public var current: Card.ID? { position < items.count ? items[position].card : nil }
    public var currentPrompt: ExercisePrompt? { position < items.count ? items[position].prompt : nil }
    public var isComplete: Bool { current == nil }

    /// Duplicate taps or retries retain the first immutable event.
    public mutating func answer(_ rating: Rating, at date: Date, idempotencyKey: UUID = UUID()) -> CardReviewEvent? {
        if let pending {
            guard case .card(let event) = pending else { return nil }
            return event
        }
        guard feedback == nil, case .flashcard(let card) = currentPrompt else { return nil }
        let event = CardReviewEvent(
            idempotencyKey: idempotencyKey, sessionID: session.id, cardID: card, rating: rating, answeredAt: date)
        pending = .card(event)
        return event
    }

    public mutating func answerExercise(
        _ response: ExerciseResponse, at date: Date, idempotencyKey: UUID = UUID()
    ) -> ExerciseEvent? {
        if let pending {
            guard case .exercise(let event) = pending else { return nil }
            return event
        }
        guard feedback == nil, session.mode == .mixed, let prompt = currentPrompt,
            let attempt = ExerciseAttempt(prompt: prompt, response: response)
        else { return nil }
        let event = ExerciseEvent(
            idempotencyKey: idempotencyKey, sessionID: session.id, answeredAt: date, attempt: attempt)
        pending = .exercise(event)
        return event
    }

    /// Card reviews advance immediately. New exercises acknowledge durability without hiding feedback.
    @discardableResult
    public mutating func acknowledge(_ idempotencyKey: UUID) -> Bool {
        guard let pending, pending.id == idempotencyKey else { return false }
        self.pending = nil
        switch pending {
        case .card:
            flashcardsReviewed += 1
            position += 1
        case .exercise(let event):
            exercisesCompleted += 1
            feedback = event.attempt.feedback
        }
        return true
    }

    @discardableResult
    public mutating func continueAfterFeedback() -> Bool {
        guard feedback != nil, pending == nil else { return false }
        feedback = nil
        position += 1
        return true
    }
}
