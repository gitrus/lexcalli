import Foundation
import LexcalliCore

/// Sample decks for previews and UI tests; their media goes through a media library like imported media.
enum SampleLibrary {
    /// Copies the bundled media into `media`.
    nonisolated static func decks(media: MediaLibrary) throws -> [Deck] {
        func add(_ name: String, _ ext: String) throws -> MediaReference? {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return try media.addSynchronously(contentsOf: url, filename: "\(name).\(ext)", maxBytes: 10_000_000)
        }
        // Fixed IDs keep seeded decks stable across launches.
        return [
            Deck(
                id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000001")!,
                name: "German Basics",
                termLanguage: .init(identifier: "de"),
                meaningLanguage: .init(identifier: "en"),
                notes: [
                    // Photo: "Admiral (Juli 2024)", Wikimedia Commons, CC0.
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000101")!,
                        term: "der Schmetterling",
                        meaning: "butterfly",
                        transcription: "/deːɐ̯ ˈʃmɛtɐlɪŋ/",
                        example: "Der Schmetterling sitzt auf der Blume.",
                        image: try add("schmetterling", "jpg"),
                        audio: try add("schmetterling", "m4a").map { [$0] } ?? []
                    ),
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000102")!,
                        term: "die Blume", meaning: "flower", transcription: "/ˈbluːmə/"),
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000103")!,
                        term: "der Baum", meaning: "tree", transcription: "/baʊ̯m/"),
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000104")!,
                        term: "jemandem Bescheid sagen", meaning: "to let someone know"),
                ]
            ),
            Deck(
                id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000002")!,
                name: "Japanese Nature",
                termLanguage: .init(identifier: "ja"),
                meaningLanguage: .init(identifier: "en"),
                notes: [
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000201")!,
                        term: "蝶々", meaning: "butterfly", transcription: "ちょうちょう"),
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000202")!,
                        term: "花", meaning: "flower", transcription: "はな"),
                    Note(
                        id: UUID(uuidString: "5A3B6C1E-0D2F-4E11-9C1A-000000000203")!,
                        term: "木", meaning: "tree", transcription: "き"),
                ]
            ),
        ]
    }

    nonisolated static func seedIfEmpty(_ library: Library) async throws {
        var summaries = library.decks.deckSummaries().makeAsyncIterator()
        guard try await summaries.next()?.isEmpty ?? true else { return }
        for deck in try decks(media: library.media) {
            try await library.decks.save(deck, at: .now)
        }
    }

    static let preview: Library = {
        let media = MediaLibrary(root: URL.temporaryDirectory.appending(path: "Lexcalli-preview-media"))
        let decks = (try? SampleLibrary.decks(media: media)) ?? []
        return Library(store: InMemoryStore(decks: decks), media: media)
    }()

    static var previewDecks: [Deck] {
        (try? decks(media: preview.media)) ?? []
    }
}
