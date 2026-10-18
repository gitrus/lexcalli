import SwiftUI

/// Settings grouped into pages; each row opens one page, and pages don't go deeper.
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                link(to: .cards)
                link(to: .appearance)
            }
            Section {
                link(to: .about)
            }
        }
        .labelStyle(.glassIcon)
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsPage.self) { page in
            switch page {
            case .cards: CardSettingsView()
            case .appearance: AppearanceSettingsView()
            case .about: AboutView()
            }
        }
    }

    private func link(to page: SettingsPage) -> some View {
        NavigationLink(value: page) {
            Label(page.title, systemImage: page.systemImage)
        }
    }
}

enum SettingsPage: Hashable {
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
    }
}
