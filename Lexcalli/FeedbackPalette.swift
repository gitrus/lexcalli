import SwiftUI

/// Shared feedback colors. Override a field for a subtree with `.environment(\.feedbackPalette.mistake, .red)`.
nonisolated struct FeedbackPalette: Equatable {
    var selection: Color = .accentColor
    var mistake: Color = .orange
    var correction: Color = .green
    var mistakeHighlightOpacity: Double = 0.12
    var correctionHighlightOpacity: Double = 0.18

    var mistakeHighlight: Color { mistake.opacity(mistakeHighlightOpacity) }
    var correctionHighlight: Color { correction.opacity(correctionHighlightOpacity) }
}

extension EnvironmentValues {
    @Entry var feedbackPalette = FeedbackPalette()
}
