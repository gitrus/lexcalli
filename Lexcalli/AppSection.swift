import SwiftUI

enum AppSection: CaseIterable, Identifiable {
    case practice
    case decks
    case settings

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .practice: "Practice"
        case .decks: "Decks"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .practice: "brain.head.profile"
        case .decks: "rectangle.stack"
        case .settings: "gearshape"
        }
    }
}
