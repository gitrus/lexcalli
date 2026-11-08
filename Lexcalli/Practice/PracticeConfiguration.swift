import SwiftUI

/// Look of the practice screen. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.practice.controlSpacing, 16)`.
nonisolated struct PracticeConfiguration: Equatable {
    var controlSpacing: CGFloat = 12
    var progressFont: Font = .subheadline
    var modeHintFont: Font = .footnote
    var failureFont: Font = .footnote
    var doneMinWidth: CGFloat = 160
    var promptFont: Font = .title2
    var answerFont: Font = .body
    var inputLabelFont: Font = .caption
    var inputPadding: CGFloat = 16
    var inputMinimumHeight: CGFloat = 44
    var inputCornerRadius: CGFloat = 16
    var inputBorderWidth: CGFloat = 1
    var infoButtonMinSize: CGFloat = 44
    var diffLabelFont: Font = .caption.weight(.semibold)
    var diffPadding: CGFloat = 12
    var comparisonBorderWidth: CGFloat = 2
    var comparisonMatchColor: Color = .green
    // Muted amber (#A87832), shared by the border and changed-text background.
    var comparisonDifferenceColor: Color = .init(red: 168 / 255, green: 120 / 255, blue: 50 / 255)
    var removedTextBackgroundOpacity: Double = 0.12
    var addedTextBackground: Color = .green.opacity(0.18)
    var feedbackLabelFont: Font = .headline
    var exerciseControlSize: ControlSize = .large
}

extension EnvironmentValues {
    @Entry var practice = PracticeConfiguration()
}
