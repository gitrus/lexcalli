import SwiftUI

/// A two-sided card that flips when tapped. The parent owns `isFlipped`, so its own controls can flip the card too.
///
/// Timing, sizes, and fonts come from `FlashCardConfiguration` in the environment. Font modifiers such as
/// `.fontDesign(.serif)` or `.dynamicTypeSize(_:)` on the card restyle both sides too.
struct FlashCard: View {
    let front: CardSide
    let back: CardSide
    @Binding var isFlipped: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flashCard) private var configuration

    var body: some View {
        ZStack {
            face(front, angle: isFlipped ? 180 : 0)
            face(back, angle: isFlipped ? 0 : -180)
        }
        .frame(maxHeight: configuration.maxHeight)
        .animation(.smooth(duration: configuration.flipDuration), value: isFlipped)
    }

    private func face(_ side: CardSide, angle: Double) -> some View {
        let isShown = angle == 0
        return CardFace(side: side, configuration: configuration)
            .modifier(FlipEffect(angle: angle, reduceMotion: reduceMotion))
            // A tap gesture rather than a Button, because a face contains its own audio buttons.
            .onTapGesture { isFlipped.toggle() }
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Flips the card")
            .accessibilityAction { isFlipped.toggle() }
    }
}

/// Turns a face around the vertical axis and hides it while it faces away. With Reduce Motion, crossfades instead.
///
/// The turn is a horizontal squeeze rather than `rotation3DEffect`: Liquid Glass does not follow 3D transforms
/// and stretches far outside the card mid-flip.
@Animatable
private struct FlipEffect: ViewModifier {
    /// 0 faces the viewer; ±180 faces away.
    var angle: Double
    @AnimatableIgnored var reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 - abs(angle) / 180 : abs(angle) < 90 ? 1 : 0)
            .scaleEffect(x: reduceMotion ? 1 : abs(cos(angle * .pi / 180)), y: 1)
    }
}

private struct CardFace: View {
    let side: CardSide
    let configuration: FlashCardConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing) {
            if let imageURL = side.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                            .clipShape(
                                ConcentricRectangle(
                                    corners: .concentric(minimum: .fixed(configuration.imageMinimumCornerRadius)),
                                    isUniform: true
                                )
                            )
                    case .failure:
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxHeight: configuration.imageMaxHeight)
            }

            Text(side.text)
                .font(configuration.textFont)
                .minimumScaleFactor(configuration.minimumTextScale)

            if let detail = side.detail {
                Text(detail)
                    .font(configuration.detailFont)
                    .foregroundStyle(.secondary)
            }

            if !side.audioURLs.isEmpty || side.transcription != nil {
                HStack {
                    ForEach(side.audioURLs, id: \.self) { AudioButton(url: $0) }
                    if let transcription = side.transcription {
                        Text(transcription)
                            .font(configuration.transcriptionFont)
                    }
                }
            }
        }
        .multilineTextAlignment(.center)
        .typesettingLanguage(side.language ?? .init(identifier: ""), isEnabled: side.language != nil)
        .padding(configuration.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerShape(.rect(cornerRadius: configuration.cornerRadius))
        .glassEffect(.regular, in: .rect(cornerRadius: configuration.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var isFlipped = false

    FlashCard(
        front: CardSide(text: "der Schmetterling", language: .init(identifier: "de")),
        back: CardSide(text: "butterfly", detail: "Der Schmetterling sitzt auf der Blume."),
        isFlipped: $isFlipped
    )
    .frame(height: 420)
    .padding()
}

#Preview("Serif, Japanese, slow flip") {
    @Previewable @State var isFlipped = false

    FlashCard(
        front: CardSide(text: "蝶々", language: .init(identifier: "ja")),
        back: CardSide(text: "butterfly", detail: "ちょうちょう"),
        isFlipped: $isFlipped
    )
    .fontDesign(.serif)
    .environment(\.flashCard.flipDuration, 1.2)
    .frame(height: 420)
    .padding()
}
