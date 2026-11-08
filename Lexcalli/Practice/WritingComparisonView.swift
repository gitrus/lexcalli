import LexcalliCore
import SwiftUI

struct WritingComparisonView: View {
    let parts: [WritingComparison.Part]
    @Environment(\.practice) private var configuration

    var body: some View {
        VStack(alignment: .trailing, spacing: configuration.controlSpacing) {
            VStack(spacing: configuration.controlSpacing) {
                ComparisonRow(side: .actual, parts: parts)
                ComparisonRow(side: .expected, parts: parts)
            }
            .padding(configuration.diffPadding)
            .background(.background, in: .rect(cornerRadius: configuration.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: configuration.inputCornerRadius)
                    .strokeBorder(
                        answersMatch ? configuration.comparisonMatchColor : configuration.comparisonDifferenceColor,
                        lineWidth: configuration.comparisonBorderWidth
                    )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Answer comparison")
            .accessibilityValue(Text(verbatim: spokenDifferences))
            ComparisonInfo(spokenDifferences: spokenDifferences)
        }
    }

    private var answersMatch: Bool {
        parts.allSatisfy { $0.kind == .match }
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
}

private nonisolated enum Side {
    case actual
    case expected

    var title: LocalizedStringKey {
        switch self {
        case .actual: "Actual"
        case .expected: "Expected"
        }
    }
}

private struct ComparisonRow: View {
    let side: Side
    let parts: [WritingComparison.Part]
    @Environment(\.practice) private var configuration

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: configuration.controlSpacing) {
            styledText
                .font(configuration.answerFont.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textRenderer(
                    ComparisonHighlightRenderer(
                        removed: configuration.comparisonDifferenceColor
                            .opacity(configuration.removedTextBackgroundOpacity),
                        added: configuration.addedTextBackground
                    )
                )
                // Native selectable-text rendering bypasses the custom highlight renderer on iOS.
                .accessibilityIdentifier(side == .expected ? "writing.expected" : "writing.actual")
            Text(side.title)
                .font(configuration.diffLabelFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var styledText: Text {
        parts.reduce(Text("")) { result, part in
            var text = Text(verbatim: side == .expected ? part.expected : part.response)
            switch part.kind {
            case .match: break
            case .softDifference: text = text.italic()
            case .difference: text = text.bold()
            }
            if part.kind != .match { text = text.customAttribute(ComparisonChange(side: side)) }
            return Text("\(result)\(text)")
        }
    }
}

private nonisolated struct ComparisonChange: TextAttribute {
    let side: Side
}

/// Paints only changed runs, including spaces, while leaving native text layout and wrapping intact.
private nonisolated struct ComparisonHighlightRenderer: TextRenderer {
    let removed: Color
    let added: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if let change = run[ComparisonChange.self] {
                    context.fill(
                        Path(run.typographicBounds.rect),
                        with: .color(change.side == .expected ? added : removed)
                    )
                }
                context.draw(run)
            }
        }
    }
}

private struct ComparisonInfo: View {
    let spokenDifferences: String
    @Environment(\.practice) private var configuration
    @State private var isPresented = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button("About this comparison", systemImage: "info.circle") { isPresented = true }
            .labelStyle(.iconOnly)
            .font(configuration.progressFont)
            .frame(minWidth: configuration.infoButtonMinSize, minHeight: configuration.infoButtonMinSize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .accessibilityIdentifier("writing.comparisonInfo")
            .popover(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: configuration.controlSpacing) {
                    HStack {
                        Text("Comparison")
                            .font(configuration.feedbackLabelFont)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Close", systemImage: "xmark") { isPresented = false }
                            .labelStyle(.iconOnly)
                            .frame(
                                minWidth: configuration.infoButtonMinSize,
                                minHeight: configuration.infoButtonMinSize
                            )
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("writing.comparisonInfo.close")
                    }
                    ViewThatFits(in: .vertical) {
                        details
                        ScrollView { details }
                    }
                }
                .padding(configuration.inputPadding)
                .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .top)
                .presentationCompactAdaptation(dynamicTypeSize.isAccessibilitySize ? .sheet : .popover)
                .presentationDetents([.large])
            }
    }

    private var details: some View {
        Text(
            "Red marks Actual changes; green marks Expected changes. Case or accent changes are italic; other changes are bold. Edge whitespace is ignored. No grade is assigned."
        )
        .font(configuration.failureFont)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(spokenDifferences)
        .accessibilityHint("Leading and trailing whitespace is ignored.")
        .accessibilityIdentifier("writing.differences")
        .speechAlwaysIncludesPunctuation()
    }
}
