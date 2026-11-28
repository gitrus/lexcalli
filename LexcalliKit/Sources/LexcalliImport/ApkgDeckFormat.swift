import CryptoKit
import Foundation
import LexcalliCore
import SQLite3

/// `.apkg` packages in the Anki data format
public struct ApkgDeckFormat: DeckFileFormat {
    public let filenameExtensions = ["apkg"]
    private let limits: UnpackLimits

    public init(limits: UnpackLimits = UnpackLimits()) {
        self.limits = limits
    }

    public func read(_ file: URL, staging: URL) throws -> ImportedDeck {
        do {
            return try CollectionReader.read(AnkiPackageUnpacker().unpack(file, into: staging, limits: limits))
        } catch let error as PackageError {
            throw switch error {
            case .invalidArchive, .unsupportedFormat: DeckFileError.unsupportedFile
            case .limitExceeded: DeckFileError.tooLarge
            default: DeckFileError.unreadable
            }
        }
    }
}

enum CollectionReader {
    static func read(_ package: UnpackedPackage) throws -> ImportedDeck {
        let collection = try Collection(package.collection)
        let sourceDeckID = try collection.int64("SELECT did FROM cards GROUP BY did ORDER BY count(*) DESC LIMIT 1")
        let name = try sourceDeckID.flatMap { try collection.deckName($0, format: package.format) } ?? ""
        var notes: [Note] = []
        var skipped = 0
        try collection.forEachRow("SELECT guid, flds FROM notes ORDER BY id") { guid, fields in
            try Task.checkCancellation()
            let texts = fields.split(separator: "\u{1F}", omittingEmptySubsequences: false).map {
                FieldText.plain(String($0))
            }
            guard texts.count >= 2, !texts[0].isEmpty, !texts[1].isEmpty else {
                skipped += 1
                return
            }
            notes.append(Note(id: stableID("imported-note", guid), term: texts[0], meaning: texts[1]))
        }
        return ImportedDeck(
            id: stableID("imported-deck", String(sourceDeckID ?? 0)), name: name, notes: notes, skippedNotes: skipped)
    }

    /// The same input always gives the same UUID (version 8, from SHA-256).
    static func stableID(_ kind: String, _ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data("\(kind):\(value)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}

enum FieldText {
    static func plain(_ html: String) -> String {
        var text = html.replacing(/\[sound:[^\]]*\]/, with: "")
        text = text.replacing(/(?i)<br\s*\/?>|<\/(div|p|li)>/, with: " ")
        text = text.replacing(/<[^>]*>/, with: "")
        text = decodingEntities(text)
        return text.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    private static let namedEntities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]

    private static func decodingEntities(_ text: String) -> String {
        text.replacing(/&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);/) { match in
            let entity = String(match.output.1)
            if entity.hasPrefix("#") {
                let digits = entity.dropFirst()
                let value =
                    digits.first.map({ $0 == "x" || $0 == "X" }) == true
                    ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
                return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? String(match.output.0)
            }
            return namedEntities[entity.lowercased()] ?? String(match.output.0)
        }
    }
}

/// A read-only connection to an unpacked collection: a complete, unchanged snapshot, so it opens immutable.
private final class Collection {
    private let database: OpaquePointer

    init(_ file: URL) throws {
        var handle: OpaquePointer?
        let uri = file.absoluteString + "?immutable=1"
        let status = sqlite3_open_v2(uri, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        guard status == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw PackageError.corruptEntry("collection")
        }
        database = handle
    }

    deinit { sqlite3_close(database) }

    func int64(_ sql: String, _ argument: Int64? = nil) throws -> Int64? {
        try withStatement(sql, argument) { statement in
            sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int64(statement, 0) : nil
        }
    }

    func text(_ sql: String, _ argument: Int64? = nil) throws -> String? {
        try withStatement(sql, argument) { statement in
            sqlite3_step(statement) == SQLITE_ROW ? column(statement, 0) : nil
        }
    }

    func forEachRow(_ sql: String, _ body: (String, String) throws -> Void) throws {
        try withStatement(sql, nil) { statement in
            while true {
                switch sqlite3_step(statement) {
                case SQLITE_ROW: try body(column(statement, 0) ?? "", column(statement, 1) ?? "")
                case SQLITE_DONE: return
                default: throw PackageError.corruptEntry("collection")
                }
            }
        }
    }

    func deckName(_ id: Int64, format: UnpackedPackage.Format) throws -> String? {
        let path: String? =
            switch format {
            case .current:
                try text("SELECT name FROM decks WHERE id = ?", id)
            case .legacy:
                try text("SELECT decks FROM col").flatMap { json in
                    let decks = try? JSONDecoder().decode([String: LegacyDeck].self, from: Data(json.utf8))
                    return decks?[String(id)]?.name
                }
            }
        return path?.split(whereSeparator: { $0 == "\u{1F}" }).last.map(String.init)?
            .components(separatedBy: "::").last
    }

    private struct LegacyDeck: Decodable {
        let name: String
    }

    private func withStatement<T>(_ sql: String, _ argument: Int64?, _ body: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw PackageError.corruptEntry("collection")
        }
        defer { sqlite3_finalize(statement) }
        if let argument { sqlite3_bind_int64(statement, 1, argument) }
        return try body(statement)
    }

    private func column(_ statement: OpaquePointer, _ index: Int32) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }
}
