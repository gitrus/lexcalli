import LexcalliCore
import SwiftUI

/// A deck in a list: its name, then a line and a badge that depend on the screen.
struct DeckRow<Detail: View>: View {
    let deck: DeckSummary
    let badge: Text
    @ViewBuilder let detail: Detail

    @Environment(\.deckList) private var configuration

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(deck.name)
                    .font(configuration.rowTitleFont)
                detail
                    .font(configuration.rowSubtitleFont)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "rectangle.stack")
        }
        .labelStyle(.glassIcon)
        .badge(badge)
    }
}

extension DeckRow where Detail == LanguagePairText {
    /// The language pair and the number of words.
    init(languagesOf deck: DeckSummary) {
        self.init(deck: deck, badge: Text(deck.noteCount, format: .number)) {
            LanguagePairText(deck: deck)
        }
    }
}

extension DeckRow where Detail == Text {
    /// How many cards have been studied, and what share.
    init(progressOf deck: DeckSummary) {
        let share = deck.cardCount == 0 ? 0 : Double(deck.studiedCardCount) / Double(deck.cardCount)
        self.init(deck: deck, badge: Text(share, format: .percent.precision(.fractionLength(0)))) {
            Text("\(deck.studiedCardCount) of \(deck.cardCount) cards studied")
        }
    }
}

struct LanguagePairText: View {
    let deck: DeckSummary

    @Environment(\.locale) private var locale

    var body: some View {
        let languages = (locale.name(of: deck.termLanguage), locale.name(of: deck.meaningLanguage))
        Text("\(languages.0) → \(languages.1)")
            .accessibilityLabel("\(languages.0) to \(languages.1)")
    }
}
