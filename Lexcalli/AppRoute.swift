import LexcalliCore
import SwiftUI

/// Every pushed screen. Routes carry identities, not models: destinations observe their content. A deck's name
/// comes along only as the title to show while it loads, so the title doesn't arrive late.
enum AppRoute: Hashable, Codable {
    case deck(Deck.ID, name: String)
    case word(Note.ID, deck: Deck.ID)
    case practice(deck: Deck.ID, name: String)
    case settings(SettingsPage)

    @ViewBuilder
    var destination: some View {
        switch self {
        case .deck(let id, let name): DeckView(deckID: id, name: name)
        case .word(let id, let deckID): WordView(noteID: id, deckID: deckID)
        case .practice(let deckID, let name): PracticeSessionView(deckID: deckID, name: name)
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
