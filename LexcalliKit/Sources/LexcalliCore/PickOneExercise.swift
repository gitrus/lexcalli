import Foundation

/// A displayed answer and the note from which it was taken.
public struct PickOneOption: Codable, Hashable, Sendable {
    public let noteID: Note.ID
    public let answer: String

    public init(noteID: Note.ID, answer: String) {
        self.noteID = noteID
        self.answer = answer
    }
}

public struct PickOnePrompt: Codable, Hashable, Sendable {
    public let cardID: Card.ID
    public let question: String
    public let expectedAnswer: String
    public let options: [PickOneOption]

    public init(cardID: Card.ID, question: String, expectedAnswer: String, options: [PickOneOption]) {
        self.cardID = cardID
        self.question = question
        self.expectedAnswer = expectedAnswer
        self.options = options
    }
}

/// The pipeline may reorder or filter candidates, but the exercise validates its output independently.
public struct DistractorCandidate: Hashable, Sendable {
    public let noteID: Note.ID
    public let prompt: String
    public let answer: String

    public init(noteID: Note.ID, prompt: String, answer: String) {
        self.noteID = noteID
        self.prompt = prompt
        self.answer = answer
    }
}

public struct DistractorStage: Sendable {
    private let transform: @Sendable ([DistractorCandidate], DistractorCandidate) -> [DistractorCandidate]

    public init(
        _ transform: @escaping @Sendable ([DistractorCandidate], DistractorCandidate) -> [DistractorCandidate]
    ) {
        self.transform = transform
    }

    func apply(_ candidates: [DistractorCandidate], target: DistractorCandidate) -> [DistractorCandidate] {
        transform(candidates, target)
    }

    /// A stable preference; an earlier random shuffle resolves equally ranked candidates.
    public static let similarity = DistractorStage { candidates, target in
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

public struct PickOneExercise: Sendable {
    public let optionCount: Int
    private let stages: [DistractorStage]

    /// Invalid counts cannot produce a usable choice exercise.
    public init?(optionCount: Int = 4, stages: [DistractorStage] = [.similarity]) {
        guard optionCount >= 2 else { return nil }
        self.optionCount = optionCount
        self.stages = stages
    }

    /// `notes` is the current deck. The target must be present and match the queued card.
    public func prompt<R: RandomNumberGenerator>(
        for cardID: Card.ID, in notes: [Note], using random: inout R
    ) -> PickOnePrompt? {
        guard let targetNote = notes.first(where: { $0.id == cardID.noteID }) else { return nil }
        let target = candidate(targetNote, direction: cardID.direction)
        guard !isBlank(target.prompt), !isBlank(target.answer) else { return nil }
        let targetPrompt = normalized(target.prompt)
        let valid = notes.filter { $0.id != target.noteID }.map { candidate($0, direction: cardID.direction) }
            .filter { !isBlank($0.answer) && normalized($0.prompt) != targetPrompt }
        let allowed = Set(valid)
        var candidates = valid.shuffled(using: &random)
        for stage in stages { candidates = stage.apply(candidates, target: target) }

        // Even custom stages cannot inject another deck, duplicate options or the target.
        var seen = Set([normalized(target.answer)])
        let distractors = candidates.filter {
            allowed.contains($0) && seen.insert(normalized($0.answer)).inserted
        }
        guard distractors.count >= optionCount - 1 else { return nil }
        var options = distractors.prefix(optionCount - 1).map { PickOneOption(noteID: $0.noteID, answer: $0.answer) }
        options.append(PickOneOption(noteID: target.noteID, answer: target.answer))
        options.shuffle(using: &random)
        return PickOnePrompt(cardID: cardID, question: target.prompt, expectedAnswer: target.answer, options: options)
    }

    private func candidate(_ note: Note, direction: CardDirection) -> DistractorCandidate {
        switch direction {
        case .forward: DistractorCandidate(noteID: note.id, prompt: note.term, answer: note.meaning)
        case .reverse: DistractorCandidate(noteID: note.id, prompt: note.meaning, answer: note.term)
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
