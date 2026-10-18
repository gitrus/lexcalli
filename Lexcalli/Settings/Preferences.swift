import SwiftUI

/// `UserDefaults` keys of the user's choices in Settings, shared by the settings pages and the views they change.
/// Each `@AppStorage` that reads a key repeats its default, so keep them equal: see the comments below.
enum PreferenceKey {
    /// `Appearance` raw value; defaults to `.system`.
    static let appearance = "appearance"
    /// Whether card text uses the serif design; defaults to `false`.
    static let cardSerifText = "card.serifText"
    /// Whether cards show the pronunciation transcription; defaults to `true`.
    static let cardShowsTranscription = "card.showsTranscription"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
