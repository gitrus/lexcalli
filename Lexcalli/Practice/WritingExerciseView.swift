import LexcalliCore
import SwiftUI

struct WritingExerciseView: View {
    let prompt: WritingPrompt
    let model: PracticeModel

    @Environment(\.practice) private var configuration
    @State private var response = ""
    @State private var isConfirming = false
    @State private var isFocused = false
    @State private var input = WritingInputControl()

    private var isLocked: Bool {
        isConfirming || model.hasPendingAnswer || model.feedback != nil || model.isSaving || model.failure != nil
            || model.phase != .studying
    }

    var body: some View {
        VStack(spacing: configuration.controlSpacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: configuration.controlSpacing) {
                    Text("Write down").font(configuration.progressFont).foregroundStyle(.secondary)
                    Text(prompt.question).font(configuration.promptFont)
                    WritingAnswerInput(
                        text: $response, isFocused: $isFocused, language: model.writingLanguage,
                        isEnabled: !isLocked, control: input, onSubmit: confirm
                    )
                    // No expected text, answer-side media or answer hints exist in the pre-save tree.
                    if case .writing(let parts) = model.feedback {
                        WritingComparisonView(parts: parts)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ExerciseControls(
                model: model, canConfirm: !isConfirming && WritingExercise().accepts(response), confirm: confirm)
        }
        .onChange(of: model.feedback) {
            if model.feedback != nil {
                AccessibilityNotification.Announcement("Answer saved. Comparison available.").post()
            }
        }
    }

    private func confirm() {
        guard !isLocked, WritingExercise().accepts(response) else { return }
        isConfirming = true
        let confirmedResponse = input.committedText() ?? response
        guard WritingExercise().accepts(confirmedResponse) else {
            isConfirming = false
            return
        }
        Task {
            await model.answerExercise(.writing(confirmedResponse))
            isConfirming = false
        }
    }
}
