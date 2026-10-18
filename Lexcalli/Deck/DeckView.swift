import LexcalliCore
import SwiftUI

/// The words in one deck.
struct DeckView: View {
    let deck: Deck

    @State private var isShowingOverview = false

    var body: some View {
        List(deck.notes) { note in
            NavigationLink(value: note) {
                NoteRow(note: note, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
            }
        }
        .overlay {
            if deck.notes.isEmpty {
                ContentUnavailableView(
                    "No Words Yet",
                    systemImage: "text.book.closed",
                    description: Text("Words in this deck will appear here.")
                )
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Deck Options", systemImage: "ellipsis") {
                    Button("Overview", systemImage: "info.circle") { isShowingOverview = true }
                    // Placeholders: decks are read-only sample data until they can be imported and stored.
                    Group {
                        Button("Rename", systemImage: "pencil") {}
                        Divider()
                        Button("Delete Deck", systemImage: "trash", role: .destructive) {}
                    }
                    .disabled(true)
                }
            }
        }
        .sheet(isPresented: $isShowingOverview) {
            DeckOverviewView(deck: deck)
        }
        .navigationDestination(for: Note.self) {
            NoteView(note: $0, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let termLanguage: Locale.Language
    let meaningLanguage: Locale.Language

    @Environment(\.deckList) private var configuration

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(note.term)
                    .font(configuration.rowTitleFont)
                    .typesettingLanguage(termLanguage)
                Text(note.meaning)
                    .font(configuration.rowSubtitleFont)
                    .foregroundStyle(.secondary)
                    .typesettingLanguage(meaningLanguage)
            }

            Spacer()

            // What the note's card offers besides text; the audio symbol matches the card's play button.
            // Transcription goes last, next to the chevron, so it lines up across rows: most notes have one.
            HStack {
                if !note.audioURLs.isEmpty {
                    Image(systemName: "speaker.wave.2")
                        .accessibilityLabel("Has audio")
                }
                if note.transcription != nil {
                    Image(systemName: "character.phonetic")
                        .accessibilityLabel("Has transcription")
                }
            }
            .imageScale(configuration.rowIconScale)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DeckView(deck: Deck.samples[0])
    }
}
