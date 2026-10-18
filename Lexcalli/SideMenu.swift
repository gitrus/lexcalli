import SwiftUI

/// Leading-edge navigation panel shown over the main screen.
struct SideMenu: View {
    @Binding var selection: AppSection
    @Binding var isOpen: Bool

    @Environment(\.sideMenu) private var configuration
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// "Lex" regular, "call" bold, "i" in the system serif. A brand name, so it is not localized.
    private var wordmark: AttributedString {
        var call = AttributedString("call")
        call.inlinePresentationIntent = .stronglyEmphasized
        var i = AttributedString("i")
        i.font = .system(configuration.wordmarkStyle, design: .serif)
        return AttributedString("Lex") + call + i
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.rowSpacing) {
            Text(wordmark)
                .font(.system(configuration.wordmarkStyle))
                .padding(.horizontal, configuration.padding)
                .padding(.bottom, configuration.padding)
                .accessibilityAddTraits(.isHeader)

            // Groups the rows' glass icons so they sample the panel consistently.
            GlassEffectContainer(spacing: configuration.rowSpacing) {
                VStack(spacing: configuration.rowSpacing) {
                    ForEach(AppSection.allCases) { section in
                        SideMenuRow(section: section, isSelected: section == selection, configuration: configuration) {
                            selection = section
                            isOpen = false
                        }
                    }
                }
            }
        }
        .padding(configuration.padding)
        // At accessibility text sizes the panel grows toward the trailing edge, so titles don't break mid-word.
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : configuration.width)
        .frame(maxHeight: .infinity, alignment: .top)
        // Rows use concentric corners, so they follow this radius minus their inset.
        .containerShape(.rect(cornerRadius: configuration.cornerRadius))
        .background {
            // The glass extends under the status bar and home indicator so its corners can follow the screen's;
            // they are concentric with the screen corners there and `cornerRadius` elsewhere.
            Color.clear
                .glassEffect(
                    .regular,
                    in: ConcentricRectangle(corners: .concentric(minimum: .fixed(configuration.cornerRadius)))
                )
                .padding(.vertical, configuration.edgeInset)
                .ignoresSafeArea(edges: .vertical)
        }
        .padding(.leading, configuration.edgeInset)
        .padding(.trailing, dynamicTypeSize.isAccessibilitySize ? configuration.accessibilityTrailingInset : 0)
        .gesture(
            DragGesture(minimumDistance: configuration.swipeMinimumDistance).onEnded { value in
                if value.translation.width < -configuration.swipeToCloseDistance { isOpen = false }
            }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { isOpen = false }
    }
}

private struct SideMenuRow: View {
    let section: AppSection
    let isSelected: Bool
    let configuration: SideMenuConfiguration
    let action: () -> Void

    /// Dynamic Type factor, so the icon circle keeps fitting its symbol.
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    /// Capped, so at accessibility sizes the circle leaves room for the title.
    private var scale: Double { min(textScale, configuration.iconMaxScale) }

    private var shape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(configuration.rowMinimumCornerRadius)), isUniform: true)
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(section.title)
            } icon: {
                // Matches the round glass toolbar button that opens the menu.
                Image(systemName: section.systemImage)
                    .frame(width: configuration.iconSize * scale, height: configuration.iconSize * scale)
                    .glassEffect(.regular, in: .circle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(configuration.rowInsets)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .background {
            if isSelected { shape.fill(.tint.quaternary) }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = AppSection.decks
    @Previewable @State var isOpen = true
    SideMenu(selection: $selection, isOpen: $isOpen)
}
