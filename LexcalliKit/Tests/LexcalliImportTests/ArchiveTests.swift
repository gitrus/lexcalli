import Foundation
import SQLite3
import Testing

@testable import LexcalliImport

struct ArchiveTests {
    @Test(arguments: ["current-new.apkg", "current-progress.apkg", "legacy-new.apkg", "legacy-progress.apkg"])
    func officialExports(name: String) throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let package = try AnkiPackageUnpacker().unpack(try fixture(name), into: directory, limits: UnpackLimits())
        let current = name.hasPrefix("current")
        let progress = name.contains("progress")
        #expect(package.format == (current ? .current : .legacy))
        #expect(try scalar(package.collection, "select count(*) from notes") == 4)
        #expect(try scalar(package.collection, "select count(*) from cards") == 8)
        #expect(try scalar(package.collection, "select count(*) from revlog") == (progress ? 3 : 0))
        #expect(try scalar(package.collection, "select ver from col") == (current ? 18 : 11))
        #expect(
            try scalar(
                package.collection, "select count(*) from cards where data like '%\"s\"%' and data like '%\"d\"%'")
                == (progress ? 3 : 0)
        )
        #expect(Set(package.media.keys) == Set(["pixel.png", "tone.wav"]))
        let image = try #require(package.media["pixel.png"])
        let audio = try #require(package.media["tone.wav"])
        #expect(try Data(contentsOf: image).starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(try Data(contentsOf: audio).starts(with: Array("RIFF".utf8)))
        let files = try FileManager.default.contentsOfDirectory(
            atPath: package.collection.deletingLastPathComponent().path)
        #expect(Set(files) == Set(["collection.sqlite", "media-0", "media-1"]))
        #expect(try scalar(package.collection, "select count(*) from cards") == 8)
    }

    @Test(arguments: ["prefer-current.apkg", "anki2-only.apkg", "small-zip64.apkg"])
    func formatPriorityAndCompatibility(name: String) throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let package = try AnkiPackageUnpacker().unpack(try fixture(name), into: directory, limits: UnpackLimits())
        #expect(package.format == (name == "prefer-current.apkg" ? .current : .legacy))
        #expect(try scalar(package.collection, "select count(*) from notes") == 4)
        #expect(package.media.count == 2)
    }

    @Test(arguments: [
        "traversal.zip", "absolute.zip", "backslash.zip", "dot.zip", "symlink.zip", "duplicate.zip",
        "bomb-declared.zip", "truncated.zip", "wrong-directory-count.zip", "duplicate-json-key.apkg",
        "duplicate-media-name.apkg", "unsafe-media-name.apkg", "missing-media.apkg", "malformed-json.apkg",
        "unknown-version.apkg", "bad-current-db.apkg", "bad-protobuf.apkg", "bad-media-sha.apkg",
    ])
    func rejectsHostilePackagesAndCleansStaging(name: String) throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = try fixture(name)
        #expect(throws: (any Error).self) {
            _ = try AnkiPackageUnpacker().unpack(archive, into: directory, limits: UnpackLimits())
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func actualBudgetSpansZIPAndZstdLayers() throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        // The decoded DB alone fits; counting both ZIP and zstd output must exceed this budget.
        let limits = UnpackLimits(maxEntryBytes: 200_000, maxTotalBytes: 140_000)
        let archive = try fixture("current-new.apkg")
        #expect(throws: PackageError.limitExceeded) {
            _ = try AnkiPackageUnpacker().unpack(archive, into: directory, limits: limits)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func forgedZIPSizeStillChargesActualBytes() throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = UnpackLimits(maxTotalBytes: 1024)
        let reader = try ZIPPackageReader(try fixture("bomb-forged-small.zip"), limits: limits)
        #expect(reader.entries().first?.uncompressedSize == 1)
        var budget = try UnpackBudget(limits)
        let output = directory.appendingPathComponent("output")
        #expect(throws: PackageError.limitExceeded) {
            try reader.extract("bomb", to: output, maxBytes: limits.maxEntryBytes, budget: &budget)
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test func budgetIsNotRefundedBetweenFiles() throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = UnpackLimits(maxTotalBytes: 15)
        var budget = try UnpackBudget(limits)
        let input = try fixture("valid.zst")
        let first = directory.appendingPathComponent("first")
        try ZstdPackageDecoder.decode(input, to: first, limits: limits, budget: &budget)
        #expect(budget.remaining == 5)
        try FileManager.default.removeItem(at: first)
        #expect(throws: PackageError.limitExceeded) {
            try ZstdPackageDecoder.decode(
                input, to: directory.appendingPathComponent("second"), limits: limits, budget: &budget)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test(arguments: ["corrupt.zst", "truncated.zst", "bomb.zst", "window-too-large.zst"])
    func boundsAndRejectsZstd(name: String) throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = UnpackLimits(maxEntryBytes: 1024, maxWindowLog: 23)
        var budget = try UnpackBudget(limits)
        let input = try fixture(name)
        let output = directory.appendingPathComponent("output")
        #expect(throws: (any Error).self) {
            try ZstdPackageDecoder.decode(input, to: output, limits: limits, budget: &budget)
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test func decoderWindowIsIndependentOfOutputBudget() throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limits = UnpackLimits(maxEntryBytes: 32 << 20, maxWindowLog: 23)
        var budget = try UnpackBudget(limits)
        do {
            try ZstdPackageDecoder.decode(
                try fixture("window-too-large.zst"), to: directory.appendingPathComponent("output"),
                limits: limits, budget: &budget
            )
            Issue.record("16 MiB frame window exceeded the 8 MiB decoder allowance")
        } catch PackageError.decompressionFailed(let message) {
            #expect(message.contains("memory"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func rejectsBadLimitsAndNonemptyOrSymlinkStaging() throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = try fixture("legacy-new.apkg")
        for limits in [UnpackLimits(maxEntries: 0), UnpackLimits(maxTotalBytes: -1), UnpackLimits(maxWindowLog: 31)] {
            #expect(throws: PackageError.invalidLimits) {
                _ = try AnkiPackageUnpacker().unpack(archive, into: directory, limits: limits)
            }
        }
        let original = directory.appendingPathComponent("preserve")
        try Data("unchanged".utf8).write(to: original)
        #expect(throws: PackageError.invalidStagingDirectory) {
            _ = try AnkiPackageUnpacker().unpack(archive, into: directory, limits: UnpackLimits())
        }
        #expect(try Data(contentsOf: original) == Data("unchanged".utf8))
        let parent = try staging()
        defer { try? FileManager.default.removeItem(at: parent) }
        let empty = parent.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
        let link = parent.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: empty)
        #expect(throws: PackageError.invalidStagingDirectory) {
            _ = try AnkiPackageUnpacker().unpack(archive, into: link, limits: UnpackLimits())
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: empty.path).isEmpty)
    }

    @Test func archiveAndEntryCountLimits() throws {
        let archive = try fixture("current-new.apkg")
        #expect(throws: PackageError.limitExceeded) {
            _ = try ZIPPackageReader(archive, limits: UnpackLimits(maxArchiveBytes: 1))
        }
        #expect(throws: PackageError.limitExceeded) {
            _ = try ZIPPackageReader(archive, limits: UnpackLimits(maxEntries: 1))
        }
    }

    @Test func cancellationBeforeUnpackLeavesNoFiles() async throws {
        let directory = try staging()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = try fixture("current-new.apkg")
        let gate = ArchiveCancellationGate()
        let task = Task {
            await gate.wait()
            return try AnkiPackageUnpacker().unpack(archive, into: directory, limits: UnpackLimits())
        }
        task.cancel()
        await gate.open()
        do {
            _ = try await task.value
            Issue.record("A cancelled unpack must not succeed")
        } catch is CancellationError {
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test func manifestRejectsAmbiguousAndMalformedValues() throws {
        for text in [
            "{\"0\":\"a\",\"0\":\"b\"}", "{\"0\":\"a\",\"1\":\"a\"}", "{\"00\":\"a\"}",
            "{\"0\":\"a\",}", "{\"0\":\"a\"} trailing", "{\"0\":3}", "[]",
        ] {
            #expect(throws: PackageError.invalidManifest) {
                _ = try PackageManifest.legacy(Data(text.utf8), maxEntries: 10)
            }
        }
        let escaped = try PackageManifest.legacy(Data("{\"0\":\"caf\\u00e9.png\"}".utf8), maxEntries: 10)
        #expect(escaped.first?.noteFilename == "café.png")
        #expect(try PackageManifest.legacy(Data("{}".utf8), maxEntries: 1).isEmpty)
        #expect(try PackageManifest.current(Data(), maxEntries: 1).isEmpty)
        for bytes: [UInt8] in [[0x0A, 0xFF], [0x0A, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02], [0]] {
            #expect(throws: PackageError.invalidManifest) {
                _ = try PackageManifest.current(Data(bytes), maxEntries: 10)
            }
        }
    }

    private func fixture(_ name: String) throws -> URL {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let url = root.appendingPathComponent(name)
        #expect(FileManager.default.fileExists(atPath: url.path))
        return url
    }

    private func staging() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "archive-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func scalar(_ file: URL, _ sql: String) throws -> Int {
        var database: OpaquePointer?
        let status = sqlite3_open_v2(
            file.absoluteString + "?immutable=1", &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        defer { if let database { sqlite3_close(database) } }
        #expect(status == SQLITE_OK)
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        return Int(sqlite3_column_int64(statement, 0))
    }
}

private actor ArchiveCancellationGate {
    private var opened = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
