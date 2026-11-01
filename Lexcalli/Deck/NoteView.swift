import LexcalliCore
import SwiftUI

/// A note as a flashcard: the term with its media on the front, the meaning and example on the back.
struct NoteView: View {
    let note: Note
    let termLanguage: Locale.Language
    let meaningLanguage: Locale.Language

    @State private var isFlipped = false
    @Environment(\.library) private var library
    @AppStorage(PreferenceKey.cardSerifText) private var serifText = false
    @AppStorage(PreferenceKey.cardShowsTranscription) private var showsTranscription = true

    var body: some View {
        let sides = note.sides(
            .forward, termLanguage: termLanguage, meaningLanguage: meaningLanguage, media: library.media,
            showsTranscription: showsTranscription)
        FlashCard(front: sides.front, back: sides.back, isFlipped: $isFlipped)
            .fontDesign(serifText ? .serif : nil)
            .padding()
    }
}

#Preview {
    let deck = SampleLibrary.previewDecks[0]
    NoteView(note: deck.notes[0], termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
        .environment(\.library, SampleLibrary.preview)
}

struct WordView: View {
    let noteID: Note.ID
    let deckID: Deck.ID

    @Environment(\.library) private var library
    @State private var deck: Observed<Deck?> = .loading

    var body: some View {
        content
            .observe({ [decks = library.decks] in decks.deck(deckID) }, id: deckID, into: $deck)
    }

    @ViewBuilder
    private var content: some View {
        switch deck {
        case .loading:
            ProgressView()
        case .failed(let message):
            LoadFailureView(title: "Word Unavailable", message: message)
        case .value(let deck):
            if let deck, let note = deck.notes.first(where: { $0.id == noteID }) {
                VStack {
                    NoteView(note: note, termLanguage: deck.termLanguage, meaningLanguage: deck.meaningLanguage)
                    CardStatusView(noteID: note.id)
                }
            } else {
                ContentUnavailableView("Word Not Found", systemImage: "text.book.closed")
            }
        }
    }
}

/// Reviews applied and next due date per direction, from the FSRS projection.
private struct CardStatusView: View {
    let noteID: Note.ID

    @Environment(\.library) private var library
    @State private var statuses: [CardDirection: (reviews: Int, due: Date)] = [:]
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(CardDirection.allCases, id: \.self) { direction in
                if let status = statuses[direction] {
                    LabeledContent(direction.title) {
                        Text(
                            "^[\(status.reviews) review](inflect: true), due \(status.due.formatted(date: .abbreviated, time: .shortened))"
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cardStatus.\(direction)")
                }
            }
            if let failure {
                Text(failure).foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .padding(.horizontal)
        .task(id: noteID) {
            do {
                for direction in CardDirection.allCases {
                    let card = Card.ID(noteID: noteID, direction: direction)
                    guard let scheduling = try await library.reviews.projection(of: card)?.scheduling else { continue }
                    statuses[direction] = (scheduling.reps, scheduling.due)
                }
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

extension CardDirection {
    var title: LocalizedStringKey {
        switch self {
        case .forward: "Word → Meaning"
        case .reverse: "Meaning → Word"
        }
    }
}
