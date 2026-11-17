import LexcalliCore
import SwiftUI

struct PickOneExerciseView: View {
    let prompt: PickOnePrompt
    let model: PracticeModel

    @Environment(\.practice) private var configuration
    @Environment(\.flashCard) private var cardConfiguration
    @ScaledMetric(relativeTo: .body) private var audioScale: CGFloat = 1
    @Environment(\.feedbackPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    @State private var selection: UUID?
    @State private var isConfirming = false

    private var isLocked: Bool {
        isConfirming || !model.acceptsAnswer
    }

    private var confirmed: (selected: UUID, correct: UUID)? {
        guard case .pickOne(let selected, let correct) = model.feedback else { return nil }
        return (selected, correct)
    }

    private var optionColors: [UUID: Color] {
        var colors: [UUID: Color] = [:]
        if let selection { colors[selection] = palette.selection }
        if let confirmed {
            colors[confirmed.selected] = palette.mistake
            colors[confirmed.correct] = palette.correction
        }
        return colors
    }

    var body: some View {
        VStack(spacing: configuration.controlSpacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: configuration.controlSpacing) {
                    Text("Pick from \(prompt.options.count)").font(configuration.progressFont).foregroundStyle(
                        .secondary)
                    question
                    ForEach(prompt.options, id: \.noteID) { option in
                        optionButton(option).id(option.noteID.uuidString)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition($scrollPosition)
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
            guard let confirmed else { return }
            if dynamicTypeSize.isAccessibilitySize {
                scrollPosition.scrollTo(
                    id: prompt.cardID.direction == .forward ? "pick.question" : confirmed.correct.uuidString,
                    anchor: .bottom)
            }
            AccessibilityNotification.Announcement("Answer saved. Correct answer: \(prompt.expectedAnswer)").post()
        }
    }

    private var question: some View {
        HStack(spacing: configuration.controlSpacing) {
            Text(prompt.question)
                .font(configuration.promptFont)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if confirmed != nil, prompt.cardID.direction == .forward, let card = model.current {
                SpeechButton(text: prompt.question, language: card.termLanguage, size: .compact)
                    .accessibilityLabel("Listen to question: \(prompt.question)")
                    .accessibilityIdentifier("pick.questionAudio")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pick.question")
        .id("pick.question")
    }

    private func optionButton(_ option: PickOneOption) -> some View {
        let selected = (confirmed?.selected ?? selection) == option.noteID
        let correct = confirmed?.correct == option.noteID
        let hasAudio = correct && prompt.cardID.direction == .reverse
        let color = optionColors[option.noteID] ?? .secondary
        let selectionSymbol = selected ? "largecircle.fill.circle" : "circle"
        let feedbackSymbol = correct ? "checkmark.circle" : "xmark.circle"
        let audioHitSize = max(
            cardConfiguration.compactAudioButtonDiameter * audioScale, cardConfiguration.audioButtonMinimumHitSize)
        return Button {
            guard !isLocked else { return }
            selection = option.noteID
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: configuration.controlSpacing) {
                Image(systemName: confirmed != nil && (selected || correct) ? feedbackSymbol : selectionSymbol)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(option.answer)
                    .font(configuration.answerFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, hasAudio ? audioHitSize + configuration.controlSpacing : 0)
            }
            .frame(minHeight: hasAudio ? max(0, audioHitSize - 2 * configuration.inputPadding) : nil)
        }
        .buttonStyle(ExerciseOptionStyle(borderColor: selected || correct ? color : nil))
        .disabled(isLocked)
        .accessibilityLabel(option.answer)
        .accessibilityValue(status(for: option.noteID))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("pick.option.\(option.noteID.uuidString)")
        .overlay(alignment: .trailing) {
            if hasAudio, let card = model.current {
                SpeechButton(text: option.answer, language: card.termLanguage, size: .compact)
                    .accessibilityLabel("Listen to correct answer: \(option.answer)")
                    .accessibilityIdentifier("pick.correctAudio")
                    .padding(.trailing, configuration.inputPadding)
            }
        }
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
