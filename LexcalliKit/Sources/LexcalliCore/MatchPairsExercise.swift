import Foundation

/// One displayed item of a Match pairs column and the note it was taken from.
public struct MatchPairsItem: Hashable, Sendable {
    public let noteID: Note.ID
    public let text: String

    public init(noteID: Note.ID, text: String) {
        self.noteID = noteID
        self.text = text
    }
}

/// Left items are the card's prompt side, right items its answer side; each column is in display order.
/// The queued card is the target; the other notes are companions, shown but not assessed.
public struct MatchPairsPrompt: Hashable, Sendable {
    public let cardID: Card.ID
    public let left: [MatchPairsItem]
    public let right: [MatchPairsItem]

    public init(cardID: Card.ID, left: [MatchPairsItem], right: [MatchPairsItem]) {
        self.cardID = cardID
        self.left = left
        self.right = right
    }

    /// Shared by generation and persistence: every item has exactly one partner, taken from the same note.
    public var isWellFormed: Bool {
        let notes = left.map(\.noteID)
        return left.count >= 2 && Set(notes).count == notes.count
            && Set(notes) == Set(right.map(\.noteID)) && right.count == left.count
            && notes.contains(cardID.noteID)
            && Self.hasDistinctText(left) && Self.hasDistinctText(right)
    }

    /// A complete one-to-one pairing from left to right items, each identified by its note.
    public func accepts(_ pairing: [Note.ID: Note.ID]) -> Bool {
        Set(pairing.keys) == Set(left.map(\.noteID)) && Set(pairing.values) == Set(right.map(\.noteID))
            && pairing.count == right.count
    }

    private static func hasDistinctText(_ items: [MatchPairsItem]) -> Bool {
        let texts = items.map { normalizedChoiceText($0.text) }
        return !texts.contains("") && Set(texts).count == texts.count
    }
}

/// Evaluated feedback, separate from the persisted prompt and response.
public struct MatchPairsEvaluation: Hashable, Sendable {
    public let pairing: [Note.ID: Note.ID]
    /// Left items paired with the right item from the same note.
    public let correct: Set<Note.ID>
    /// Only the queued card is the target; companion results do not change this value.
    public let targetCorrect: Bool

    init(prompt: MatchPairsPrompt, pairing: [Note.ID: Note.ID]) {
        self.pairing = pairing
        correct = Set(prompt.left.filter { pairing[$0.noteID] == $0.noteID }.map(\.noteID))
        targetCorrect = correct.contains(prompt.cardID.noteID)
    }
}

public struct MatchPairsExercise: Sendable {
    public let pairCount: Int
    private let stages: [ChoiceStage]

    /// Fewer than two pairs leave nothing to match.
    public init?(pairCount: Int = 4, stages: [ChoiceStage] = [.similarity]) {
        guard pairCount >= 2 else { return nil }
        self.pairCount = pairCount
        self.stages = stages
    }

    /// `notes` is the current deck. Companions are chosen like Pick-one distractors, in the card's direction.
    public func prompt<R: RandomNumberGenerator>(
        for cardID: Card.ID, in notes: [Note], using random: inout R
    ) -> MatchPairsPrompt? {
        guard let targetNote = notes.first(where: { $0.id == cardID.noteID }) else { return nil }
        let target = ChoiceCandidate(targetNote, direction: cardID.direction)
        guard !isBlank(target.prompt), !isBlank(target.answer) else { return nil }
        let valid = notes.filter { $0.id != target.noteID }.map { ChoiceCandidate($0, direction: cardID.direction) }
            .filter { !isBlank($0.prompt) && !isBlank($0.answer) }
        let allowed = Set(valid)
        var candidates = valid.shuffled(using: &random)
        for stage in stages { candidates = stage.apply(candidates, target: target) }

        // Both columns must stay unambiguous, whatever the stages return.
        var prompts = Set([normalizedChoiceText(target.prompt)])
        var answers = Set([normalizedChoiceText(target.answer)])
        let companions = candidates.filter { candidate in
            guard allowed.contains(candidate), !prompts.contains(normalizedChoiceText(candidate.prompt)),
                answers.insert(normalizedChoiceText(candidate.answer)).inserted
            else { return false }
            prompts.insert(normalizedChoiceText(candidate.prompt))
            return true
        }
        guard companions.count >= pairCount - 1 else { return nil }
        let pairs = companions.prefix(pairCount - 1) + [target]
        let prompt = MatchPairsPrompt(
            cardID: cardID,
            left: pairs.map { MatchPairsItem(noteID: $0.noteID, text: $0.prompt) }.shuffled(using: &random),
            right: pairs.map { MatchPairsItem(noteID: $0.noteID, text: $0.answer) }.shuffled(using: &random))
        return prompt.isWellFormed ? prompt : nil
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
