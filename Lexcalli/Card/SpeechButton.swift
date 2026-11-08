import AVFoundation
import SwiftUI

/// Reads text aloud with the best system voice installed for its language. Cards use it for a word without recorded
/// audio.
struct SpeechButton: View {
    let text: String
    let language: Locale.Language

    @Environment(\.flashCard) private var configuration

    /// Shared, so starting one button stops another.
    private static let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        Button("Speak", systemImage: "speaker.wave.2.fill") {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = .best(for: language)
            utterance.rate = configuration.speechRate
            // While VoiceOver or Spoken Content runs, use the voice and rate the user chose there.
            utterance.prefersAssistiveTechnologySettings = true
            Self.synthesizer.stopSpeaking(at: .immediate)
            Self.synthesizer.speak(utterance)
        }
        .buttonStyle(AudioButtonStyle())
        .accessibilityHint("Uses a system voice")
        .onDisappear { Self.synthesizer.stopSpeaking(at: .immediate) }
    }
}

extension AVSpeechSynthesisVoice {
    /// The highest-quality installed voice for `language`, preferring its region, then the system's choice.
    /// Premium and enhanced voices count only once the user downloads them in Settings.
    static func best(for language: Locale.Language) -> AVSpeechSynthesisVoice? {
        let systemChoice = AVSpeechSynthesisVoice(language: language.minimalIdentifier)?.identifier
        func rank(_ voice: AVSpeechSynthesisVoice) -> (Int, Int, Int) {
            let voiceLanguage = Locale.Language(identifier: voice.language)
            return (
                voice.quality.rawValue,
                voiceLanguage.region != nil && voiceLanguage.region == language.region ? 1 : 0,
                voice.identifier == systemChoice ? 1 : 0
            )
        }
        return speechVoices()
            .filter {
                Locale.Language(identifier: $0.language).languageCode == language.languageCode
                    && !$0.voiceTraits.contains(.isNoveltyVoice)
                    && !$0.voiceTraits.contains(.isPersonalVoice)
            }
            .max { rank($0) < rank($1) }
    }
}

extension AVSpeechSynthesisVoiceQuality {
    /// The name Settings uses for this quality.
    var title: String {
        switch self {
        case .premium: String(localized: "Premium")
        case .enhanced: String(localized: "Enhanced")
        default: String(localized: "Default")
        }
    }
}

#Preview {
    SpeechButton(text: "γεια σου", language: .init(identifier: "el"))
}
