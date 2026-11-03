import Foundation

/// Raw values are stored in exercise history; do not rename them.
public enum ExerciseKind: String, Codable, Hashable, Sendable {
    case flashcard = "flashcard"
    case writing = "writing"
    case pickOne = "pickOne"
}

public enum ExercisePrompt: Hashable, Sendable {
    case flashcard(Card.ID)
    case writing(WritingPrompt)
    case pickOne(PickOnePrompt)

    public var kind: ExerciseKind {
        switch self {
        case .flashcard: .flashcard
        case .writing: .writing
        case .pickOne: .pickOne
        }
    }
}

public enum ExerciseResponse: Hashable, Sendable {
    case flashcard(Rating)
    case writing(String)
    case pickOne(Note.ID)
}

public enum ExerciseFeedback: Hashable, Sendable {
    /// A flashcard rating is the learner's self-assessment, not an automatic grade.
    case flashcard(Rating)
    case writing([WritingComparison.Part])
    case pickOne(selected: Note.ID, correct: Note.ID)
}

/// Strategies generate a frozen prompt and interpret only their own response type.
public protocol ExerciseStrategy: Sendable {
    var kind: ExerciseKind { get }
    var version: Int { get }
    func generate<R: RandomNumberGenerator>(card: Card.ID, notes: [Note], using random: inout R) -> ExercisePrompt?
    func evaluate(_ response: ExerciseResponse, for prompt: ExercisePrompt) -> ExerciseFeedback?
}

extension WritingExercise: ExerciseStrategy {
    public var kind: ExerciseKind { .writing }
    public var version: Int { 1 }

    public func generate<R: RandomNumberGenerator>(
        card: Card.ID, notes: [Note], using random: inout R
    ) -> ExercisePrompt? {
        notes.first { $0.id == card.noteID }.flatMap { prompt(for: $0) }.map(ExercisePrompt.writing)
    }

    public func evaluate(_ response: ExerciseResponse, for prompt: ExercisePrompt) -> ExerciseFeedback? {
        guard case .writing(let text) = response, case .writing(let writing) = prompt, accepts(text) else { return nil }
        return .writing(WritingComparison.compare(expected: writing.expectedAnswer, response: text))
    }
}

extension PickOneExercise: ExerciseStrategy {
    public var kind: ExerciseKind { .pickOne }
    public var version: Int { 1 }

    public func generate<R: RandomNumberGenerator>(
        card: Card.ID, notes: [Note], using random: inout R
    ) -> ExercisePrompt? {
        self.prompt(for: card, in: notes, using: &random).map(ExercisePrompt.pickOne)
    }

    public func evaluate(_ response: ExerciseResponse, for prompt: ExercisePrompt) -> ExerciseFeedback? {
        guard case .pickOne(let selected) = response, case .pickOne(let choice) = prompt,
            choice.options.contains(where: { $0.noteID == selected })
        else { return nil }
        return .pickOne(selected: selected, correct: choice.cardID.noteID)
    }
}

public struct FlashcardExercise: ExerciseStrategy {
    public let kind: ExerciseKind = .flashcard
    public let version = 1

    public init() {}

    public func generate<R: RandomNumberGenerator>(
        card: Card.ID, notes: [Note], using random: inout R
    ) -> ExercisePrompt? {
        .flashcard(card)
    }

    public func evaluate(_ response: ExerciseResponse, for prompt: ExercisePrompt) -> ExerciseFeedback? {
        guard case .flashcard(let rating) = response, case .flashcard = prompt else { return nil }
        return .flashcard(rating)
    }
}

/// Explicit composition; the caller stores the returned prompt for its entire presentation lifetime.
public struct ExerciseEngine: Sendable {
    private let strategies: [any ExerciseStrategy]

    public init(strategies: [any ExerciseStrategy]) {
        var kinds: Set<ExerciseKind> = [.flashcard]
        self.strategies = [FlashcardExercise()] + strategies.filter { kinds.insert($0.kind).inserted }
    }

    public func generate<R: RandomNumberGenerator>(
        card: Card.ID, notes: [Note], using random: inout R
    ) -> ExercisePrompt {
        let eligible = strategies.compactMap { strategy in
            guard let prompt = strategy.generate(card: card, notes: notes, using: &random),
                prompt.kind == strategy.kind
            else { return nil as ExercisePrompt? }
            return prompt
        }
        return eligible.randomElement(using: &random) ?? .flashcard(card)
    }

    public func evaluate(_ response: ExerciseResponse, for prompt: ExercisePrompt) -> ExerciseFeedback? {
        strategies.first { $0.kind == prompt.kind }?.evaluate(response, for: prompt)
    }
}
