import Foundation

/// An untrusted `.apkg` unpacked into app-owned staging as plain files.
public struct UnpackedPackage: Hashable, Sendable {
    public enum Format: Hashable, Sendable {
        /// `collection.anki21b`: zstd SQLite schema 18, Protobuf meta and media manifest.
        case current
        /// `collection.anki21` or `.anki2`: SQLite schema 11, JSON media map.
        case legacy
    }

    public let format: Format
    /// A complete, unchanged snapshot, so it may be opened read-only and immutable.
    public let collection: URL
    /// Keyed by the name notes use (`<img src>`, `[sound:]`).
    public let media: [String: URL]

    public init(format: Format, collection: URL, media: [String: URL]) {
        self.format = format
        self.collection = collection
        self.media = media
    }
}

/// Totals count bytes actually written across entries and layers, never declared sizes.
public struct UnpackLimits: Hashable, Sendable {
    public var maxArchiveBytes: Int64
    public var maxEntries: Int
    public var maxEntryBytes: Int64
    public var maxTotalBytes: Int64
    /// As a power of two.
    public var maxWindowLog: Int32

    public init(
        maxArchiveBytes: Int64 = 512 << 20,
        maxEntries: Int = 50_000,
        maxEntryBytes: Int64 = 256 << 20,
        maxTotalBytes: Int64 = 2 << 30,
        maxWindowLog: Int32 = 27
    ) {
        self.maxArchiveBytes = maxArchiveBytes
        self.maxEntries = maxEntries
        self.maxEntryBytes = maxEntryBytes
        self.maxTotalBytes = maxTotalBytes
        self.maxWindowLog = maxWindowLog
    }
}

/// Synchronous, streaming, cancellable between chunks; call from a non-main worker.
public protocol PackageUnpacking: Sendable {
    /// `archive` is an immutable copy in staging, never a picker URL; `directory` is empty.
    func unpack(_ archive: URL, into directory: URL, limits: UnpackLimits) throws -> UnpackedPackage
}
