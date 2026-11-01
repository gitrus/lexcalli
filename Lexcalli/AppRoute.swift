import LexcalliCore
import SwiftUI

/// Every pushed screen. Routes carry identities, not models: destinations observe their content.
enum AppRoute: Hashable, Codable {
    case deck(Deck.ID)
    case word(Note.ID, deck: Deck.ID)
    case practice(deck: Deck.ID)
    case settings(SettingsPage)

    @ViewBuilder
    var destination: some View {
        switch self {
        case .deck(let id): DeckView(deckID: id)
        case .word(let id, let deckID): WordView(noteID: id, deckID: deckID)
        case .practice(let deckID): PracticeSessionView(deckID: deckID)
        case .settings(.cards): CardSettingsView()
        case .settings(.appearance): AppearanceSettingsView()
        case .settings(.about): AboutView()
        }
    }
}

extension View {
    /// Apply once per navigation stack.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { $0.destination }
    }
}
