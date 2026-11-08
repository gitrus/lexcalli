import Foundation
import LexcalliCore
import Observation

/// One session. Each answer becomes one event before any await and is resent on retry until acknowledged.
@Observable
final class PracticeModel {
    enum Phase: Equatable {
        case opening
        case openFailed(String)
        case studying
        case finishing
        case finished(reviewed: Int)
    }

    struct CurrentCard: Equatable {
        let id: Card.ID
        let note: Note
        let termLanguage: Locale.Language
        let meaningLanguage: Locale.Language
    }

    private(set) var phase = Phase.opening
    var current: CurrentCard? {
        guard let prompt = run?.currentPrompt, let deck,
            let note = deck.notes.first(where: { $0.id == prompt.cardID.noteID })
        else { return nil }
        return CurrentCard(
            id: prompt.cardID, note: note, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
    }
    var currentPrompt: ExercisePrompt? { run?.currentPrompt }
    var feedback: ExerciseFeedback? { run?.feedback }
    var hasPendingAnswer: Bool { run?.pending != nil }
    var flashcardsReviewed: Int { run?.flashcardsReviewed ?? 0 }
    var exercisesCompleted: Int { run?.exercisesCompleted ?? 0 }
    let mode: PracticeMode
    private(set) var deckName: String
    var progress: (answered: Int, total: Int) { (run?.answeredCount ?? 0, run?.items.count ?? 0) }
    var currentPosition: Int {
        guard let run else { return 0 }
        return run.position + (run.current == nil ? 0 : 1)
    }
    /// A command is running; others wait.
    private(set) var isSaving = false
    /// `retry()` repeats the failed command.
    private(set) var failure: String?
    /// Cards behind their events after projection, until recalculated.
    private(set) var needsRepair: [Card.ID] = []

    @ObservationIgnored private let library: Library
    @ObservationIgnored private let deckID: Deck.ID
    @ObservationIgnored private var isOpening = false
    /// Reused when retrying a lost open.
    @ObservationIgnored private let sessionID = UUID()
    private var run: PracticeRun?
    @ObservationIgnored private var deck: Deck?
    @ObservationIgnored private var failedCommand: Command?

    private enum Command {
        case save, finish, recalculate
    }

    init(library: Library, deckID: Deck.ID, deckName: String, mode: PracticeMode = .flashcards) {
        self.library = library
        self.deckID = deckID
        self.deckName = deckName
        self.mode = mode
    }

    /// The store first ends and projects sessions an earlier launch left open.
    func open() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        switch phase {
        case .opening, .openFailed: break
        case .studying, .finishing, .finished: return
        }
        phase = .opening
        do {
            var decks = library.decks.deck(deckID).makeAsyncIterator()
            guard let deck = try await decks.next() ?? nil else {
                phase = .openFailed(String(localized: "This deck no longer exists."))
                return
            }
            let opened = try await library.reviews.openSession(sessionID, deck: deckID, mode: mode, at: .now)
            let prepared = try await Self.prepareRun(
                opened, deck: deck, engine: library.exerciseEngines.engine(for: opened.session.mode))
            // Another call may have opened it meanwhile.
            guard run == nil else { return }
            self.deck = deck
            deckName = deck.name
            run = prepared
            needsRepair = opened.recovered.needsRecalculation + opened.recovered.failedCards
            phase = .studying
        } catch {
            phase = .openFailed(error.localizedDescription)
            return
        }
        await finishIfDone()
    }

    func answer(_ rating: Rating) async {
        await submit(.flashcard(rating))
    }

    func answerExercise(_ response: ExerciseResponse) async {
        if case .flashcard = response { return }
        await submit(response)
    }

    private func submit(_ response: ExerciseResponse) async {
        guard phase == .studying, !isSaving, failure == nil, var run else { return }
        let attempt: PendingAttempt?
        switch response {
        case .flashcard(let rating): attempt = run.answer(rating, at: .now).map(PendingAttempt.card)
        case .writing, .pickOne: attempt = run.answerExercise(response, at: .now).map(PendingAttempt.exercise)
        }
        guard let attempt else { return }
        // Kept before awaiting, so a retry resends exactly this event.
        self.run = run
        await save(attempt)
        await finishIfDone()
    }

    func continueAfterFeedback() async {
        guard phase == .studying, !isSaving, failure == nil,
            run?.continueAfterFeedback() == true
        else { return }
        await finishIfDone()
    }

    func retry() async {
        guard !isSaving else { return }
        if let pending = run?.pending, phase == .studying {
            await save(pending)
            await finishIfDone()
        } else if failedCommand == .finish {
            await finish()
        } else if failedCommand == .recalculate {
            await recalculate()
        }
    }

    /// Waits for the pending answer first.
    func finish() async {
        guard phase == .studying, !isSaving else { return }
        if let pending = run?.pending {
            await save(pending)
            guard run?.pending == nil else { return }
        }
        phase = .finishing
        failure = nil
        do {
            let report = try await library.reviews.endSession(sessionID, at: .now)
            needsRepair += report.needsRecalculation + report.failedCards
            failedCommand = nil
            phase = .finished(reviewed: run?.flashcardsReviewed ?? 0)
        } catch {
            // Stays open; the next open recovers it.
            phase = .studying
            fail(.finish, String(localized: "Couldn't finish the session. \(error.localizedDescription)"))
        }
    }

    func recalculate() async {
        guard !isSaving, !needsRepair.isEmpty else { return }
        isSaving = true
        failure = nil
        defer { isSaving = false }
        do {
            while let card = needsRepair.first {
                _ = try await library.reviews.recalculate(card)
                needsRepair.removeFirst()
            }
            failedCommand = nil
        } catch {
            fail(.recalculate, String(localized: "Couldn't recalculate. \(error.localizedDescription)"))
        }
    }

    /// Nothing left to answer ends the session, so the summary needs no separate Finish.
    private func finishIfDone() async {
        guard let run, run.isComplete, run.pending == nil, run.feedback == nil else { return }
        await finish()
    }

    private func fail(_ command: Command, _ message: String) {
        failedCommand = command
        failure = message
    }

    private func save(_ attempt: PendingAttempt) async {
        isSaving = true
        failure = nil
        defer { isSaving = false }
        do {
            _ = try await library.reviews.record(attempt)
            run?.acknowledge(attempt.id)
            failedCommand = nil
        } catch {
            fail(.save, String(localized: "Couldn't save your answer. \(error.localizedDescription)"))
        }
    }

    @concurrent private static func prepareRun(
        _ opened: OpenedSession, deck: Deck, engine: ExerciseEngine
    ) async throws -> PracticeRun {
        var random = SystemRandomNumberGenerator()
        return try PracticeRun(opened: opened, notes: deck.notes, engine: engine, using: &random)
    }
}
