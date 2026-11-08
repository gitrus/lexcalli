import Foundation
import Testing

@testable import LexcalliCore
@testable import LexcalliStore

/// The stored JSON is a persisted contract: rows written by the first Mixed build must keep decoding.
struct ExerciseEventPayloadTests {
    let note = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let other = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let session = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let answeredAt = Date(timeIntervalSince1970: 1_793_000_000.123)

    // Captured from version 1 rows as first shipped; never edit these strings.
    static let frozenWriting =
        #"{"answeredAt":814692800.1229999,"attempt":{"writing":{"prompt":{"cardID":{"direction":1,"noteID":"11111111-1111-1111-1111-111111111111"},"expectedAnswer":"πώς σε λένε;","question":"what is your name?"},"response":"  πως σε λενε; "}},"idempotencyKey":"44444444-4444-4444-4444-444444444444","sessionID":"33333333-3333-3333-3333-333333333333","version":1}"#
    static let frozenPickOne =
        #"{"answeredAt":814692800.1229999,"attempt":{"pickOne":{"prompt":{"cardID":{"direction":0,"noteID":"11111111-1111-1111-1111-111111111111"},"expectedAnswer":"house","options":[{"answer":"tree","noteID":"22222222-2222-2222-2222-222222222222"},{"answer":"house","noteID":"11111111-1111-1111-1111-111111111111"}],"question":"Haus"},"selected":"22222222-2222-2222-2222-222222222222"}},"idempotencyKey":"55555555-5555-5555-5555-555555555555","sessionID":"33333333-3333-3333-3333-333333333333","version":1}"#

    var writing: ExerciseEvent {
        ExerciseEvent(
            idempotencyKey: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, sessionID: session,
            answeredAt: answeredAt,
            attempt: .writing(
                prompt: WritingPrompt(
                    cardID: Card.ID(noteID: note, direction: .reverse), question: "what is your name?",
                    expectedAnswer: "πώς σε λένε;"),
                response: "  πως σε λενε; "))
    }

    var pickOne: ExerciseEvent {
        ExerciseEvent(
            idempotencyKey: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, sessionID: session,
            answeredAt: answeredAt,
            attempt: .pickOne(
                prompt: PickOnePrompt(
                    cardID: Card.ID(noteID: note, direction: .forward), question: "Haus", expectedAnswer: "house",
                    options: [
                        PickOneOption(noteID: other, answer: "tree"), PickOneOption(noteID: note, answer: "house"),
                    ]),
                selected: other))
    }

    @Test(arguments: [(frozenWriting, 0), (frozenPickOne, 1)])
    func shippedRowsDecodeAndReencodeByteForByte(_ frozen: String, _ index: Int) throws {
        let expected = [writing, pickOne][index]
        let data = Data(frozen.utf8)
        #expect(try ExerciseEventPayload.event(from: data) == expected)
        #expect(try ExerciseEventPayload(expected).encoded() == data)
    }

    @Test func unknownVersionIsATypedErrorNotACrash() throws {
        let future = Data(Self.frozenWriting.replacingOccurrences(of: #""version":1"#, with: #""version":2"#).utf8)
        #expect(throws: StoreError.unsupportedPayloadVersion(2)) { try ExerciseEventPayload.event(from: future) }
    }

    @Test(arguments: [
        "not json",
        #"{"version":1}"#,
        frozenWriting.replacingOccurrences(of: #""direction":1"#, with: #""direction":7"#),
    ])
    func malformedPayloadIsACorruptRow(_ payload: String) throws {
        #expect(throws: StoreError.corruptRow("exercise_event")) {
            try ExerciseEventPayload.event(from: Data(payload.utf8))
        }
    }

    @Test func retryIdentityKeepsRawTextAndOptionOrder() throws {
        let original = try ExerciseEventPayload(writing).encoded()
        guard case .writing(let prompt, _) = writing.attempt else { return }
        // Canonically equivalent but byte-different input is a different payload.
        let decomposed = ExerciseEvent(
            idempotencyKey: writing.id, sessionID: session, answeredAt: answeredAt,
            attempt: .writing(prompt: prompt, response: "  πω\u{301}ς σε λενε; "))
        #expect(try ExerciseEventPayload(decomposed).encoded() != original)

        guard case .pickOne(let choice, let selected) = pickOne.attempt else { return }
        let reordered = ExerciseEvent(
            idempotencyKey: pickOne.id, sessionID: session, answeredAt: answeredAt,
            attempt: .pickOne(
                prompt: PickOnePrompt(
                    cardID: choice.cardID, question: choice.question, expectedAnswer: choice.expectedAnswer,
                    options: choice.options.reversed()),
                selected: selected))
        #expect(try ExerciseEventPayload(reordered).encoded() != ExerciseEventPayload(pickOne).encoded())
    }
}
