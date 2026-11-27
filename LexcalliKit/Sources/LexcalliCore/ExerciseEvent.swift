import Foundation

/// The exact prompt and response shown at confirmation; no writing grade is fabricated.
public enum ExerciseAttempt: Hashable, Sendable {
    case writing(prompt: WritingPrompt, response: String)
    case pickOne(prompt: PickOnePrompt, selected: Note.ID)
    case matchPairs(prompt: MatchPairsPrompt, pairing: [Note.ID: Note.ID])

    public var cardID: Card.ID {
        switch self {
        case .writing(let prompt, _): prompt.cardID
        case .pickOne(let prompt, _): prompt.cardID
        case .matchPairs(let prompt, _): prompt.cardID
        }
    }

    public var kind: ExerciseKind {
        switch self {
        case .writing: .writing
        case .pickOne: .pickOne
        case .matchPairs: .matchPairs
        }
    }

    public var feedback: ExerciseFeedback {
        switch self {
        case .writing(let prompt, let response):
            .writing(WritingComparison.compare(expected: prompt.expectedAnswer, response: response))
        case .pickOne(let prompt, let selected):
            .pickOne(selected: selected, correct: prompt.cardID.noteID)
        case .matchPairs(let prompt, let pairing):
            .matchPairs(MatchPairsEvaluation(prompt: prompt, pairing: pairing))
        }
    }

    /// Only a valid response can be frozen for persistence.
    public init?(prompt: ExercisePrompt, response: ExerciseResponse) {
        switch (prompt, response) {
        case (.writing(let prompt), .writing(let response)):
            guard WritingExercise().accepts(response) else { return nil }
            self = .writing(prompt: prompt, response: response)
        case (.pickOne(let prompt), .pickOne(let selected)):
            guard prompt.options.contains(where: { $0.noteID == selected }) else { return nil }
            self = .pickOne(prompt: prompt, selected: selected)
        case (.matchPairs(let prompt), .matchPairs(let pairing)):
            guard prompt.accepts(pairing) else { return nil }
            self = .matchPairs(prompt: prompt, pairing: pairing)
        default:
            return nil
        }
    }
}

/// Separate from card review history: recording an attempt does not schedule a card.
public struct ExerciseEvent: Identifiable, Hashable, Sendable {
    public let idempotencyKey: UUID
    public let sessionID: PracticeSession.ID
    public let version: Int
    public let answeredAt: Date
    public let attempt: ExerciseAttempt

    public var id: UUID { idempotencyKey }

    public init(
        idempotencyKey: UUID = UUID(), sessionID: PracticeSession.ID, answeredAt: Date, attempt: ExerciseAttempt
    ) {
        self.idempotencyKey = idempotencyKey
        self.sessionID = sessionID
        self.version = 1
        self.answeredAt = Date(milliseconds: answeredAt.milliseconds)
        self.attempt = attempt
    }

    /// Shared write-boundary validation. Snapshots need not equal content edited since prompt generation.
    public func validate(in session: PracticeSession, noteIDs: Set<Note.ID>) throws {
        guard session.status == .open else { throw ReviewStoreError.sessionNotOpen(session.id) }
        guard session.id == sessionID, session.mode == .mixed, version == 1 else {
            throw ReviewStoreError.invalidExercise(id)
        }
        guard noteIDs.contains(attempt.cardID.noteID) else {
            throw ReviewStoreError.cardNotInSessionDeck(attempt.cardID)
        }
        switch attempt {
        case .writing(let prompt, let response):
            guard prompt.cardID.direction == .reverse,
                WritingExercise().accepts(prompt.question), WritingExercise().accepts(prompt.expectedAnswer),
                WritingExercise().accepts(response)
            else { throw ReviewStoreError.invalidExercise(id) }
        case .pickOne(let prompt, let selected):
            guard prompt.isWellFormed,
                prompt.options.allSatisfy({ noteIDs.contains($0.noteID) }),
                prompt.options.contains(where: { $0.noteID == selected })
            else { throw ReviewStoreError.invalidExercise(id) }
        case .matchPairs(let prompt, let pairing):
            guard prompt.isWellFormed, prompt.left.allSatisfy({ noteIDs.contains($0.noteID) }),
                prompt.accepts(pairing)
            else { throw ReviewStoreError.invalidExercise(id) }
        }
    }
}
