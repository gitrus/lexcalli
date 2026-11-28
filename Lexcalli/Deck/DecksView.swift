import LexcalliCore
import SwiftUI

struct DecksView: View {
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading
    @State private var isPickingFile = false
    @State private var importRequest: DeckImportRequest?

    var body: some View {
        List(decks.value ?? []) { deck in
            NavigationLink(value: AppRoute.deck(deck.id, name: deck.name)) {
                DeckRow(languagesOf: deck)
            }
            .listRowBackground(Color.paper)
        }
        .overlay {
            switch decks {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadFailureView(title: "Decks Unavailable", message: message)
            case .value(let decks) where decks.isEmpty:
                ContentUnavailableView {
                    Label("No Decks Yet", systemImage: "rectangle.stack")
                } description: {
                    Text("Imported decks will appear here.")
                } actions: {
                    Button("Import Deck") { isPickingFile = true }
                }
            case .value:
                EmptyView()
            }
        }
        .paperGroupedBackground()
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import Deck", systemImage: "square.and.arrow.down") { isPickingFile = true }
                    .accessibilityIdentifier("decks.import")
            }
        }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: library.deckFileTypes) { result in
            importRequest = DeckImportRequest(file: result)
        }
        .sheet(item: $importRequest) { DeckImportView(request: $0) }
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
