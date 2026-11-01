import LexcalliCore
import SwiftUI

struct RootView: View {
    @State private var selection: AppSection = .decks
    @State private var path: [AppRoute] = []
    @State private var isMenuOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sideMenu) private var menuConfiguration
    @AppStorage(PreferenceKey.appearance) private var appearance = Appearance.system

    var body: some View {
        NavigationStack(path: $path) {
            sectionContent
                .appRouteDestinations()
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
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: selection) { path = [] }
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
        .environment(\.library, SampleLibrary.preview)
}
