import LexcalliCore
import SwiftUI

struct PickOneExerciseView: View {
    let prompt: PickOnePrompt
    let model: PracticeModel

    @Environment(\.practice) private var configuration
    @State private var selection: UUID?
    @State private var isConfirming = false

    private var isLocked: Bool {
        isConfirming || model.hasPendingAnswer || model.feedback != nil || model.isSaving || model.failure != nil
            || model.phase != .studying
    }

    private var confirmed: (selected: UUID, correct: UUID)? {
        guard case .pickOne(let selected, let correct) = model.feedback else { return nil }
        return (selected, correct)
    }

    var body: some View {
        VStack(spacing: configuration.controlSpacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: configuration.controlSpacing) {
                    Text("Pick from \(prompt.options.count)").font(configuration.progressFont).foregroundStyle(
                        .secondary)
                    Text(prompt.question).font(configuration.promptFont)
                    ForEach(prompt.options, id: \.noteID) { option in
                        optionButton(option)
                    }
                }
            }
            ExerciseControls(model: model, canConfirm: selection != nil && !isConfirming) {
                guard !isLocked, let selection else { return }
                isConfirming = true
                Task {
                    await model.answerExercise(.pickOne(selection))
                    isConfirming = false
                }
            }
        }
        .onChange(of: model.feedback) {
            if model.feedback != nil {
                AccessibilityNotification.Announcement("Answer saved. Correct answer: \(prompt.expectedAnswer)").post()
            }
        }
    }

    private func optionButton(_ option: PickOneOption) -> some View {
        let selected = (confirmed?.selected ?? selection) == option.noteID
        return Button {
            guard !isLocked else { return }
            selection = option.noteID
        } label: {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(option.answer).font(configuration.answerFont)
                    if let confirmed {
                        if confirmed.selected == option.noteID {
                            Text("Your selection").font(configuration.failureFont)
                        }
                        if confirmed.correct == option.noteID {
                            Label("Correct answer", systemImage: "checkmark.circle").font(configuration.failureFont)
                        } else if confirmed.selected == option.noteID {
                            Label("Not the expected answer", systemImage: "xmark.circle").font(
                                configuration.failureFont)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(configuration.exerciseControlSize)
        .disabled(isLocked)
        .accessibilityLabel(option.answer)
        .accessibilityValue(status(for: option.noteID))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("pick.option.\(option.noteID.uuidString)")
    }

    private func status(for id: UUID) -> String {
        guard let confirmed else { return selection == id ? String(localized: "Selected") : "" }
        var labels: [String] = []
        if confirmed.selected == id { labels.append(String(localized: "Your selection")) }
        if confirmed.correct == id {
            labels.append(String(localized: "Correct answer"))
        } else if confirmed.selected == id {
            labels.append(String(localized: "Not the expected answer"))
        }
        return labels.joined(separator: ". ")
    }
}
