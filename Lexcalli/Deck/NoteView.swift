import LexcalliCore
import SwiftUI

/// A note as a flashcard: the term with its media on the front, the meaning and example on the back.
struct NoteView: View {
    let note: Note
    let termLanguage: Locale.Language
    let meaningLanguage: Locale.Language

    @State private var isFlipped = false

    var body: some View {
        FlashCard(
            front: CardSide(
                text: note.term,
                transcription: note.transcription,
                imageURL: note.imageURL,
                audioURLs: note.audioURLs,
                language: termLanguage
            ),
            back: CardSide(text: note.meaning, detail: note.example, language: meaningLanguage),
            isFlipped: $isFlipped
        )
        .padding()
    }
}

#Preview {
    let deck = Deck.samples[0]
    NoteView(note: deck.notes[0], termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
}
