import Foundation

/// A candidate for a choice exercise, as a distractor or a companion pair.
public struct ChoiceCandidate: Hashable, Sendable {
    public let noteID: Note.ID
    public let prompt: String
    public let answer: String

    public init(noteID: Note.ID, prompt: String, answer: String) {
        self.noteID = noteID
        self.prompt = prompt
        self.answer = answer
    }

    /// The card's prompt and answer sides, as choice exercises show them.
    init(_ note: Note, direction: CardDirection) {
        switch direction {
        case .forward: self.init(noteID: note.id, prompt: note.term, answer: note.meaning)
        case .reverse: self.init(noteID: note.id, prompt: note.meaning, answer: note.term)
        }
    }
}

/// The pipeline may reorder or filter candidates, but each exercise validates its output independently.
public struct ChoiceStage: Sendable {
    private let transform: @Sendable ([ChoiceCandidate], ChoiceCandidate) -> [ChoiceCandidate]

    public init(
        _ transform: @escaping @Sendable ([ChoiceCandidate], ChoiceCandidate) -> [ChoiceCandidate]
    ) {
        self.transform = transform
    }

    func apply(_ candidates: [ChoiceCandidate], target: ChoiceCandidate) -> [ChoiceCandidate] {
        transform(candidates, target)
    }

    /// A stable preference; an earlier random shuffle resolves equally ranked candidates.
    public static let similarity = ChoiceStage { candidates, target in
        let targetWords = target.answer.split(whereSeparator: \.isWhitespace).count
        let targetLength = target.answer.count
        return candidates.enumerated().map { index, candidate in
            let words = candidate.answer.split(whereSeparator: \.isWhitespace).count
            return (candidate, words == targetWords ? 0 : 1, abs(candidate.answer.count - targetLength), index)
        }.sorted { left, right in
            (left.1, left.2, left.3) < (right.1, right.2, right.3)
        }.map(\.0)
    }
}

/// Shared ambiguity rules for displayed choice text; preserve accents and ignore case and edge whitespace.
func normalizedChoiceText(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .precomposedStringWithCanonicalMapping
        .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
}
