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
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        // The glass style draws the icon in the primary color; keep it in the accent color.
        .foregroundStyle(.tint)
        .buttonBorderShape(.circle)
        .onDisappear { player?.stop() }
    }
}
