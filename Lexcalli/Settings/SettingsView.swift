import SwiftUI

/// Settings grouped into pages; each row opens one page, and pages don't go deeper.
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                link(to: .cards)
                link(to: .appearance)
            }
            .listRowBackground(Color.paper)
            Section {
                link(to: .about)
            }
            .listRowBackground(Color.paper)
        }
        .labelStyle(.glassIcon)
        .paperGroupedBackground()
        .navigationTitle("Settings")
    }

    private func link(to page: SettingsPage) -> some View {
        NavigationLink(value: AppRoute.settings(page)) {
            Label(page.title, systemImage: page.systemImage)
        }
    }
}

enum SettingsPage: Hashable, Codable {
    case cards
    case appearance
    case about

    var title: LocalizedStringKey {
        switch self {
        case .cards: "Cards"
        case .appearance: "Appearance"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .cards: "rectangle.on.rectangle"
        case .appearance: "circle.lefthalf.filled"
        case .about: "info"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appRouteDestinations()
    }
}
