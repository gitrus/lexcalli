import CryptoKit
import Foundation

/// Unpacks flat Anki archives into invocation-owned staging, with one budget across ZIP and zstd layers.
public struct AnkiPackageUnpacker: PackageUnpacking {
    public init() {}

    public func unpack(_ archive: URL, into directory: URL, limits: UnpackLimits) throws -> UnpackedPackage {
        var budget = try UnpackBudget(limits)
        try Task.checkCancellation()
        let reader = try ZIPPackageReader(archive, limits: limits)
        try prepare(directory)
        let working = directory.appendingPathComponent(".unpack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: false)
        do {
            let package = try unpack(reader, into: working, limits: limits, budget: &budget)
            try Task.checkCancellation()
            return package
        } catch {
            let failure = error
            do { try FileManager.default.removeItem(at: working) } catch { throw PackageError.cleanupFailed }
            throw failure
        }
    }

    private func unpack(
        _ reader: any ArchiveReader, into directory: URL, limits: UnpackLimits, budget: inout UnpackBudget
    ) throws -> UnpackedPackage {
        let names = Set(reader.entries().map(\.name))
        guard
            let databaseName = ["collection.anki21b", "collection.anki21", "collection.anki2"].first(
                where: names.contains)
        else { throw PackageError.unsupportedFormat }
        let current = databaseName == "collection.anki21b"
        if current {
            let metadata = directory.appendingPathComponent("meta.pb")
            try reader.extract("meta", to: metadata, maxBytes: min(64 << 10, limits.maxEntryBytes), budget: &budget)
            try PackageManifest.validateMetadata(Data(contentsOf: metadata))
            try FileManager.default.removeItem(at: metadata)
        }
        let collection = directory.appendingPathComponent("collection.sqlite")
        try extract(databaseName, reader: reader, to: collection, compressed: current, limits: limits, budget: &budget)
        let handle = try FileHandle(forReadingFrom: collection)
        let header: Data
        do {
            header = try handle.read(upToCount: 16) ?? Data()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
        guard header == Data("SQLite format 3\0".utf8) else { throw PackageError.corruptEntry(databaseName) }

        // Bound the in-memory metadata independently of potentially large collection/media limits.
        var metadataLimits = limits
        metadataLimits.maxEntryBytes = min(limits.maxEntryBytes, 16 << 20)
        let manifest = directory.appendingPathComponent("media.manifest")
        try extract("media", reader: reader, to: manifest, compressed: current, limits: metadataLimits, budget: &budget)
        let data = try Data(contentsOf: manifest)
        let entries =
            try current
            ? PackageManifest.current(data, maxEntries: limits.maxEntries)
            : PackageManifest.legacy(data, maxEntries: limits.maxEntries)
        try FileManager.default.removeItem(at: manifest)
        var media: [String: URL] = [:]
        for (index, entry) in entries.enumerated() {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent("media-\(index)")
            try extract(
                entry.archiveName, reader: reader, to: destination, compressed: current, limits: limits, budget: &budget
            )
            try validateMedia(entry, at: destination)
            media[entry.noteFilename] = destination
        }
        return UnpackedPackage(format: current ? .current : .legacy, collection: collection, media: media)
    }

    private func extract(
        _ name: String, reader: any ArchiveReader, to destination: URL, compressed: Bool,
        limits: UnpackLimits, budget: inout UnpackBudget
    ) throws {
        if compressed {
            let raw = destination.appendingPathExtension("zst")
            try reader.extract(name, to: raw, maxBytes: limits.maxEntryBytes, budget: &budget)
            try ZstdPackageDecoder.decode(raw, to: destination, limits: limits, budget: &budget)
            try FileManager.default.removeItem(at: raw)
        } else {
            try reader.extract(name, to: destination, maxBytes: limits.maxEntryBytes, budget: &budget)
        }
    }

    private func validateMedia(_ entry: PackageMediaEntry, at url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let expected = entry.size, size.map(Int64.init) != expected {
            throw PackageError.corruptEntry(entry.archiveName)
        }
        if let expected = entry.sha1 {
            let input = try FileHandle(forReadingFrom: url)
            defer { try? input.close() }
            // SHA-1 is Anki's media-integrity field, not a security/content identity for our media store.
            var hash = Insecure.SHA1()
            while let bytes = try input.read(upToCount: 64 << 10), !bytes.isEmpty {
                try Task.checkCancellation()
                hash.update(data: bytes)
            }
            guard Data(hash.finalize()) == expected else { throw PackageError.corruptEntry(entry.archiveName) }
        }
    }

    private func prepare(_ directory: URL) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: directory.path) {
            try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
            try manager.contentsOfDirectory(atPath: directory.path).isEmpty
        else { throw PackageError.invalidStagingDirectory }
    }
}
