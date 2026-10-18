import LexcalliCore
import SwiftUI

struct RootView: View {
    @State private var selection: AppSection = .decks
    @State private var isMenuOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sideMenu) private var menuConfiguration

    var body: some View {
        NavigationStack {
            sectionContent
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Menu", systemImage: "line.3.horizontal") {
                            isMenuOpen = true
                        }
                    }
                }
        }
        // Hide the main screen from VoiceOver while the menu covers it.
        .accessibilityHidden(isMenuOpen)
        .overlay {
            if isMenuOpen {
                Color.black.opacity(menuConfiguration.scrimOpacity)
                    .ignoresSafeArea()
                    .onTapGesture { isMenuOpen = false }
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .leading) {
            if isMenuOpen {
                SideMenu(selection: $selection, isOpen: $isMenuOpen)
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: menuConfiguration.reduceMotionDuration) : menuConfiguration.animation,
            value: isMenuOpen
        )
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        // Sample decks until decks can be imported.
        case .decks: DecksView(decks: Deck.samples)
        case .practice: PracticeView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView()
}
