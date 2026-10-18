import SwiftUI

enum AppSection: CaseIterable, Identifiable {
    case decks
    case practice
    case settings

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .decks: "Decks"
        case .practice: "Practice"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .decks: "rectangle.stack"
        case .practice: "brain.head.profile"
        case .settings: "gearshape"
        }
    }
}
