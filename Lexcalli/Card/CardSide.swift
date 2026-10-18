import Foundation

/// What one side of a flashcard shows. The text is learning content, so it is displayed as-is, not localized.
struct CardSide: Hashable {
    var text: String
    var detail: String?
    /// Pronunciation, for example IPA. Shown next to the audio buttons.
    var transcription: String?
    var imageURL: URL?
    var audioURLs: [URL] = []
    /// Language of this side's text, so the system picks fitting fonts and line breaking (for example, for Japanese).
    /// It comes from the deck's `termLanguage` or `meaningLanguage`, not from each note.
    var language: Locale.Language?
}
