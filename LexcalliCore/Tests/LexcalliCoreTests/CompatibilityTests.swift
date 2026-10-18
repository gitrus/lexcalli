import FSRS
import Testing

/// Raw values are persisted and exchanged with other tools, so their numbering must not change.
struct CompatibilityTests {
    @Test func ankiReviewLogEase() {
        #expect([Rating.again, .hard, .good, .easy].map(\.rawValue) == [1, 2, 3, 4])
    }

    @Test func ankiCardType() {
        #expect([CardState.new, .learning, .review, .relearning].map(\.rawValue) == [0, 1, 2, 3])
    }
}
