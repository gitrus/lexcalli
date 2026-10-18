import SwiftUI

/// Look of the settings rows. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.settingsList.iconSize, 36)`.
nonisolated struct SettingsListConfiguration: Equatable {
    /// Glass circle size at the default text size; it grows with Dynamic Type.
    var iconSize: CGFloat = 32
    /// Size of the symbol inside the circle.
    var iconScale: Image.Scale = .small
}

extension EnvironmentValues {
    @Entry var settingsList = SettingsListConfiguration()
}
