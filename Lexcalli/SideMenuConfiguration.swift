import SwiftUI

/// Look and timing of `SideMenu` and how `RootView` presents it. Change a default here, or override it for a subtree
/// through the environment, for example `.environment(\.sideMenu.width, 320)`.
nonisolated struct SideMenuConfiguration: Equatable {
    var width: CGFloat = 280
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 12
    /// Gap between the panel and the screen edges.
    var edgeInset: CGFloat = 8
    /// Text style of the wordmark; it scales with Dynamic Type.
    var wordmarkStyle: Font.TextStyle = .title
    var rowSpacing: CGFloat = 4
    var rowInsets = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
    var rowMinimumCornerRadius: CGFloat = 12
    /// Icon circle size at the default text size; it grows with Dynamic Type.
    var iconSize: CGFloat = 40
    /// Largest factor the icon circle grows by with Dynamic Type, so long titles keep their room.
    var iconMaxScale: CGFloat = 1.5
    /// Gap between the panel and the trailing screen edge at accessibility text sizes, where the panel widens to fit
    /// its rows; the scrim stays visible there, so tapping it still closes the menu.
    var accessibilityTrailingInset: CGFloat = 48
    var scrimOpacity: Double = 0.3
    var animation: Animation = .snappy
    /// Crossfade used instead of the slide when Reduce Motion is on.
    var reduceMotionDuration: TimeInterval = 0.2
    /// Drag distance before the swipe-to-close gesture starts tracking.
    var swipeMinimumDistance: CGFloat = 20
    /// Leftward drag distance that closes the menu.
    var swipeToCloseDistance: CGFloat = 60
}

extension EnvironmentValues {
    @Entry var sideMenu = SideMenuConfiguration()
}
