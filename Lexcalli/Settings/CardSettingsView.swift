import SwiftUI

/// How flashcards show a word.
struct CardSettingsView: View {
    @AppStorage(PreferenceKey.cardSerifText) private var serifText = false
    @AppStorage(PreferenceKey.cardShowsTranscription) private var showsTranscription = true

    var body: some View {
        Form {
            Section {
                Toggle("Serif Text", isOn: $serifText)
                Toggle("Show Transcription", isOn: $showsTranscription)
            } footer: {
                Text("Audio stays available on the card when the transcription is hidden.")
            }
        }
        .navigationTitle("Cards")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CardSettingsView()
    }
}
