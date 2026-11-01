import Foundation
import LexcalliCore

/// The deck a new library starts with, bundled as `StarterDeck.json`: Greek → Russian phrases of "Μάθημα 2. Γεια σου".
enum StarterDeck {
    /// Adds the deck once per library, next to any decks it already has; deleting the deck doesn't bring it back.
    /// `name` tells libraries apart, such as the ones UI tests open.
    nonisolated static func addIfNew(to library: Library, named name: String, defaults: UserDefaults = .standard)
        async throws
    {
        let deck = try deck()
        // Per deck, so a new starter deck is added too.
        let key = "starterDeckAdded.\(name).\(deck.id)"
        guard !defaults.bool(forKey: key) else { return }
        var summaries = library.decks.deckSummaries().makeAsyncIterator()
        // Already there, for example from an earlier copy: keep it as it is.
        if try await !(summaries.next() ?? []).contains(where: { $0.id == deck.id }) {
            try await library.decks.save(deck, at: .now)
        }
        defaults.set(true, forKey: key)
    }

    nonisolated static func deck(bundle: Bundle = .main) throws -> Deck {
        guard let url = bundle.url(forResource: "StarterDeck", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        return Deck(
            id: file.id,
            name: file.name,
            termLanguage: .init(identifier: file.termLanguage),
            meaningLanguage: .init(identifier: file.meaningLanguage),
            notes: file.notes.map { Note(id: $0.id, term: $0.term, meaning: $0.meaning) }
        )
    }

    /// Fixed IDs keep the deck's identity across launches and installs.
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
