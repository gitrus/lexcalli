import Foundation
import LexcalliCore

/// The decks a new library starts with, bundled as `StarterDecks.json`: Greek → Russian lessons, "Μάθημα 2" onward.
enum StarterDecks {
    /// Adds each deck once per library, next to any decks it already has; deleting a deck doesn't bring it back.
    /// `name` tells libraries apart, such as the ones UI tests open.
    nonisolated static func addNew(to library: Library, named name: String, defaults: UserDefaults = .standard)
        async throws
    {
        var summaries = library.decks.deckSummaries().makeAsyncIterator()
        let existingIDs = Set((try await summaries.next() ?? []).map(\.id))
        for deck in try decks() {
            // Per deck, so a deck added to the bundle later still reaches existing libraries.
            let key = "starterDeckAdded.\(name).\(deck.id)"
            guard !defaults.bool(forKey: key) else { continue }
            // Already there, for example from an earlier copy: keep it as it is.
            if !existingIDs.contains(deck.id) {
                try await library.decks.save(deck, at: .now)
            }
            defaults.set(true, forKey: key)
        }
    }

    nonisolated static func decks(bundle: Bundle = .main) throws -> [Deck] {
        guard let url = bundle.url(forResource: "StarterDecks", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([File].self, from: Data(contentsOf: url)).map { file in
            Deck(
                id: file.id,
                name: file.name,
                termLanguage: .init(identifier: file.termLanguage),
                meaningLanguage: .init(identifier: file.meaningLanguage),
                notes: file.notes.map { Note(id: $0.id, term: $0.term, meaning: $0.meaning) }
            )
        }
    }

    /// Fixed IDs keep each deck's identity across launches and installs.
    private nonisolated struct File: Decodable {
        struct Entry: Decodable {
            let id: UUID
            let term: String
            let meaning: String
        }

        let id: UUID
        let name: String
        let termLanguage: String
        let meaningLanguage: String
        let notes: [Entry]
    }
}
