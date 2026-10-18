import LexcalliCore
import SwiftUI

struct DecksView: View {
    let decks: [Deck]

    var body: some View {
        List(decks) { deck in
            NavigationLink(value: deck) {
                DeckRow(deck: deck)
            }
        }
        .overlay {
            if decks.isEmpty {
                ContentUnavailableView(
                    "No Decks Yet",
                    systemImage: "rectangle.stack",
                    description: Text("Imported decks will appear here.")
                )
            }
        }
        .navigationTitle("Decks")
        .navigationDestination(for: Deck.self) { DeckView(deck: $0) }
    }
}

private struct DeckRow: View {
    let deck: Deck

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
        .badge(deck.notes.count)
    }
}

#Preview {
    NavigationStack {
        DecksView(decks: Deck.samples)
    }
}

#Preview("Empty") {
    NavigationStack {
        DecksView(decks: [])
    }
}
