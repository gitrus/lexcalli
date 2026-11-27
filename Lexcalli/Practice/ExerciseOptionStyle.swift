import SwiftUI

/// Options keep a quiet border unless selection or feedback supplies a color.
struct ExerciseOptionStyle: ButtonStyle {
    let borderColor: Color?
    @Environment(\.practice) private var appearance

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(appearance.inputPadding)
            .frame(minHeight: appearance.inputMinimumHeight)
            .background(.background, in: .rect(cornerRadius: appearance.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: appearance.inputCornerRadius)
                    .strokeBorder(
                        borderColor.map(AnyShapeStyle.init) ?? AnyShapeStyle(.quaternary),
                        lineWidth: borderColor == nil ? appearance.inputBorderWidth : appearance.comparisonBorderWidth)
            }
            .contentShape(.rect(cornerRadius: appearance.inputCornerRadius))
            .opacity(configuration.isPressed ? appearance.optionPressedOpacity : 1)
    }
}
