import Foundation

/// One piece of learning content: a word, collocation, or expression with its meaning and media.
/// Cards for practice are built from notes.
public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The word or expression being learned, in the deck's `termLanguage`.
    public var term: String
    /// Its meaning, in the deck's `meaningLanguage`.
    public var meaning: String
    /// Pronunciation of `term`, for example IPA.
    public var transcription: String?
    /// An example sentence using `term`.
    public var example: String?
    public var image: MediaReference?
    public var audio: [MediaReference]

    public init(
        id: UUID = UUID(),
        term: String,
        meaning: String,
        transcription: String? = nil,
        example: String? = nil,
        image: MediaReference? = nil,
        audio: [MediaReference] = []
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.transcription = transcription
        self.example = example
        self.image = image
        self.audio = audio
    }
}
