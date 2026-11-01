import LexcalliCore
import SwiftUI

struct DecksView: View {
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading

    var body: some View {
        List(decks.value ?? []) { deck in
            NavigationLink(value: AppRoute.deck(deck.id)) {
                DeckRow(deck: deck)
            }
        }
        .overlay {
            switch decks {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadFailureView(title: "Decks Unavailable", message: message)
            case .value(let decks) where decks.isEmpty:
                ContentUnavailableView(
                    "No Decks Yet",
                    systemImage: "rectangle.stack",
                    description: Text("Imported decks will appear here.")
                )
            case .value:
                EmptyView()
            }
        }
        .navigationTitle("Decks")
        .observe({ [decks = library.decks] in decks.deckSummaries() }, id: 0, into: $decks)
    }
}

private struct DeckRow: View {
    let deck: DeckSummary

    @Environment(\.locale) private var locale
    @Environment(\.deckList) private var configuration

    var body: some View {
        let languages = (locale.name(of: deck.termLanguage), locale.name(of: deck.meaningLanguage))
        VStack(alignment: .leading) {
            Text(deck.name)
                .font(configuration.rowTitleFont)
            Text("\(languages.0) → \(languages.1)")
                .font(configuration.rowSubtitleFont)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(languages.0) to \(languages.1)")
        }
        .badge(deck.noteCount)
    }
}

#Preview {
    NavigationStack {
        DecksView()
            .appRouteDestinations()
    }
    .environment(\.library, SampleLibrary.preview)
}

#Preview("Empty") {
    NavigationStack {
        DecksView()
    }
    .environment(\.library, Library(store: InMemoryStore(), media: SampleLibrary.preview.media))
}
