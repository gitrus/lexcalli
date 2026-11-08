import AVFoundation
import SwiftUI

/// Plays one audio file, such as a word's pronunciation or an example sentence.
struct AudioButton: View {
    let url: URL

    @State private var player: AVAudioPlayer?

    var body: some View {
        Button("Play Audio", systemImage: "speaker.wave.2.fill") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
        .buttonStyle(AudioButtonStyle())
        .onDisappear { player?.stop() }
    }
}
