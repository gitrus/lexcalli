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
    var feedbackLabelFont: Font = .headline
    var exerciseControlSize: ControlSize = .large
}

extension EnvironmentValues {
    @Entry var practice = PracticeConfiguration()
}
