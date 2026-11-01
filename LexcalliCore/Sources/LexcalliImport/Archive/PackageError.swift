import Foundation

/// An untrusted package could not be unpacked safely. Filesystem errors and cancellation propagate separately.
public enum PackageError: Error, Hashable, Sendable {
    case invalidLimits
    case invalidArchive
    case invalidStagingDirectory
    case unsupportedFormat
    case unsafeName(String)
    case nonFileEntry(String)
    case duplicateEntry(String)
    case missingEntry(String)
    case limitExceeded
    case corruptEntry(String)
    case invalidManifest
    case decompressionFailed(String)
    /// Partial staging could not be removed. The caller must quarantine it rather than commit its contents.
    case cleanupFailed
}

/// One invocation's cumulative budget. Bytes are never refunded when intermediate files are removed.
struct UnpackBudget {
    private(set) var remaining: Int64

    init(_ limits: UnpackLimits) throws {
        guard limits.maxArchiveBytes > 0, limits.maxEntries > 0, limits.maxEntryBytes > 0,
            limits.maxTotalBytes > 0, (10...30).contains(limits.maxWindowLog)
        else { throw PackageError.invalidLimits }
        remaining = limits.maxTotalBytes
    }

    mutating func consume(_ count: Int) throws {
        try Task.checkCancellation()
        guard count >= 0, Int64(count) <= remaining else { throw PackageError.limitExceeded }
        remaining -= Int64(count)
    }
}

/// Both archive member names and original media names must be flat. They never become destination paths.
func validatePackageName(_ name: String) throws {
    guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
        !name.contains(":"), !name.utf8.contains(0)
    else { throw PackageError.unsafeName(name) }
}
