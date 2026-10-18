import Foundation
import LexcalliCore

extension Deck {
    /// Sample decks for checking the deck and card screens on a device until decks can be imported.
    static let samples: [Deck] = [
        Deck(
            name: "German Basics",
            termLanguage: .init(identifier: "de"),
            meaningLanguage: .init(identifier: "en"),
            notes: [
                // Photo: "Admiral (Juli 2024)", Wikimedia Commons, CC0.
                Note(
                    term: "der Schmetterling",
                    meaning: "butterfly",
                    transcription: "/deːɐ̯ ˈʃmɛtɐlɪŋ/",
                    example: "Der Schmetterling sitzt auf der Blume.",
                    imageURL: Bundle.main.url(forResource: "schmetterling", withExtension: "jpg"),
                    audioURLs: Bundle.main.url(forResource: "schmetterling", withExtension: "m4a").map { [$0] } ?? []
                ),
                Note(term: "die Blume", meaning: "flower", transcription: "/ˈbluːmə/"),
                Note(term: "der Baum", meaning: "tree", transcription: "/baʊ̯m/"),
                Note(term: "jemandem Bescheid sagen", meaning: "to let someone know"),
            ]
        ),
        Deck(
            name: "Japanese Nature",
            termLanguage: .init(identifier: "ja"),
            meaningLanguage: .init(identifier: "en"),
            notes: [
                Note(term: "蝶々", meaning: "butterfly", transcription: "ちょうちょう"),
                Note(term: "花", meaning: "flower", transcription: "はな"),
                Note(term: "木", meaning: "tree", transcription: "き"),
            ]
        ),
    ]
}
