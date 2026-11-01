import LexcalliCore
import SwiftUI

struct DeckView: View {
    let deckID: Deck.ID

    @Environment(\.library) private var library
    @State private var deck: Observed<Deck?> = .loading
    @State private var isShowingOverview = false

    var body: some View {
        let deck = deck.value ?? nil
        List(deck?.notes ?? []) { note in
            NavigationLink(value: AppRoute.word(note.id, deck: deckID)) {
                NoteRow(note: note, termLanguage: deck!.termLanguage, meaningLanguage: deck!.meaningLanguage)
            }
        }
        .overlay {
            switch self.deck {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadFailureView(title: "Deck Unavailable", message: message)
            case .value(nil):
                ContentUnavailableView("Deck Not Found", systemImage: "rectangle.stack")
            case .value(let deck?) where deck.notes.isEmpty:
                ContentUnavailableView(
                    "No Words Yet",
                    systemImage: "text.book.closed",
                    description: Text("Words in this deck will appear here.")
                )
            case .value:
                EmptyView()
            }
        }
        .navigationTitle(deck?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Deck Options", systemImage: "ellipsis") {
                    Button("Overview", systemImage: "info.circle") { isShowingOverview = true }
                        .disabled(deck == nil)
                    // Placeholders until decks can be edited.
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
            if let deck { DeckOverviewView(deck: deck) }
        }
        .observe({ [decks = library.decks] in decks.deck(deckID) }, id: deckID, into: $deck)
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
                if !note.audio.isEmpty {
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
        DeckView(deckID: SampleLibrary.previewDecks[0].id)
            .appRouteDestinations()
    }
    .environment(\.library, SampleLibrary.preview)
}
