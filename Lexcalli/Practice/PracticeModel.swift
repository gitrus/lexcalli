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
    private(set) var current: CurrentCard?
    private(set) var deckName: String
    private(set) var progress = (answered: 0, total: 0)
    /// A command is running; others wait.
    private(set) var isSaving = false
    /// `retry()` repeats the failed command.
    private(set) var failure: String?
    /// Cards behind their events after projection, until recalculated.
    private(set) var needsRepair: [Card.ID] = []

    @ObservationIgnored private let library: Library
    @ObservationIgnored private let deckID: Deck.ID
    /// Reused when retrying a lost open.
    @ObservationIgnored private let sessionID = UUID()
    @ObservationIgnored private var run: PracticeRun?
    @ObservationIgnored private var deck: Deck?
    @ObservationIgnored private var failedCommand: Command?

    private enum Command {
        case save, finish, recalculate
    }

    init(library: Library, deckID: Deck.ID, deckName: String) {
        self.library = library
        self.deckID = deckID
        self.deckName = deckName
    }

    /// The store first ends and projects sessions an earlier launch left open.
    func open() async {
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
            let opened = try await library.reviews.openSession(sessionID, deck: deckID, at: .now)
            // Another call may have opened it meanwhile.
            guard run == nil else { return }
            self.deck = deck
            deckName = deck.name
            run = PracticeRun(session: opened.session, queue: opened.queue)
            needsRepair = opened.recovered.needsRecalculation + opened.recovered.failedCards
            phase = .studying
            update()
        } catch {
            phase = .openFailed(error.localizedDescription)
            return
        }
        await finishIfDone()
    }

    func answer(_ rating: Rating) async {
        guard phase == .studying, !isSaving, var run else { return }
        guard let event = run.answer(rating, at: .now) else { return }
        // Kept before awaiting, so a retry resends exactly this event.
        self.run = run
        await save(event)
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
            phase = .finished(reviewed: run?.answeredCount ?? 0)
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
        guard let run, run.current == nil, run.pending == nil else { return }
        await finish()
    }

    private func fail(_ command: Command, _ message: String) {
        failedCommand = command
        failure = message
    }

    private func save(_ event: CardReviewEvent) async {
        isSaving = true
        failure = nil
        defer { isSaving = false }
        do {
            _ = try await library.reviews.record(event)
            run?.acknowledge(event.idempotencyKey)
            failedCommand = nil
            update()
        } catch {
            fail(.save, String(localized: "Couldn't save your answer. \(error.localizedDescription)"))
        }
    }

    private func update() {
        guard let run, let deck else { return }
        progress = (run.answeredCount, run.queue.count)
        current = run.current.flatMap { id in
            deck.notes.first { $0.id == id.noteID }.map {
                CurrentCard(id: id, note: $0, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
            }
        }
    }
}
