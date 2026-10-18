import SwiftUI

struct PracticeView: View {
    @State private var isFlipped = false

    // Sample card for checking FlashCard on a device until decks can be imported.
    // Photo: "Admiral (Juli 2024)", Wikimedia Commons, CC0.
    var body: some View {
        FlashCard(
            front: CardSide(
                text: "der Schmetterling",
                transcription: "/deːɐ̯ ˈʃmɛtɐlɪŋ/",
                imageURL: Bundle.main.url(forResource: "schmetterling", withExtension: "jpg"),
                audioURLs: Bundle.main.url(forResource: "schmetterling", withExtension: "m4a").map { [$0] } ?? [],
                language: .init(identifier: "de")
            ),
            back: CardSide(text: "butterfly", detail: "Der Schmetterling sitzt auf der Blume."),
            isFlipped: $isFlipped
        )
        .padding()
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack {
        PracticeView()
    }
}
