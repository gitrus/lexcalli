import AVFoundation
import LexcalliCore
import SwiftUI

/// How flashcards show a word.
struct CardSettingsView: View {
    @AppStorage(PreferenceKey.cardSerifText) private var serifText = false
    @AppStorage(PreferenceKey.cardShowsTranscription) private var showsTranscription = true
    @AppStorage(PreferenceKey.cardSpeaksMissingAudio) private var speaksMissingAudio = true

    @Environment(\.library) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var decks: Observed<[DeckSummary]> = .loading
    /// Changes when installed voices may have changed, such as after a download in Settings, to look them up again.
    @State private var voicesRevision = 0

    var body: some View {
        Form {
            Section {
                Toggle("Serif Text", isOn: $serifText)
                Toggle("Show Transcription", isOn: $showsTranscription)
            } footer: {
                Text("Audio stays available on the card when the transcription is hidden.")
            }
            Section {
                Toggle("Speak Words Without Audio", isOn: $speaksMissingAudio)
            } footer: {
                Text("Uses the best voice installed for the deck’s language.")
            }
            if speaksMissingAudio, !termLanguages.isEmpty {
                Section {
                    ForEach(termLanguages, id: \.self) { language in
                        VoiceRow(language: language, revision: voicesRevision)
                    }
                } header: {
                    Text("Voices")
                } footer: {
                    Text(
                        "Download Enhanced or Premium voices in Settings › Accessibility › Spoken Content › Voices for more natural speech."
                    )
                }
            }
        }
        .navigationTitle("Cards")
        .navigationBarTitleDisplayMode(.inline)
        .observe({ [decks = library.decks] in decks.deckSummaries() }, id: 0, into: $decks)
        .task {
            for await _ in NotificationCenter.default.notifications(
                named: AVSpeechSynthesizer.availableVoicesDidChangeNotification)
            {
                voicesRevision += 1
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { voicesRevision += 1 }
        }
    }

    /// The languages cards speak: each deck's term language, once.
    private var termLanguages: [Locale.Language] {
        let languages = Set((decks.value ?? []).map(\.termLanguage))
        return languages.sorted { Locale.current.name(of: $0) < Locale.current.name(of: $1) }
    }
}

/// The voice that reads a language's words, and its quality.
private struct VoiceRow: View {
    let language: Locale.Language
    /// Not shown; a new value makes the row look up the voice again.
    let revision: Int

    var body: some View {
        let voice = AVSpeechSynthesisVoice.best(for: language)
        LabeledContent(Locale.current.name(of: language)) {
            if let voice {
                Text("\(voice.name), \(voice.quality.title)")
            } else {
                Text("No Voice Installed")
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardSettingsView()
    }
    .environment(\.library, SampleLibrary.preview)
}
