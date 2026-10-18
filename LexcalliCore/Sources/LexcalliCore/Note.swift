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
    public var imageURL: URL?
    public var audioURLs: [URL]

    public init(
        id: UUID = UUID(),
        term: String,
        meaning: String,
        transcription: String? = nil,
        example: String? = nil,
        imageURL: URL? = nil,
        audioURLs: [URL] = []
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.transcription = transcription
        self.example = example
        self.imageURL = imageURL
        self.audioURLs = audioURLs
    }
}
