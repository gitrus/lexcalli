import LexcalliCore
import SwiftUI

struct PracticeView: View {
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading

    var body: some View {
        List(decks.value ?? []) { deck in
            PracticeDeckSection(deck: deck)
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

/// The familiar deck tap still starts Flashcards; Mixed is a separate history-gated entry.
private struct PracticeDeckSection: View {
    let deck: DeckSummary
    @Environment(\.library) private var library
    @Environment(\.practice) private var configuration
    @State private var availability: Observed<Bool> = .loading
    @State private var observationID = 0

    var body: some View {
        Section {
            NavigationLink(value: AppRoute.practice(deck: deck.id, name: deck.name)) {
                DeckRow(progressOf: deck)
            }
            switch availability {
            case .value(true):
                NavigationLink(value: AppRoute.mixedPractice(deck: deck.id, name: deck.name)) {
                    Label("Mixed — \(deck.name)", systemImage: "shuffle")
                }
                .accessibilityIdentifier("practice.mixed.\(deck.id.uuidString)")
            case .loading:
                ProgressView().accessibilityLabel("Checking Mixed availability")
            case .failed(let message):
                VStack(alignment: .leading) {
                    Text("Mixed Unavailable")
                    Text(message).font(configuration.failureFont)
                    Button("Try Again") { observationID += 1 }
                }
            case .value(false):
                EmptyView()
            }
        }
        .observe({ library.reviews.hasCardReviews(deck: deck.id) }, id: observationID, into: $availability)
    }
}

#Preview {
    NavigationStack {
        PracticeView()
            .appRouteDestinations()
    }
    .environment(\.library, SampleLibrary.preview)
}
