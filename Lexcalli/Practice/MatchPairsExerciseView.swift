import LexcalliCore
import SwiftUI

struct MatchPairsExerciseView: View {
    let prompt: MatchPairsPrompt
    let model: PracticeModel

    @Environment(\.practice) private var configuration
    @Environment(\.feedbackPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var board = MatchPairsBoard()
    @State private var isConfirming = false
    @State private var scrollPosition = ScrollPosition(idType: String.self)

    private var isLocked: Bool {
        isConfirming || !model.acceptsAnswer
    }

    private var evaluation: MatchPairsEvaluation? {
        guard case .matchPairs(let evaluation) = model.feedback else { return nil }
        return evaluation
    }

    private var headings: (left: LocalizedStringKey, right: LocalizedStringKey) {
        prompt.cardID.direction == .forward ? ("Words", "Meanings") : ("Meanings", "Words")
    }

    var body: some View {
        VStack(spacing: configuration.controlSpacing) {
            ScrollView {
                VStack(alignment: .leading, spacing: configuration.controlSpacing) {
                    if let evaluation {
                        MatchPairsResult(prompt: prompt, evaluation: evaluation, card: model.current)
                    } else {
                        Text("Match \(prompt.left.count) pairs").font(configuration.progressFont)
                            .foregroundStyle(.secondary)
                        columns
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .scrollPosition($scrollPosition)
            ExerciseControls(model: model, canConfirm: board.isComplete(for: prompt) && !isConfirming) {
                guard !isLocked, board.isComplete(for: prompt) else { return }
                isConfirming = true
                Task {
                    await model.answerExercise(.matchPairs(board.pairing))
                    isConfirming = false
                }
            }
        }
        .onChange(of: model.feedback) {
            guard let evaluation else { return }
            if dynamicTypeSize.isAccessibilitySize {
                let wrong = prompt.left.first { !evaluation.correct.contains($0.noteID) }
                scrollPosition.scrollTo(
                    id: wrong.map { MatchPairsResult.rowID($0.noteID) } ?? MatchPairsResult.headingID)
            }
            let correct = evaluation.correct.count
            AccessibilityNotification.Announcement(
                "Answer saved. \(correct) of \(prompt.left.count) pairs correct."
            ).post()
        }
    }

    /// Side by side, or stacked with headings once two columns no longer fit long text.
    @ViewBuilder
    private var columns: some View {
        if dynamicTypeSize.isAccessibilitySize {
            column(.left, heading: headings.left)
            column(.right, heading: headings.right)
        } else {
            HStack(alignment: .top, spacing: configuration.controlSpacing) {
                column(.left, heading: nil)
                column(.right, heading: nil)
            }
        }
    }

    private func column(_ side: MatchPairsBoard.Side, heading: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: configuration.controlSpacing) {
            if let heading {
                Text(heading).font(configuration.feedbackLabelFont).accessibilityAddTraits(.isHeader)
            }
            ForEach(side == .left ? prompt.left : prompt.right, id: \.noteID) { item in
                itemButton(MatchPairsBoard.Item(side: side, noteID: item.noteID), text: item.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemButton(_ item: MatchPairsBoard.Item, text: String) -> some View {
        let number = board.pairNumber(of: item)
        let isSelected = board.selection == item
        let tint: Color? =
            number.map { configuration.matchPairTints[($0 - 1) % configuration.matchPairTints.count] }
            ?? (isSelected ? palette.selection : nil)
        let symbol = number.map { "\($0).circle.fill" } ?? (isSelected ? "largecircle.fill.circle" : "circle")
        return Button {
            guard !isLocked else { return }
            board.tap(item)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: configuration.controlSpacing) {
                Image(systemName: symbol)
                    .foregroundStyle(tint ?? .secondary)
                    .accessibilityHidden(true)
                Text(text)
                    .font(configuration.answerFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(ExerciseOptionStyle(borderColor: tint))
        .disabled(isLocked)
        .accessibilityLabel(text)
        .accessibilityValue(status(of: item, number: number))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("match.\(item.side == .left ? "left" : "right").\(item.noteID.uuidString)")
    }

    private func status(of item: MatchPairsBoard.Item, number: Int?) -> String {
        if board.selection == item { return String(localized: "Selected") }
        guard let number, let partner = board.partner(of: item) else { return String(localized: "Not paired") }
        let partnerText = (item.side == .left ? prompt.right : prompt.left).first { $0.noteID == partner }?.text ?? ""
        return String(localized: "Pair \(number), with \(partnerText)")
    }
}

/// The learner's pairing before confirmation. Screen state only; nothing here knows which pairs are right.
struct MatchPairsBoard: Equatable {
    enum Side: Hashable { case left, right }

    struct Item: Hashable {
        let side: Side
        let noteID: Note.ID
    }

    private struct Pair: Hashable {
        let left: Note.ID
        let right: Note.ID
    }

    private(set) var selection: Item?
    /// In the order the learner made them, which numbers the badges.
    private var pairs: [Pair] = []

    var pairing: [Note.ID: Note.ID] { Dictionary(uniqueKeysWithValues: pairs.map { ($0.left, $0.right) }) }

    func isComplete(for prompt: MatchPairsPrompt) -> Bool { prompt.accepts(pairing) }

    func pairNumber(of item: Item) -> Int? {
        pairs.firstIndex { Self.contains($0, item) }.map { $0 + 1 }
    }

    func partner(of item: Item) -> Note.ID? {
        pairs.first { Self.contains($0, item) }.map { item.side == .left ? $0.right : $0.left }
    }

    /// A selection on the other side pairs with the tapped item, replacing its old pair; otherwise tapping a paired
    /// item breaks its pair and selects it, and tapping an unpaired one toggles or moves the selection.
    mutating func tap(_ item: Item) {
        if let selected = selection, selected.side != item.side {
            pairs.removeAll { Self.contains($0, item) || Self.contains($0, selected) }
            pairs.append(
                item.side == .left
                    ? Pair(left: item.noteID, right: selected.noteID) : Pair(left: selected.noteID, right: item.noteID))
            selection = nil
        } else if pairNumber(of: item) != nil {
            pairs.removeAll { Self.contains($0, item) }
            selection = item
        } else {
            selection = selection == item ? nil : item
        }
    }

    private static func contains(_ pair: Pair, _ item: Item) -> Bool {
        item.side == .left ? pair.left == item.noteID : pair.right == item.noteID
    }
}

/// Saved feedback, one row per left item in left-column order.
private struct MatchPairsResult: View {
    static let headingID = "match.result.heading"
    static func rowID(_ noteID: Note.ID) -> String { "match.result.\(noteID.uuidString)" }

    let prompt: MatchPairsPrompt
    let evaluation: MatchPairsEvaluation
    let card: PracticeModel.CurrentCard?

    @Environment(\.practice) private var configuration
    @Environment(\.feedbackPalette) private var palette

    var body: some View {
        Text("\(evaluation.correct.count) of \(prompt.left.count) pairs correct")
            .font(configuration.feedbackLabelFont)
            .accessibilityAddTraits(.isHeader)
            .id(Self.headingID)
        ForEach(prompt.left, id: \.noteID) { item in
            row(item)
        }
    }

    private func text(onRight noteID: Note.ID?) -> String {
        prompt.right.first { $0.noteID == noteID }?.text ?? ""
    }

    private func row(_ item: MatchPairsItem) -> some View {
        let chosen = text(onRight: evaluation.pairing[item.noteID])
        let expected = text(onRight: item.noteID)
        let isCorrect = evaluation.correct.contains(item.noteID)
        // Terms are on the left for a forward card, on the right for a reverse one.
        let term = prompt.cardID.direction == .forward ? item.text : expected
        return HStack(spacing: configuration.controlSpacing) {
            Image(systemName: isCorrect ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(isCorrect ? palette.correction : palette.mistake)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: configuration.matchResultLineSpacing) {
                Text(item.text).font(configuration.answerFont.weight(.semibold))
                highlighted(chosen, color: isCorrect ? nil : palette.mistakeHighlight)
                if !isCorrect {
                    highlighted(expected, color: palette.correctionHighlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.text), \(chosen)")
            .accessibilityValue(
                isCorrect
                    ? String(localized: "Correct pair")
                    : String(localized: "Not a pair. Correct: \(expected)"))
            if let card {
                SpeechButton(text: term, language: card.termLanguage, size: .compact)
                    .accessibilityLabel("Listen to \(term)")
            }
        }
        .padding(configuration.inputPadding)
        .background(.background, in: .rect(cornerRadius: configuration.inputCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: configuration.inputCornerRadius)
                .strokeBorder(
                    isCorrect ? palette.correction : palette.mistake, lineWidth: configuration.comparisonBorderWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.rowID(item.noteID))
        .id(Self.rowID(item.noteID))
    }

    private func highlighted(_ text: String, color: Color?) -> some View {
        Text(text)
            .font(configuration.answerFont)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, color == nil ? 0 : configuration.matchHighlightPadding)
            .background(color ?? .clear, in: .rect(cornerRadius: configuration.matchHighlightPadding))
    }
}
