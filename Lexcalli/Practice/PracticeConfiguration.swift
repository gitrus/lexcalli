import SwiftUI

/// Look of the practice screen. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.practice.controlSpacing, 16)`.
nonisolated struct PracticeConfiguration: Equatable {
    var controlSpacing: CGFloat = 12
    var progressFont: Font = .subheadline
    var failureFont: Font = .footnote
    var doneMinWidth: CGFloat = 160
}

extension EnvironmentValues {
    @Entry var practice = PracticeConfiguration()
}
