import SwiftUI

/// Look and timing of `FlashCard`. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.flashCard.flipDuration, 0.8)`.
nonisolated struct FlashCardConfiguration: Equatable {
    /// The card fills the space it gets, up to this height.
    var maxHeight: CGFloat = 520
    var flipDuration: TimeInterval = 0.45
    var cornerRadius: CGFloat = 32
    var padding: CGFloat = 24
    var spacing: CGFloat = 16
    var textFont: Font = .largeTitle.bold()
    var detailFont: Font = .body
    var transcriptionFont: Font = .title3
    /// How far long text may shrink to fit, as a fraction of `textFont`.
    var minimumTextScale: CGFloat = 0.5
    var imageMaxHeight: CGFloat = 220
    var imageMinimumCornerRadius: CGFloat = 12
}

extension EnvironmentValues {
    @Entry var flashCard = FlashCardConfiguration()
}
