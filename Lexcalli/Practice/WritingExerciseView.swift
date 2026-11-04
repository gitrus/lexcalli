import LexcalliCore
import SwiftUI

struct WritingExerciseView: View {
    let prompt: WritingPrompt
    let model: PracticeModel

    @Environment(\.practice) private var configuration
    @State private var response = ""
    @State private var isConfirming = false
    @FocusState private var isFocused: Bool

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
                    TextField("Type the term or phrase", text: $response)
                        .font(configuration.answerFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($isFocused)
                        .onSubmit(confirm)
                        .disabled(isLocked)
                        .accessibilityIdentifier("writing.response")
                    // No expected text, answer-side media or answer hints exist in the pre-save tree.
                    if case .writing(let parts) = model.feedback {
                        WritingFeedbackView(parts: parts)
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
        let confirmedResponse = response
        isConfirming = true
        isFocused = false
        Task {
            await model.answerExercise(.writing(confirmedResponse))
            isConfirming = false
        }
    }
}

private struct WritingFeedbackView: View {
    let parts: [WritingComparison.Part]
    @Environment(\.practice) private var configuration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.controlSpacing) {
            Text("Your answer").font(configuration.feedbackLabelFont).accessibilityAddTraits(.isHeader)
            Text(styled(expected: false)).font(configuration.answerFont)
            Text("Expected answer").font(configuration.feedbackLabelFont).accessibilityAddTraits(.isHeader)
            Text(styled(expected: true)).font(configuration.answerFont)
            Text(
                "Case or accent differences are italic. Other differences are bold. This is a comparison, not a grade."
            )
            .font(configuration.failureFont)
            .foregroundStyle(.secondary)
            .accessibilityLabel(spokenDifferences)
            .accessibilityIdentifier("writing.differences")
            .speechAlwaysIncludesPunctuation()
        }
    }

    /// Style alone is inaudible. Describe each changed span and name otherwise silent whitespace.
    private var spokenDifferences: String {
        let differences = parts.filter { $0.kind != .match }.map { part in
            let entered = part.kind == .softDifference ? characterNames(part.response) : spokenText(part.response)
            let expected = part.kind == .softDifference ? characterNames(part.expected) : spokenText(part.expected)
            if part.kind == .softDifference {
                return String(localized: "Case or accent difference. Entered: \(entered). Expected: \(expected).")
            }
            return String(localized: "Different text. Entered: \(entered). Expected: \(expected).")
        }
        return differences.isEmpty
            ? String(localized: "The answers match canonically. No grade is assigned.")
            : differences.joined(separator: " ") + " " + String(localized: "No grade is assigned.")
    }

    /// Letter names distinguish H/h and accented letters even when the voice pronounces them alike.
    private func characterNames(_ text: String) -> String {
        text.unicodeScalars.map { $0.properties.name ?? "U+" + String($0.value, radix: 16) }
            .joined(separator: ", ")
    }

    private func spokenText(_ text: String) -> String {
        guard !text.isEmpty else { return String(localized: "nothing") }
        return text.map { character in
            switch character {
            case " ": return " " + String(localized: "space") + " "
            case "\n": return " " + String(localized: "new line") + " "
            case "\t": return " " + String(localized: "tab") + " "
            default: return String(character)
            }
        }.joined()
    }

    private func styled(expected: Bool) -> AttributedString {
        parts.reduce(into: AttributedString()) { result, part in
            var text = AttributedString(expected ? part.expected : part.response)
            switch part.kind {
            case .match: break
            case .softDifference: text.inlinePresentationIntent = .emphasized
            case .difference: text.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(text)
        }
    }
}
