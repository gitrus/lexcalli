import Foundation

struct PackageMediaEntry {
    let archiveName: String
    let noteFilename: String
    let size: Int64?
    let sha1: Data?
}

enum PackageManifest {
    static func validateMetadata(_ data: Data) throws {
        var reader = PackageProtoReader(data)
        var version: UInt64?
        while let field = try reader.next() {
            if field.number == 1 {
                guard case .integer(let value) = field.value, version == nil else { throw PackageError.invalidManifest }
                version = value
            }
        }
        guard version == 3 else { throw PackageError.unsupportedFormat }
    }

    static func current(_ data: Data, maxEntries: Int) throws -> [PackageMediaEntry] {
        var reader = PackageProtoReader(data)
        var entries: [PackageMediaEntry] = []
        while let field = try reader.next() {
            guard field.number == 1 else { continue }
            guard case .bytes(let bytes) = field.value, entries.count < maxEntries else {
                throw PackageError.invalidManifest
            }
            entries.append(try mediaRecord(bytes, index: entries.count))
        }
        return try validated(entries)
    }

    static func legacy(_ data: Data, maxEntries: Int) throws -> [PackageMediaEntry] {
        // JSONDecoder dictionaries would hide duplicate keys.
        var reader = PackageJSONReader(data)
        return try validated(reader.read(maxEntries: maxEntries))
    }

    private static func mediaRecord(_ data: Data, index: Int) throws -> PackageMediaEntry {
        var reader = PackageProtoReader(data)
        var seen = Set<Int>()
        var name: String?
        var size: UInt64 = 0
        var digest: Data?
        var archiveName = String(index)
        while let field = try reader.next() {
            guard [1, 2, 3, 255].contains(field.number) else { continue }
            guard seen.insert(field.number).inserted else { throw PackageError.invalidManifest }
            switch (field.number, field.value) {
            case (1, .bytes(let bytes)): name = String(data: bytes, encoding: .utf8)
            case (2, .integer(let value)) where value <= UInt32.max: size = value
            case (3, .bytes(let bytes)) where bytes.count == 20: digest = bytes
            case (255, .integer(let value)) where value <= UInt32.max: archiveName = String(value)
            default: throw PackageError.invalidManifest
            }
        }
        guard let name, let digest else { throw PackageError.invalidManifest }
        return PackageMediaEntry(archiveName: archiveName, noteFilename: name, size: Int64(size), sha1: digest)
    }

    private static func validated(_ entries: [PackageMediaEntry]) throws -> [PackageMediaEntry] {
        var sourceNames = Set<String>()
        var noteNames = Set<String>()
        for entry in entries {
            try Task.checkCancellation()
            try validatePackageName(entry.noteFilename)
            let key = entry.archiveName
            guard let number = UInt64(key), String(number) == key, !key.isEmpty,
                sourceNames.insert(key).inserted, noteNames.insert(entry.noteFilename).inserted
            else { throw PackageError.invalidManifest }
        }
        return entries
    }
}

private struct PackageProtoReader {
    enum Value {
        case integer(UInt64)
        case bytes(Data)
        case ignored
    }
    struct Field {
        let number: Int
        let value: Value
    }

    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) { bytes = Array(data) }

    mutating func next() throws -> Field? {
        try Task.checkCancellation()
        guard offset < bytes.count else { return nil }
        let key = try varint()
        guard key >> 3 > 0, key >> 3 <= 0x1FFF_FFFF else { throw PackageError.invalidManifest }
        let number = Int(key >> 3)
        let value: Value
        switch key & 7 {
        case 0: value = .integer(try varint())
        case 1:
            try skip(8)
            value = .ignored
        case 2:
            let size = try varint()
            guard size <= bytes.count - offset else { throw PackageError.invalidManifest }
            value = .bytes(Data(bytes[offset..<(offset + Int(size))]))
            offset += Int(size)
        case 5:
            try skip(4)
            value = .ignored
        default: throw PackageError.invalidManifest
        }
        return Field(number: number, value: value)
    }

    private mutating func varint() throws -> UInt64 {
        var result: UInt64 = 0
        for shift in stride(from: 0, to: 64, by: 7) {
            guard offset < bytes.count else { throw PackageError.invalidManifest }
            let byte = bytes[offset]
            offset += 1
            guard shift != 63 || byte <= 1 else { throw PackageError.invalidManifest }
            result |= UInt64(byte & 127) << shift
            if byte & 128 == 0 { return result }
        }
        throw PackageError.invalidManifest
    }

    private mutating func skip(_ count: Int) throws {
        guard count <= bytes.count - offset else { throw PackageError.invalidManifest }
        offset += count
    }
}

private struct PackageJSONReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) { bytes = Array(data) }

    mutating func read(maxEntries: Int) throws -> [PackageMediaEntry] {
        try require(123)  // {
        var result: [PackageMediaEntry] = []
        if !take(125) {
            repeat {
                try Task.checkCancellation()
                guard result.count < maxEntries else { throw PackageError.invalidManifest }
                let key = try string()
                try require(58)  // :
                let name = try string()
                result.append(PackageMediaEntry(archiveName: key, noteFilename: name, size: nil, sha1: nil))
            } while take(44)  // ,
            try require(125)  // }
        }
        whitespace()
        guard offset == bytes.count else { throw PackageError.invalidManifest }
        return result
    }

    private mutating func string() throws -> String {
        whitespace()
        let start = offset
        guard offset < bytes.count, bytes[offset] == 34 else { throw PackageError.invalidManifest }
        offset += 1
        var escaped = false
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            if byte == 34 && !escaped {
                do { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset])) } catch {
                    throw PackageError.invalidManifest
                }
            }
            if byte == 92 && !escaped { escaped = true } else { escaped = false }
        }
        throw PackageError.invalidManifest
    }

    private mutating func whitespace() {
        while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 }
    }

    private mutating func take(_ byte: UInt8) -> Bool {
        whitespace()
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1
        return true
    }

    private mutating func require(_ byte: UInt8) throws {
        guard take(byte) else { throw PackageError.invalidManifest }
    }
}
