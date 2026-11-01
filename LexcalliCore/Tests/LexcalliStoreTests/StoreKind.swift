import Foundation
import LexcalliCore
import LexcalliStore
import Testing

protocol TestableStore: DeckStore, ReviewStore {
    var activeObservations: Int { get }
}

enum StoreKind: CaseIterable, Sendable, CustomTestStringConvertible {
    case inMemory
    case database

    func make() throws -> any TestableStore {
        switch self {
        case .inMemory: InMemoryStore()
        case .database: try DatabaseStore.inMemory()
        }
    }

    var testDescription: String {
        switch self {
        case .inMemory: "in memory"
        case .database: "GRDB"
        }
    }

    /// Polls for up to two seconds, e.g. for an observation's release after cancellation.
    func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Condition not met in time")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

extension InMemoryStore: TestableStore {
    var activeObservations: Int { observerCount }
}

extension DatabaseStore: TestableStore {}
