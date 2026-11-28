import Foundation
import Testing

@testable import LexcalliImport

struct ApkgDeckFormatTests {
    @Test(arguments: ["current-new.apkg", "legacy-new.apkg", "current-progress.apkg", "legacy-progress.apkg"])
    func ankiNotesReadAsText(name: String) throws {
        let deck = try read(name)

        #expect(deck.name == "Lexcalli Synthetic CC0")
        #expect(deck.notes.map(\.term) == ["άλφα", "βήτα", "γεια σου", "νερό"])
        #expect(deck.notes.map(\.meaning) == ["alpha", "beta", "hello", "water"])
        #expect(deck.skippedNotes == 0)
        #expect(deck.notes.allSatisfy { $0.audio.isEmpty && $0.image == nil })
    }

    /// Both formats of one export carry the same Anki deck id and note `guid`s, so re-importing updates in place.
    @Test func ankiIdentitiesDoNotDependOnTheFormat() throws {
        let current = try read("current-new.apkg")
        let legacy = try read("legacy-new.apkg")

        #expect(current.id == legacy.id)
        #expect(current.notes.map(\.id) == legacy.notes.map(\.id))
        #expect(Set(current.notes.map(\.id)).count == current.notes.count)
    }

    @Test func stableIDsAreVersion8AndRepeatable() {
        let id = CollectionReader.stableID("imported-note", "hHe;O%RV,3")

        #expect(id == CollectionReader.stableID("imported-note", "hHe;O%RV,3"))
        #expect(id != CollectionReader.stableID("imported-deck", "hHe;O%RV,3"))
        #expect(id.uuidString.dropFirst(14).first == "8")
    }

    @Test(arguments: [
        ("άλφα<br><img src=\"pixel.png\"> [sound:tone.wav]", "άλφα"),
        ("<div>to remember</div><div>to recall</div>", "to remember to recall"),
        ("salt &amp; pepper&nbsp;", "salt & pepper"),
        ("&lt;b&gt; &#233;t&#xE9; &unknown;", "<b> été &unknown;"),
        ("  spaced\n\tout  ", "spaced out"),
        ("[sound:only.mp3]", ""),
    ])
    func ankiFieldHTMLAsPlainText(html: String, text: String) {
        #expect(FieldText.plain(html) == text)
    }

    @Test func ankiPackageErrorsBecomeDeckFileErrors() throws {
        let notAPackage = try staged(Data("plain text".utf8), named: "notes.apkg")
        defer { try? FileManager.default.removeItem(at: notAPackage.deletingLastPathComponent()) }
        #expect(throws: DeckFileError.unsupportedFile) { _ = try read(notAPackage) }

        let fixture = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        #expect(throws: DeckFileError.tooLarge) {
            _ = try read(fixture.appendingPathComponent("current-new.apkg"), limits: UnpackLimits(maxArchiveBytes: 64))
        }
        #expect(throws: DeckFileError.unreadable) {
            _ = try read(fixture.appendingPathComponent("bad-current-db.apkg"))
        }
    }

    @Test func formatClaimsItsExtension() {
        let format: any DeckFileFormat = ApkgDeckFormat()
        #expect(format.filenameExtensions == ["apkg"])
    }

    private func read(_ name: String) throws -> ImportedDeck {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try read(root.appendingPathComponent(name))
    }

    private func read(_ file: URL, limits: UnpackLimits = UnpackLimits()) throws -> ImportedDeck {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("format-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }
        return try ApkgDeckFormat(limits: limits).read(file, staging: staging)
    }

    private func staged(_ data: Data, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "format-input-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let file = directory.appendingPathComponent(name)
        try data.write(to: file)
        return file
    }
}
