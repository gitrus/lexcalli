import AVFoundation
import SwiftUI

@main
struct LexcalliApp: App {
    init() {
        // Pronunciation is learning content: play it with the silent switch on, mixed over the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
    }

    @State private var library = LibraryPhase.opening

    var body: some Scene {
        WindowGroup {
            Group {
                switch library {
                case .opening:
                    ProgressView()
                case .ready(let library):
                    RootView()
                        .environment(\.library, library)
                case .failed(let message):
                    // Never an empty library: the data is kept and the reason shown.
                    LoadFailureView(title: "Your Decks Couldn't Be Opened", message: message)
                }
            }
            .task { library = await LibraryPhase.open() }
        }
    }
}
