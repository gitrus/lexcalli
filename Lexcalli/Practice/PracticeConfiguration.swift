import SwiftUI

/// Look of the practice screen. Change a default here, or override it for a subtree through the environment,
/// for example `.environment(\.practice.controlSpacing, 16)`.
nonisolated struct PracticeConfiguration: Equatable {
    var controlSpacing: CGFloat = 12
    var compactDeckSectionSpacing: CGFloat = 12
    var denseDeckSectionSpacing: CGFloat = 8
    var progressFont: Font = .subheadline
    var modeHintFont: Font = .footnote
    var failureFont: Font = .footnote
    var doneMinWidth: CGFloat = 160
    var promptFont: Font = .title2
    var answerFont: Font = .body
    var optionPressedOpacity: Double = 0.75
    var inputLabelFont: Font = .caption
    var inputPadding: CGFloat = 16
    var inputMinimumHeight: CGFloat = 44
    var inputCornerRadius: CGFloat = 16
    var inputBorderWidth: CGFloat = 1
    var infoButtonMinSize: CGFloat = 44
    var diffLabelFont: Font = .caption.weight(.semibold)
    var diffPadding: CGFloat = 12
    var comparisonBorderWidth: CGFloat = 2
    var feedbackLabelFont: Font = .headline
    var exerciseControlSize: ControlSize = .large
    /// Taps played `answerHapticSpacing` apart when exercise feedback appears. Single taps of different strength felt
    /// alike on a device, so right and wrong differ in rhythm, like the system success and error haptics but lighter.
    var correctAnswerHaptic: [SensoryFeedback] = [
        .impact(flexibility: .rigid, intensity: 0.5), .impact(flexibility: .rigid, intensity: 0.7),
    ]
    var wrongAnswerHaptic: [SensoryFeedback] = Array(repeating: .impact(weight: .medium, intensity: 1), count: 3)
    var answerHapticSpacing: Duration = .milliseconds(100)
    /// Match pairs badges cycle through these. Feedback's green and orange are left out, and red-looking pink comes
    /// late, so a pair never looks like a mistake before checking.
    var matchPairTints: [Color] = [.blue, .purple, .teal, .indigo, .brown, .pink]
    var matchResultLineSpacing: CGFloat = 6
    var matchHighlightPadding: CGFloat = 4
}

extension EnvironmentValues {
    @Entry var practice = PracticeConfiguration()
}
