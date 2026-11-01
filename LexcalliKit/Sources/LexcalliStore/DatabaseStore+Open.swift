import Foundation
import GRDB

public enum StoreOpenError: Error, Hashable, Sendable {
    /// The database is unchanged; the pre-migration snapshot is kept.
    case migrationFailed(snapshot: URL?, reason: String)
    case newerSchema
    /// Couldn't close before swapping in the migrated copy; the database is unchanged.
    case databaseBusy
}

extension DatabaseStore {
    /// Opens in WAL mode and migrates. An existing database is never migrated in place: a copy is migrated, then
    /// swapped in with one rename, so any failure or termination leaves the old or the fully migrated database.
    public static func open(at url: URL) throws -> DatabaseStore {
        try open(at: url, migrator: .lexcalli)
    }

    public static func snapshotURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("pre-migration.sqlite")
    }

    static func migratingURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("migrating.sqlite")
    }

    static func open(at url: URL, migrator: DatabaseMigrator) throws -> DatabaseStore {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Left by an interrupted migration; the database itself is untouched.
        let migrating = migratingURL(for: url)
        try removeFiles(of: migrating)

        let pool = try DatabasePool(path: url.path(percentEncoded: false), configuration: configuration)
        let (applied, isComplete, isSuperseded) = try pool.read { db in
            (
                try migrator.appliedIdentifiers(db), try migrator.hasCompletedMigrations(db),
                try migrator.hasBeenSuperseded(db)
            )
        }
        guard !isSuperseded else {
            try pool.close()
            throw StoreOpenError.newerSchema
        }
        guard !isComplete else { return DatabaseStore(writer: pool) }
        guard !applied.isEmpty else {
            try migrator.migrate(pool)
            return DatabaseStore(writer: pool)
        }

        let snapshot = snapshotURL(for: url)
        try removeFiles(of: snapshot)
        try backup(pool, to: snapshot)
        try backup(pool, to: migrating)
        do {
            // Closing alone may leave the WAL: the pool's last connections are read-only and can't checkpoint.
            _ = try pool.writeWithoutTransaction { try $0.checkpoint(.truncate) }
            try pool.close()
        } catch {
            throw StoreOpenError.databaseBusy
        }

        do {
            let copy = try DatabaseQueue(path: migrating.path(percentEncoded: false), configuration: configuration)
            try migrator.migrate(copy)
            try copy.close()
        } catch {
            try? removeFiles(of: migrating)
            throw StoreOpenError.migrationFailed(snapshot: snapshot, reason: String(describing: error))
        }

        try swap(migrating, into: url)
        return DatabaseStore(
            writer: try DatabasePool(path: url.path(percentEncoded: false), configuration: configuration))
    }

    private static func backup(_ pool: DatabasePool, to url: URL) throws {
        let copy = try DatabaseQueue(path: url.path(percentEncoded: false))
        try pool.backup(to: copy)
        try copy.close()
    }

    /// The WAL must be empty, or SQLite would replay it onto the new file.
    private static func swap(_ migrated: URL, into url: URL) throws {
        let wal = sidecar(of: url, "-wal")
        let walSize = (try? wal.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard walSize == 0 else { throw StoreOpenError.databaseBusy }
        try removeFiles(of: url, keepingDatabase: true)
        guard Foundation.rename(migrated.path(percentEncoded: false), url.path(percentEncoded: false)) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
        }
    }

    private static func sidecar(of url: URL, _ suffix: String) -> URL {
        URL(filePath: url.path(percentEncoded: false) + suffix)
    }

    private static func removeFiles(of url: URL, keepingDatabase: Bool = false) throws {
        let fileManager = FileManager.default
        for file in (keepingDatabase ? [] : [url]) + [sidecar(of: url, "-wal"), sidecar(of: url, "-shm")]
        where fileManager.fileExists(atPath: file.path(percentEncoded: false)) {
            try fileManager.removeItem(at: file)
        }
    }

    public func close() throws {
        try writer.close()
    }
}
