import LexcalliCore
import SwiftUI

struct PracticeView: View {
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading

    var body: some View {
        List(decks.value ?? []) { deck in
            NavigationLink(value: AppRoute.practice(deck: deck.id, name: deck.name)) {
                DeckRow(progressOf: deck)
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
                    "Nothing to Practice",
                    systemImage: "brain.head.profile",
                    description: Text("Words from your decks will appear here.")
                )
            case .value:
                EmptyView()
            }
        }
        .navigationTitle("Practice")
        .observe({ [decks = library.decks] in decks.deckSummaries() }, id: 0, into: $decks)
    }
}

#Preview {
    NavigationStack {
        PracticeView()
            .appRouteDestinations()
    }
    .environment(\.library, SampleLibrary.preview)
}
