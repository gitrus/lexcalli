import Foundation
import Testing

@testable import LexcalliCore
@testable import LexcalliStore

extension ExerciseStoreTests {
    @Test(arguments: StoreKind.allCases)
    func lostAcknowledgementAndFinishBeforeContinueRecordOnce(_ kind: StoreKind) async throws {
        let store = try kind.make()
        try await unlock(store)
        let opened = try await store.openSession(UUID(), deck: deck.id, mode: .mixed, at: now)
        let card = try #require(opened.queue.first)
        let note = try #require(deck.notes.first { $0.id == card.noteID })
        let prompt = try #require(WritingExercise().prompt(for: note))
        var run = try PracticeRun(session: opened.session, items: [PracticeItem(card: card, prompt: .writing(prompt))])
        let submitted = run.answerExercise(.writing("answer"), at: now)
        let first = try #require(submitted)
        // The write committed but its acknowledgement was lost.
        _ = try await store.record(first)
        let retried = run.answerExercise(.writing("changed input is ignored"), at: now.addingTimeInterval(10))
        let retry = try #require(retried)
        #expect(try ExerciseEventPayload(retry).encoded() == ExerciseEventPayload(first).encoded())
        #expect(try await store.record(retry) == .alreadyRecorded)
        run.acknowledge(retry.id)
        #expect(run.feedback != nil && !run.isComplete && run.answeredCount == 1)
        // Finish includes the acknowledged attempt without requiring Continue.
        _ = try await store.endSession(opened.session.id, at: now)
        #expect(try await store.exerciseEvents(in: opened.session.id) == [first])
        #expect(try await store.session(opened.session.id)?.status == .ended)
    }
}
