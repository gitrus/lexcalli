import Foundation

/// A writing prompt snapshots the displayed question and expected answer for a single card.
public struct WritingPrompt: Hashable, Sendable {
    public let cardID: Card.ID
    public let question: String
    public let expectedAnswer: String

    public init(cardID: Card.ID, question: String, expectedAnswer: String) {
        self.cardID = cardID
        self.question = question
        self.expectedAnswer = expectedAnswer
    }
}

/// Writing always asks for the term, regardless of the direction selected by the due queue.
public struct WritingExercise: Sendable {
    public init() {}

    public func prompt(for note: Note) -> WritingPrompt? {
        guard accepts(note.meaning), accepts(note.term) else { return nil }
        return WritingPrompt(
            cardID: Card.ID(noteID: note.id, direction: .reverse),
            question: note.meaning,
            expectedAnswer: note.term
        )
    }

    /// Reject blank input without changing the text that will be saved and compared.
    public func accepts(_ response: String) -> Bool {
        !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// An aligned comparison, not a correctness grade. Both sides retain the original text.
public enum WritingComparison {
    public enum Kind: Hashable, Sendable {
        case match
        case softDifference
        case difference
    }

    public struct Part: Hashable, Sendable {
        public let kind: Kind
        public let expected: String
        public let response: String

        public init(kind: Kind, expected: String, response: String) {
            self.kind = kind
            self.expected = expected
            self.response = response
        }
    }

    public static func compare(expected: String, response: String) -> [Part] {
        let left = Array(expected).map(String.init)
        let right = Array(response).map(String.init)
        // Edit distance gives a stable alignment and retains insertions and deletions.
        var distance = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)
        for row in 0...left.count { distance[row][0] = row * 2 }
        for column in 0...right.count { distance[0][column] = column * 2 }
        if !left.isEmpty && !right.isEmpty {
            for row in 1...left.count {
                for column in 1...right.count {
                    let cost = cost(of: kind(left[row - 1], right[column - 1]))
                    distance[row][column] = min(
                        distance[row - 1][column] + 2, distance[row][column - 1] + 2,
                        distance[row - 1][column - 1] + cost)
                }
            }
        }

        var parts: [Part] = []
        var row = left.count
        var column = right.count
        while row > 0 || column > 0 {
            if row > 0 && column > 0 {
                let difference = kind(left[row - 1], right[column - 1])
                if distance[row][column] == distance[row - 1][column - 1] + cost(of: difference) {
                    parts.append(Part(kind: difference, expected: left[row - 1], response: right[column - 1]))
                    row -= 1
                    column -= 1
                    continue
                }
            }
            if row > 0 && distance[row][column] == distance[row - 1][column] + 2 {
                parts.append(Part(kind: .difference, expected: left[row - 1], response: ""))
                row -= 1
            } else {
                parts.append(Part(kind: .difference, expected: "", response: right[column - 1]))
                column -= 1
            }
        }
        return parts.reversed()
    }

    private static func cost(of kind: Kind) -> Int {
        switch kind {
        case .match: 0
        case .softDifference: 1
        case .difference: 2
        }
    }

    private static func kind(_ expected: String, _ response: String) -> Kind {
        if expected.precomposedStringWithCanonicalMapping == response.precomposedStringWithCanonicalMapping {
            return .match
        }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let locale = Locale(identifier: "en_US_POSIX")
        if expected.folding(options: options, locale: locale) == response.folding(options: options, locale: locale) {
            return .softDifference
        }
        return .difference
    }
}
