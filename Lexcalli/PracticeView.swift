import LexcalliCore
import SwiftUI

struct PracticeView: View {
    var body: some View {
        Group {
            // Sample card for checking FlashCard on a device until practice draws cards from decks.
            if let deck = Deck.samples.first, let note = deck.notes.first {
                NoteView(note: note, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
            } else {
                ContentUnavailableView(
                    "Nothing to Practice",
                    systemImage: "brain.head.profile",
                    description: Text("Words from your decks will appear here.")
                )
            }
        }
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack {
        PracticeView()
    }
}
