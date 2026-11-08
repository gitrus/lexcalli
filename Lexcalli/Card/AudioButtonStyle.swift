import SwiftUI

/// A fixed circular platter with our own press feedback. The system glass button style can morph
/// its pressed platter into a rounded rectangle, even with a circular button border.
struct AudioButtonStyle: ButtonStyle {
    @Environment(\.flashCard) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(card.audioButtonFont)
            .foregroundStyle(.tint)
            .frame(width: card.audioButtonDiameter * scale, height: card.audioButtonDiameter * scale)
            // Deliberately not interactive: press feedback below never changes the circle's shape.
            .glassEffect(.regular.interactive(false), in: .circle)
            .contentShape(.circle)
            .opacity(configuration.isPressed ? card.audioButtonPressedOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? card.audioButtonPressedScale : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: card.audioButtonPressDuration),
                value: configuration.isPressed
            )
    }
}
