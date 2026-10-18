import SwiftUI

struct RootView: View {
    @State private var selection: AppSection = .decks
    @State private var isMenuOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                Color.black.opacity(0.3)
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
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: isMenuOpen)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        case .decks: DecksView()
        case .practice: PracticeView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView()
}
