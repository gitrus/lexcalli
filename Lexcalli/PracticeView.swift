import LexcalliCore
import SwiftUI

struct PracticeView: View {
    let open: (AppRoute) -> Void
    @Environment(\.library) private var library
    @State private var decks: Observed<[DeckSummary]> = .loading

    var body: some View {
        List(decks.value ?? []) { deck in
            PracticeDeckSection(deck: deck, open: open)
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

/// Deck information stays separate from the explicit mode choices; saved history unlocks Mixed.
private struct PracticeDeckSection: View {
    let deck: DeckSummary
    let open: (AppRoute) -> Void
    @Environment(\.practice) private var configuration

    var body: some View {
        Section {
            DeckRow(progressOf: deck)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: configuration.controlSpacing) { modeButtons }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: configuration.controlSpacing) { modeButtons }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glass)
            .controlSize(configuration.exerciseControlSize)
        } footer: {
            if !deck.hasCardReviews {
                Text("Complete a flashcard review to unlock Mixed.")
                    .font(configuration.modeHintFont)
            }
        }
    }

    @ViewBuilder
    private var modeButtons: some View {
        Button {
            open(.practice(deck: deck.id, name: deck.name))
        } label: {
            Label("Flashcards", systemImage: "rectangle.on.rectangle")
        }
        .accessibilityLabel("Flashcards — \(deck.name)")
        .accessibilityIdentifier("practice.flashcards.\(deck.id.uuidString)")

        Button {
            open(.mixedPractice(deck: deck.id, name: deck.name))
        } label: {
            Label("Mixed", systemImage: "shuffle")
        }
        .disabled(!deck.hasCardReviews)
        .accessibilityLabel("Mixed — \(deck.name)")
        .accessibilityHint(deck.hasCardReviews ? "" : "Complete a flashcard review to unlock Mixed.")
        .accessibilityIdentifier("practice.mixed.\(deck.id.uuidString)")
    }
}

#Preview {
    @Previewable @State var path: [AppRoute] = []
    NavigationStack(path: $path) {
        PracticeView { path.append($0) }
            .appRouteDestinations()
    }
    .environment(\.library, SampleLibrary.preview)
}
