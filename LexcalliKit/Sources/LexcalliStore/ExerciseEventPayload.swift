import Foundation
import LexcalliCore

/// The stored JSON of one exercise event, mapped to and from the domain like the other records.
/// Key names are the persisted contract, spelled out rather than derived from domain property names.
/// A format change adds a version and a mapping; it never renames a key.
struct ExerciseEventPayload: Codable {
    static let version = 1

    var idempotencyKey: UUID
    var sessionID: UUID
    var version: Int
    var answeredAt: Date
    var attempt: Attempt

    enum CodingKeys: String, CodingKey {
        case idempotencyKey, sessionID, version, answeredAt, attempt
    }

    enum Attempt: Codable {
        case writing(prompt: Writing, response: String)
        case pickOne(prompt: PickOne, selected: UUID)

        enum CodingKeys: String, CodingKey { case writing, pickOne }
        enum WritingCodingKeys: String, CodingKey { case prompt, response }
        enum PickOneCodingKeys: String, CodingKey { case prompt, selected }
    }

    struct CardReference: Codable {
        var noteID: UUID
        var direction: Int

        enum CodingKeys: String, CodingKey { case noteID, direction }
    }

    struct Writing: Codable {
        var cardID: CardReference
        var question: String
        var expectedAnswer: String

        enum CodingKeys: String, CodingKey { case cardID, question, expectedAnswer }
    }

    struct PickOne: Codable {
        var cardID: CardReference
        var question: String
        var expectedAnswer: String
        var options: [Option]

        enum CodingKeys: String, CodingKey { case cardID, question, expectedAnswer, options }
    }

    struct Option: Codable {
        var noteID: UUID
        var answer: String

        enum CodingKeys: String, CodingKey { case noteID, answer }
    }
}

extension ExerciseEventPayload {
    init(_ event: ExerciseEvent) {
        let attempt: Attempt =
            switch event.attempt {
            case .writing(let prompt, let response):
                .writing(
                    prompt: Writing(
                        cardID: CardReference(prompt.cardID), question: prompt.question,
                        expectedAnswer: prompt.expectedAnswer),
                    response: response)
            case .pickOne(let prompt, let selected):
                .pickOne(
                    prompt: PickOne(
                        cardID: CardReference(prompt.cardID), question: prompt.question,
                        expectedAnswer: prompt.expectedAnswer,
                        options: prompt.options.map { Option(noteID: $0.noteID, answer: $0.answer) }),
                    selected: selected)
            }
        self.init(
            idempotencyKey: event.idempotencyKey, sessionID: event.sessionID, version: Self.version,
            answeredAt: event.answeredAt, attempt: attempt)
    }

    /// Sorted keys make equal events equal bytes, so an idempotent retry compares exactly what was stored.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// A newer version or an unreadable row is reported, never trapped on.
    static func event(from data: Data) throws -> ExerciseEvent {
        // The version is read first, so a future format isn't misreported as corruption.
        struct Header: Decodable { var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw StoreError.corruptRow("exercise_event")
        }
        guard header.version == version else { throw StoreError.unsupportedPayloadVersion(header.version) }
        guard let payload = try? JSONDecoder().decode(Self.self, from: data), let event = payload.event else {
            throw StoreError.corruptRow("exercise_event")
        }
        return event
    }

    private var event: ExerciseEvent? {
        let mapped: ExerciseAttempt
        switch attempt {
        case .writing(let prompt, let response):
            guard let card = prompt.cardID.domain else { return nil }
            mapped = .writing(
                prompt: WritingPrompt(cardID: card, question: prompt.question, expectedAnswer: prompt.expectedAnswer),
                response: response)
        case .pickOne(let prompt, let selected):
            guard let card = prompt.cardID.domain else { return nil }
            mapped = .pickOne(
                prompt: PickOnePrompt(
                    cardID: card, question: prompt.question, expectedAnswer: prompt.expectedAnswer,
                    options: prompt.options.map { PickOneOption(noteID: $0.noteID, answer: $0.answer) }),
                selected: selected)
        }
        return ExerciseEvent(
            idempotencyKey: idempotencyKey, sessionID: sessionID, answeredAt: answeredAt, attempt: mapped)
    }
}

extension ExerciseEventPayload.CardReference {
    init(_ card: Card.ID) {
        self.init(noteID: card.noteID, direction: card.direction.rawValue)
    }

    var domain: Card.ID? {
        CardDirection(rawValue: direction).map { Card.ID(noteID: noteID, direction: $0) }
    }
}
