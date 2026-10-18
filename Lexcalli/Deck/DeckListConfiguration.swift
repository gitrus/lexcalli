import SwiftUI

/// Look of the rows in the deck list and the word list. Change a default here, or override it for a subtree
/// through the environment, for example `.environment(\.deckList.rowTitleFont, .body)`.
nonisolated struct DeckListConfiguration: Equatable {
    /// Deck name or word.
    var rowTitleFont: Font = .headline
    /// Language pair or meaning.
    var rowSubtitleFont: Font = .subheadline
    /// Size of the audio and transcription symbols in word rows.
    var rowIconScale: Image.Scale = .small
}

extension EnvironmentValues {
    @Entry var deckList = DeckListConfiguration()
}
