import AVFoundation
import SwiftUI

@main
struct LexcalliApp: App {
    init() {
        // Pronunciation is learning content: play it with the silent switch on, mixed over the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
