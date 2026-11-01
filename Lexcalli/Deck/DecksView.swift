import LexcalliCore
import SwiftUI

struct DecksView: View {
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading

    var body: some View {
        List(decks.value ?? []) { deck in
            NavigationLink(value: AppRoute.deck(deck.id, name: deck.name)) {
                DeckRow(languagesOf: deck)
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
    .environment(\.library, .unavailable)
}
