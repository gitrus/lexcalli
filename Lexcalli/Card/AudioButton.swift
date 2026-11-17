import AVFoundation
import SwiftUI

/// Plays one audio file, such as a word's pronunciation or an example sentence.
struct AudioButton: View {
    let url: URL
    var size: AudioButtonStyle.Size = .regular

    @State private var player: AVAudioPlayer?

    var body: some View {
        Button("Play Audio", systemImage: "speaker.wave.2.fill") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
        .buttonStyle(AudioButtonStyle(size: size))
        .onDisappear { player?.stop() }
    }
}
