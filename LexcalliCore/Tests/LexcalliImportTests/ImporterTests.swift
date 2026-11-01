import Foundation
import Testing

@testable import LexcalliImport

struct ImporterTests {
    @Test func defaultLimitsBoundEveryResource() {
        let limits = UnpackLimits()

        #expect(limits.maxEntryBytes <= limits.maxTotalBytes)
        #expect(limits.maxArchiveBytes > 0 && limits.maxEntries > 0)
    }
}
