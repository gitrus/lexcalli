import FSRS
import Testing

@testable import LexcalliCore

/// Raw values are persisted and exchanged with other tools, so their numbering must not change.
/// `FSRS::` selects swift-fsrs types.
struct CompatibilityTests {
    @Test func ankiReviewLogEase() {
        #expect([FSRS::Rating.again, .hard, .good, .easy].map(\.rawValue) == [1, 2, 3, 4])
        #expect(LexcalliCore::Rating.allCases.map(\.rawValue) == [1, 2, 3, 4])
        #expect(LexcalliCore::Rating.allCases.map { FSRS::Rating($0).rawValue } == [1, 2, 3, 4])
    }

    @Test func ankiCardType() {
        #expect([FSRS::CardState.new, .learning, .review, .relearning].map(\.rawValue) == [0, 1, 2, 3])
        #expect(LexcalliCore::CardState.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(LexcalliCore::CardState.allCases.map { FSRS::CardState($0).rawValue } == [0, 1, 2, 3])
        #expect(
            LexcalliCore::CardState.allCases.map { LexcalliCore::CardState(FSRS::CardState($0)) }
                == LexcalliCore::CardState.allCases)
    }

    @Test func cardDirection() {
        #expect(CardDirection.allCases.map(\.rawValue) == [0, 1])
    }
}
