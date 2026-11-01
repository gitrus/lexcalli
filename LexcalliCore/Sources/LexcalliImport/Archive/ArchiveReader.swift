import Darwin
import Foundation
import ZIPFoundation

struct ArchiveEntry: Hashable, Sendable {
    let name: String
    let uncompressedSize: Int64
}

/// A bounded flat archive; each write charges the same invocation-wide budget.
protocol ArchiveReader {
    func entries() -> [ArchiveEntry]
    func extract(_ name: String, to destination: URL, maxBytes: Int64, budget: inout UnpackBudget) throws
}

/// Invocation-local: ZIPFoundation's non-Sendable handle never crosses isolation or runs concurrently.
final class ZIPPackageReader: ArchiveReader {
    private let archive: Archive
    private let indexed: [String: Entry]
    private let listing: [ArchiveEntry]

    init(_ url: URL, limits: UnpackLimits) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw PackageError.invalidArchive }
        guard let fileSize = values.fileSize, Int64(fileSize) <= limits.maxArchiveBytes else {
            throw PackageError.limitExceeded
        }
        let expectedCount = try ZIPDirectoryCount.read(url, size: UInt64(fileSize))
        guard expectedCount <= UInt64(limits.maxEntries) else { throw PackageError.limitExceeded }
        do { archive = try Archive(url: url, accessMode: .read) } catch { throw PackageError.invalidArchive }
        var indexed: [String: Entry] = [:]
        var listing: [ArchiveEntry] = []
        var total: Int64 = 0
        for entry in archive {
            try Task.checkCancellation()
            try validatePackageName(entry.path)
            guard entry.type == .file else { throw PackageError.nonFileEntry(entry.path) }
            guard indexed[entry.path] == nil else { throw PackageError.duplicateEntry(entry.path) }
            guard listing.count < limits.maxEntries, entry.uncompressedSize <= UInt64(limits.maxEntryBytes),
                entry.uncompressedSize <= UInt64(limits.maxTotalBytes - total)
            else { throw PackageError.limitExceeded }
            indexed[entry.path] = entry
            let size = Int64(entry.uncompressedSize)
            listing.append(ArchiveEntry(name: entry.path, uncompressedSize: size))
            total += size
        }
        // ZIPFoundation's iterator stops on a bad central/local header; never accept a truncated prefix of entries.
        guard UInt64(listing.count) == expectedCount else { throw PackageError.invalidArchive }
        self.indexed = indexed
        self.listing = listing
    }

    func entries() -> [ArchiveEntry] { listing }

    func extract(_ name: String, to destination: URL, maxBytes: Int64, budget: inout UnpackBudget) throws {
        try Task.checkCancellation()
        guard let entry = indexed[name] else { throw PackageError.missingEntry(name) }
        guard maxBytes >= 0, entry.uncompressedSize <= UInt64(min(maxBytes, budget.remaining)) else {
            throw PackageError.limitExceeded
        }
        try withPackageOutput(destination) { output in
            var written: Int64 = 0
            let checksum = try archive.extract(entry, bufferSize: 64 << 10, skipCRC32: false) { bytes in
                guard Int64(bytes.count) <= maxBytes - written else { throw PackageError.limitExceeded }
                try budget.consume(bytes.count)
                try output.write(contentsOf: bytes)
                written += Int64(bytes.count)
            }
            guard checksum == entry.checksum, written == Int64(entry.uncompressedSize) else {
                throw PackageError.corruptEntry(name)
            }
        }
    }
}

/// Destination parents belong to this invocation. Never overwrite an existing destination or follow its symlink.
func withPackageOutput(_ url: URL, write: (FileHandle) throws -> Void) throws {
    let descriptor = open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    do {
        try write(handle)
        try Task.checkCancellation()
        try handle.synchronize()
        try handle.close()
    } catch {
        let failure = error
        try? handle.close()
        do { try FileManager.default.removeItem(at: url) } catch { throw PackageError.cleanupFailed }
        throw failure
    }
}

/// Validates the footer's count independently of ZIPFoundation's failable iterator. No entry data is decoded here.
private enum ZIPDirectoryCount {
    static func read(_ url: URL, size: UInt64) throws -> UInt64 {
        guard size >= 22 else { throw PackageError.invalidArchive }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let start = size - min(size, 65_557)
        try handle.seek(toOffset: start)
        let tail = try handle.read(upToCount: Int(size - start)) ?? Data()
        guard tail.count >= 22 else { throw PackageError.invalidArchive }
        for offset in stride(from: tail.count - 22, through: 0, by: -1) {
            guard tail.little(offset, 4) == 0x0605_4B50,
                offset + 22 + Int(tail.little(offset + 20, 2)) == tail.count
            else { continue }
            guard tail.little(offset + 4, 2) == 0, tail.little(offset + 6, 2) == 0 else {
                throw PackageError.invalidArchive
            }
            let count = tail.little(offset + 10, 2)
            guard tail.little(offset + 8, 2) == count else { throw PackageError.invalidArchive }
            let footer = start + UInt64(offset)
            if count == 0xFFFF || tail.little(offset + 12, 4) == 0xFFFF_FFFF
                || tail.little(offset + 16, 4) == 0xFFFF_FFFF
            {
                return try zip64(handle, footer: footer)
            }
            try validateSpan(tail.little(offset + 16, 4), tail.little(offset + 12, 4), before: footer)
            return count
        }
        throw PackageError.invalidArchive
    }

    private static func zip64(_ handle: FileHandle, footer: UInt64) throws -> UInt64 {
        guard footer >= 20 else { throw PackageError.invalidArchive }
        try handle.seek(toOffset: footer - 20)
        let locator = try handle.read(upToCount: 20) ?? Data()
        guard locator.count == 20, locator.little(0, 4) == 0x0706_4B50,
            locator.little(4, 4) == 0, locator.little(16, 4) == 1
        else { throw PackageError.invalidArchive }
        let position = locator.little(8, 8)
        guard position <= footer - 20, footer - 20 - position >= 56 else { throw PackageError.invalidArchive }
        try handle.seek(toOffset: position)
        let record = try handle.read(upToCount: 56) ?? Data()
        guard record.count == 56, record.little(0, 4) == 0x0606_4B50,
            record.little(4, 8) >= 44, record.little(4, 8) <= footer - 20 - position - 12,
            record.little(16, 4) == 0, record.little(20, 4) == 0,
            record.little(24, 8) == record.little(32, 8)
        else { throw PackageError.invalidArchive }
        try validateSpan(record.little(48, 8), record.little(40, 8), before: position)
        return record.little(32, 8)
    }

    private static func validateSpan(_ offset: UInt64, _ size: UInt64, before footer: UInt64) throws {
        guard offset <= footer, size <= footer - offset else { throw PackageError.invalidArchive }
    }
}

extension Data {
    /// Call only after the containing fixed-width record's length has been checked.
    fileprivate func little(_ offset: Int, _ count: Int) -> UInt64 {
        (0..<count).reduce(0) { $0 | UInt64(self[offset + $1]) << ($1 * 8) }
    }
}
