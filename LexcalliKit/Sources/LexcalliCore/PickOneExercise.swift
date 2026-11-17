import Foundation

/// A displayed answer and the note from which it was taken.
public struct PickOneOption: Hashable, Sendable {
    public let noteID: Note.ID
    public let answer: String

    public init(noteID: Note.ID, answer: String) {
        self.noteID = noteID
        self.answer = answer
    }
}

public struct PickOnePrompt: Hashable, Sendable {
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

    /// Shared by generation and persistence, so a generated prompt cannot drift from write validation.
    public var isWellFormed: Bool {
        let answers = options.map { normalizedChoiceText($0.answer) }
        return !normalizedChoiceText(question).isEmpty && options.count >= 2
            && Set(answers).count == answers.count && !answers.contains("")
            && Set(options.map(\.noteID)).count == options.count
            && options.filter { $0.noteID == cardID.noteID && $0.answer == expectedAnswer }.count == 1
    }
}

public struct PickOneExercise: Sendable {
    public let optionCount: Int
    private let stages: [ChoiceStage]

    /// Invalid counts cannot produce a usable choice exercise.
    public init?(optionCount: Int = 4, stages: [ChoiceStage] = [.similarity]) {
        guard optionCount >= 2 else { return nil }
        self.optionCount = optionCount
        self.stages = stages
    }

    /// `notes` is the current deck. The target must be present and match the queued card.
    public func prompt<R: RandomNumberGenerator>(
        for cardID: Card.ID, in notes: [Note], using random: inout R
    ) -> PickOnePrompt? {
        guard let targetNote = notes.first(where: { $0.id == cardID.noteID }) else { return nil }
        let target = ChoiceCandidate(targetNote, direction: cardID.direction)
        guard !isBlank(target.prompt), !isBlank(target.answer) else { return nil }
        let targetPrompt = normalizedChoiceText(target.prompt)
        let valid = notes.filter { $0.id != target.noteID }.map { ChoiceCandidate($0, direction: cardID.direction) }
            .filter { !isBlank($0.answer) && normalizedChoiceText($0.prompt) != targetPrompt }
        let allowed = Set(valid)
        var candidates = valid.shuffled(using: &random)
        for stage in stages { candidates = stage.apply(candidates, target: target) }

        // Even custom stages cannot inject another deck, duplicate options or the target.
        var seen = Set([normalizedChoiceText(target.answer)])
        let distractors = candidates.filter {
            allowed.contains($0) && seen.insert(normalizedChoiceText($0.answer)).inserted
        }
        guard distractors.count >= optionCount - 1 else { return nil }
        var options = distractors.prefix(optionCount - 1).map { PickOneOption(noteID: $0.noteID, answer: $0.answer) }
        options.append(PickOneOption(noteID: target.noteID, answer: target.answer))
        options.shuffle(using: &random)
        let prompt = PickOnePrompt(
            cardID: cardID, question: target.prompt, expectedAnswer: target.answer, options: options)
        return prompt.isWellFormed ? prompt : nil
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
