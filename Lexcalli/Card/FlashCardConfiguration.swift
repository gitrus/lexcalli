import AVFoundation
import SwiftUI

/// Look and timing of `FlashCard`. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.flashCard.flipDuration, 0.8)`.
nonisolated struct FlashCardConfiguration: Equatable {
    /// The card fills the space it gets, up to this height.
    var maxHeight: CGFloat = 416
    var flipDuration: TimeInterval = 0.45
    var cornerRadius: CGFloat = 32
    var padding: CGFloat = 24
    var spacing: CGFloat = 16
    var textFont: Font = .largeTitle.bold()
    var detailFont: Font = .body
    var transcriptionFont: Font = .title3
    /// How far long text may shrink to fit, as a fraction of `textFont`.
    var minimumTextScale: CGFloat = 0.5
    var imageMaxHeight: CGFloat = 176
    /// Symbol shown when the image fails to load.
    var imagePlaceholderFont: Font = .largeTitle
    var imageMinimumCornerRadius: CGFloat = 12
    /// Rate of the system voice that reads a word without recorded audio, from `AVSpeechUtteranceMinimumSpeechRate`
    /// to `AVSpeechUtteranceMaximumSpeechRate`.
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
}

extension EnvironmentValues {
    @Entry var flashCard = FlashCardConfiguration()
}
