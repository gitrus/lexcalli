import Foundation
import LexcalliCore
import LexcalliStore
import Testing

protocol TestableStore: DeckStore, ReviewStore {
    var activeObservations: Int { get }
}

enum StoreKind: CaseIterable, Sendable, CustomTestStringConvertible {
    case reference
    case database

    func make() throws -> any TestableStore {
        switch self {
        case .reference: ReferenceStore()
        case .database: try DatabaseStore.inMemory()
        }
    }

    var testDescription: String {
        switch self {
        case .reference: "reference"
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

extension DatabaseStore: TestableStore {}
