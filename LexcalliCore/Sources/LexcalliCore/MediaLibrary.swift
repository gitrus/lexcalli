import CryptoKit
import Foundation

/// Stored instead of a URL, because the container path can change between launches; resolved at the edge.
public struct MediaReference: Hashable, Sendable, Codable {
    /// Lowercase hex SHA-256; names the file.
    public let hash: String
    /// The source's name, e.g. Anki's media filename; its extension gives the type.
    public let filename: String

    public init(hash: String, filename: String) {
        self.hash = hash
        self.filename = filename
    }

    public var fileExtension: String { (filename as NSString).pathExtension.lowercased() }
}

public enum MediaLibraryError: Error, Hashable, Sendable {
    case tooLarge(filename: String, maxBytes: Int64)
}

/// Files named by content hash, under `<root>/<hash prefix>/`. Staged until complete; a hashed file placed before
/// the database references it is either referenced later or removed by `removeUnreferenced(keeping:)`.
public struct MediaLibrary: Hashable, Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var stagingDirectory: URL { root.appending(path: ".staging", directoryHint: .isDirectory) }

    public func url(for reference: MediaReference) -> URL {
        let name = reference.fileExtension.isEmpty ? reference.hash : "\(reference.hash).\(reference.fileExtension)"
        return root.appending(path: String(reference.hash.prefix(2)), directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .notDirectory)
    }

    public func contains(_ reference: MediaReference) -> Bool {
        FileManager.default.fileExists(atPath: url(for: reference).path(percentEncoded: false))
    }

    /// Off the caller's actor; cancellable between chunks.
    @concurrent public func add(contentsOf source: URL, filename: String, maxBytes: Int64) async throws
        -> MediaReference
    {
        try addSynchronously(contentsOf: source, filename: filename, maxBytes: maxBytes)
    }

    /// For small files and fixtures; prefer `add`.
    public func addSynchronously(contentsOf source: URL, filename: String, maxBytes: Int64) throws -> MediaReference {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let staged = stagingDirectory.appending(path: UUID().uuidString, directoryHint: .notDirectory)
        guard fileManager.createFile(atPath: staged.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: staged.path(percentEncoded: false)])
        }
        defer { try? fileManager.removeItem(at: staged) }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: staged)
        defer { try? output.close() }

        var hasher = SHA256()
        var total: Int64 = 0
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            total += Int64(chunk.count)
            guard total <= maxBytes else { throw MediaLibraryError.tooLarge(filename: filename, maxBytes: maxBytes) }
            hasher.update(data: chunk)
            try output.write(contentsOf: chunk)
        }
        try output.synchronize()

        let reference = MediaReference(
            hash: hasher.finalize().map { String(format: "%02x", $0) }.joined(),
            filename: filename
        )
        let destination = url(for: reference)
        if !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            do {
                try fileManager.moveItem(at: staged, to: destination)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                // Another import placed the same content first.
            }
        }
        return reference
    }

    /// Removes staging and unreferenced files; returns the count. Run only while no import writes.
    @concurrent public func removeUnreferenced(keeping hashes: Set<String>) async throws -> Int {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: stagingDirectory)
        guard
            let shards = try? fileManager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        else { return 0 }
        var removed = 0
        for shard in shards {
            for file in try fileManager.contentsOfDirectory(at: shard, includingPropertiesForKeys: nil) {
                let hash = file.deletingPathExtension().lastPathComponent
                if !hashes.contains(hash) {
                    try fileManager.removeItem(at: file)
                    removed += 1
                }
            }
        }
        return removed
    }
}
