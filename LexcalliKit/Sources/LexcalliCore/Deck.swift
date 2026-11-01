import Foundation

/// A named collection of notes in one language pair, such as German → English.
public struct Deck: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    /// Language of each note's `term`.
    public var termLanguage: Locale.Language
    /// Language of each note's `meaning`.
    public var meaningLanguage: Locale.Language
    public var notes: [Note]

    public init(
        id: UUID = UUID(),
        name: String,
        termLanguage: Locale.Language,
        meaningLanguage: Locale.Language,
        notes: [Note] = []
    ) {
        self.id = id
        self.name = name
        self.termLanguage = termLanguage
        self.meaningLanguage = meaningLanguage
        self.notes = notes
    }
}
