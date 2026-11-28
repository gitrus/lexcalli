import Foundation
import LexcalliCore


public protocol DeckFileFormat: Sendable {
    /// Lowercased filename extensions without the dot
    var filenameExtensions: [String] { get }

    /// Synchronous and cancellable; call from a non-main worker. `file` is an app-owned copy, and `staging` is an empty director
    func read(_ file: URL, staging: URL) throws -> ImportedDeck
}

/// What a learner can act on, whatever the format's own errors were
public enum DeckFileError: Error, Hashable, Sendable {
    case unsupportedFile
    case tooLarge
    case unreadable
}

/// A deck read from a file, before the learner chooses its name and languages.
public struct ImportedDeck: Hashable, Sendable {
    /// Stable for the same source deck, so importing it again updates it.
    public let id: UUID
    /// The name the file gives, or empty.
    public let name: String
    /// Stable IDs for the same source notes, so a re-import keeps their cards and scheduling.
    public let notes: [Note]
    /// Notes left out because they have no word or no meaning.
    public let skippedNotes: Int

    public init(id: UUID, name: String, notes: [Note], skippedNotes: Int) {
        self.id = id
        self.name = name
        self.notes = notes
        self.skippedNotes = skippedNotes
    }

    public func deck(termLanguage: Locale.Language, meaningLanguage: Locale.Language, named name: String) -> Deck {
        Deck(id: id, name: name, termLanguage: termLanguage, meaningLanguage: meaningLanguage, notes: notes)
    }
}
