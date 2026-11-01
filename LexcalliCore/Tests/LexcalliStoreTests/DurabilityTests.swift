import Foundation
import GRDB
import LexcalliCore
import Testing

@testable import LexcalliStore

/// What in-memory contracts can't check: reopening, WAL, migrations, media files.
@Suite struct DurabilityTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let directory: TemporaryDirectory
    let deck = Deck(
        name: "German",
        termLanguage: .init(identifier: "de"),
        meaningLanguage: .init(identifier: "en"),
        notes: [
            Note(
                term: "der Schmetterling", meaning: "butterfly", transcription: "/ˈʃmɛtɐlɪŋ/",
                image: MediaReference(hash: "ab12", filename: "schmetterling.jpg"),
                audio: [MediaReference(hash: "cd34", filename: "schmetterling.m4a")]),
            Note(term: "der Baum", meaning: "tree"),
        ]
    )

    init() throws {
        directory = try TemporaryDirectory()
    }

    var databaseURL: URL { directory.url.appending(path: "Lexcalli.sqlite") }

    /// One ended session with an answer, and one left open with another.
    func populate(_ store: DatabaseStore) async throws -> (ended: CardReviewEvent, open: CardReviewEvent) {
        try await store.save(deck, at: now)
        let first = try await store.openSession(UUID(), deck: deck.id, at: now)
        let ended = CardReviewEvent(sessionID: first.session.id, cardID: first.queue[0], rating: .good, answeredAt: now)
        _ = try await store.record(ended)
        _ = try await store.endSession(first.session.id, at: now)

        let later = now.addingTimeInterval(120)
        let second = try await store.openSession(UUID(), deck: deck.id, at: later)
        let open = CardReviewEvent(
            sessionID: second.session.id, cardID: second.queue[0], rating: .hard, answeredAt: later)
        _ = try await store.record(open)
        return (ended, open)
    }

    func expectContents(of store: DatabaseStore, _ events: (ended: CardReviewEvent, open: CardReviewEvent)) async throws
    {
        var observed = store.deck(deck.id).makeAsyncIterator()
        #expect(try await observed.next() == deck)
        #expect(try await store.reviewEvents(of: events.ended.cardID) == [events.ended])
        #expect(try await store.reviewEvents(of: events.open.cardID) == [events.open])
        let projection = try #require(try await store.projection(of: events.ended.cardID))
        #expect(projection.scheduling.reps == 1)
        #expect(projection.checkpoint?.position == events.ended.position)
        #expect(try await store.session(events.open.sessionID!)?.status == .open)
    }

    @Test func reopensWithEverythingCommitted() async throws {
        let store = try DatabaseStore.open(at: databaseURL)
        let events = try await populate(store)
        try store.close()

        let reopened = try DatabaseStore.open(at: databaseURL)
        try await expectContents(of: reopened, events)

        // The open session is recovered and its answer applied once.
        let next = try await reopened.openSession(UUID(), deck: deck.id, at: now.addingTimeInterval(300))
        #expect(next.recovered.endedSessions == [events.open.sessionID!])
        #expect(next.recovered.projectedCards == [events.open.cardID])
        #expect(try await reopened.projection(of: events.open.cardID)?.scheduling.reps == 1)
    }

    @Test func recoversCommittedDataStillInWAL() async throws {
        let store = try DatabaseStore.open(at: databaseURL)
        let events = try await populate(store)
        let wal = URL(filePath: databaseURL.path(percentEncoded: false) + "-wal")
        #expect(try #require(try wal.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)

        // A terminated process's files: copied while the store is still open.
        let crashed = try TemporaryDirectory()
        for suffix in ["", "-wal", "-shm"] {
            try FileManager.default.copyItem(
                at: URL(filePath: databaseURL.path(percentEncoded: false) + suffix),
                to: URL(filePath: crashed.url.appending(path: "Lexcalli.sqlite").path(percentEncoded: false) + suffix))
        }
        try store.close()

        try await expectContents(of: try DatabaseStore.open(at: crashed.url.appending(path: "Lexcalli.sqlite")), events)
    }

    @Test func upgradesPreviousSchemaKeepingSnapshot() async throws {
        let store = try DatabaseStore.open(at: databaseURL)
        let events = try await populate(store)
        try store.close()

        var next = DatabaseMigrator.lexcalli
        next.registerMigration("test-next-version") { db in
            try db.alter(table: "deck") { $0.add(column: "test_note", .text) }
        }
        let upgraded = try DatabaseStore.open(at: databaseURL, migrator: next)

        try await expectContents(of: upgraded, events)
        let snapshot = DatabaseStore.snapshotURL(for: databaseURL)
        #expect(FileManager.default.fileExists(atPath: snapshot.path(percentEncoded: false)))
        // The snapshot includes what was in the WAL.
        try upgraded.close()
        let previous = try DatabaseStore.open(at: snapshot)
        try await expectContents(of: previous, events)
    }

    @Test func failedMigrationLeavesDatabaseUnchanged() async throws {
        let store = try DatabaseStore.open(at: databaseURL)
        let events = try await populate(store)
        try store.close()

        var failing = DatabaseMigrator.lexcalli
        failing.registerMigration("test-succeeds") { db in try db.create(table: "test_partial") { $0.column("x") } }
        failing.registerMigration("test-fails") { _ in throw TestFailure() }

        #expect {
            try DatabaseStore.open(at: databaseURL, migrator: failing)
        } throws: { error in
            guard case StoreOpenError.migrationFailed(let snapshot, _) = error else { return false }
            return snapshot == DatabaseStore.snapshotURL(for: databaseURL)
        }

        // Only the copy was migrated.
        #expect(!FileManager.default.fileExists(atPath: DatabaseStore.migratingURL(for: databaseURL).path()))
        let unchanged = try DatabaseStore.open(at: databaseURL)
        try await expectContents(of: unchanged, events)
        #expect(try await unchanged.writer.read { try $0.tableExists("test_partial") } == false)
    }

    @Test func copyLeftByInterruptedMigrationIsDiscarded() async throws {
        let store = try DatabaseStore.open(at: databaseURL)
        let events = try await populate(store)
        try store.close()
        // A partial copy left by a termination during migration.
        try Data("partial".utf8).write(to: DatabaseStore.migratingURL(for: databaseURL))

        let reopened = try DatabaseStore.open(at: databaseURL)

        try await expectContents(of: reopened, events)
        #expect(!FileManager.default.fileExists(atPath: DatabaseStore.migratingURL(for: databaseURL).path()))
    }

    @Test func refusesNewerSchema() async throws {
        var newer = DatabaseMigrator.lexcalli
        newer.registerMigration("test-from-the-future") { _ in }
        try DatabaseStore.open(at: databaseURL, migrator: newer).close()

        #expect(throws: StoreOpenError.newerSchema) {
            try DatabaseStore.open(at: databaseURL)
        }
    }

    @Test func mediaSurvivesRecreatingTheLibrary() async throws {
        let source = directory.url.appending(path: "source.m4a")
        try Data("pronunciation".utf8).write(to: source)
        let root = directory.url.appending(path: "Media")

        let reference = try await MediaLibrary(root: root).add(contentsOf: source, filename: "Baum.M4A", maxBytes: 1024)

        let library = MediaLibrary(root: root)
        #expect(library.contains(reference))
        #expect(try Data(contentsOf: library.url(for: reference)) == Data("pronunciation".utf8))
        #expect(library.url(for: reference).lastPathComponent == "\(reference.hash).m4a")
        #expect(reference.hash.count == 64)
    }

    @Test func mediaOverLimitIsNotAdded() async throws {
        let source = directory.url.appending(path: "large.jpg")
        try Data(count: 2048).write(to: source)
        let library = MediaLibrary(root: directory.url.appending(path: "Media"))

        await #expect(throws: MediaLibraryError.tooLarge(filename: "large.jpg", maxBytes: 1024)) {
            try await library.add(contentsOf: source, filename: "large.jpg", maxBytes: 1024)
        }
        #expect(try await library.removeUnreferenced(keeping: []) == 0)
        #expect(!FileManager.default.fileExists(atPath: library.stagingDirectory.path(percentEncoded: false)))
    }

    @Test func unreferencedMediaIsRemoved() async throws {
        let library = MediaLibrary(root: directory.url.appending(path: "Media"))
        var references: [MediaReference] = []
        for content in ["kept", "dropped"] {
            let source = directory.url.appending(path: content)
            try Data(content.utf8).write(to: source)
            references.append(try await library.add(contentsOf: source, filename: "\(content).mp3", maxBytes: 1024))
        }

        #expect(try await library.removeUnreferenced(keeping: [references[0].hash]) == 1)
        #expect(library.contains(references[0]))
        #expect(!library.contains(references[1]))
    }
}

struct TestFailure: Error {}

final class TemporaryDirectory: Sendable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "LexcalliTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
