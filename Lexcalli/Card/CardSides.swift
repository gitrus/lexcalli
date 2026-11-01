import LexcalliCore
import SwiftUI

extension Note {
    /// The front never shows its answer: a reverse card's audio and transcription stay on the back. The image
    /// illustrates the meaning, so both fronts show it. With `speaksMissingAudio`, a term without audio is read aloud
    /// by a system voice instead.
    func sides(
        _ direction: CardDirection,
        termLanguage: Locale.Language,
        meaningLanguage: Locale.Language,
        media: MediaLibrary,
        showsTranscription: Bool,
        speaksMissingAudio: Bool
    ) -> (front: CardSide, back: CardSide) {
        let imageURL = image.map(media.url(for:))
        let audioURLs = audio.map(media.url(for:))
        let spokenText = speaksMissingAudio && audioURLs.isEmpty ? term : nil
        let transcription = showsTranscription ? transcription : nil
        switch direction {
        case .forward:
            return (
                CardSide(
                    text: term, transcription: transcription, imageURL: imageURL, audioURLs: audioURLs,
                    spokenText: spokenText, language: termLanguage),
                CardSide(text: meaning, detail: example, language: meaningLanguage)
            )
        case .reverse:
            return (
                CardSide(text: meaning, imageURL: imageURL, language: meaningLanguage),
                CardSide(
                    text: term, detail: example, transcription: transcription, audioURLs: audioURLs,
                    spokenText: spokenText, language: termLanguage)
            )
        }
    }
}
