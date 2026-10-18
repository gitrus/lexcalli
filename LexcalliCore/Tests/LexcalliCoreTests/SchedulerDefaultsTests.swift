import FSRS
import Foundation
import Testing

@testable import LexcalliCore

struct SchedulerDefaultsTests {
    @Test func usesFSRS6() {
        #expect(FSRS(parameters: SchedulerDefaults.parameters).version == .v6)
    }

    @Test func schedulesNewCardOnGood() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduler = FSRS(parameters: SchedulerDefaults.parameters)

        let result = try scheduler.next(card: Card(due: now), now: now, grade: .good)

        #expect(result.card.reps == 1)
        #expect(result.card.due > now)
        #expect(result.log.rating == .good)
    }
}
