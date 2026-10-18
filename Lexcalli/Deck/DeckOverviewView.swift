import LexcalliCore
import SwiftUI

/// A deck's languages and what its words include. Presented as a sheet, so it owns its close button.
struct DeckOverviewView: View {
    let deck: Deck

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Languages") {
                    LabeledContent("Words", value: locale.name(of: deck.termLanguage))
                    LabeledContent("Meanings", value: locale.name(of: deck.meaningLanguage))
                }

                // Same symbols as the word rows in the deck.
                Section("Words") {
                    row("Total", systemImage: "text.book.closed", count: deck.notes.count)
                    row("With Audio", systemImage: "speaker.wave.2", count: deck.notes.count { !$0.audioURLs.isEmpty })
                    row(
                        "With Transcription", systemImage: "character.phonetic",
                        count: deck.notes.count { $0.transcription != nil })
                    row("With Image", systemImage: "photo", count: deck.notes.count { $0.imageURL != nil })
                }
            }
            .navigationTitle(deck.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, count: Int) -> some View {
        LabeledContent {
            Text(count, format: .number)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

#Preview {
    DeckOverviewView(deck: Deck.samples[0])
}
