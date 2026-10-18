import SwiftUI

/// Leading-edge navigation panel shown over the main screen.
struct SideMenu: View {
    @Binding var selection: AppSection
    @Binding var isOpen: Bool

    /// Concentric with the screen corners where the panel sits next to them; 28pt elsewhere.
    private let panelShape = ConcentricRectangle(corners: .concentric(minimum: .fixed(28)))

    /// "Lex" regular, "call" bold, "i" in the system serif. A brand name, so it is not localized.
    private static let wordmark: AttributedString = {
        var call = AttributedString("call")
        call.inlinePresentationIntent = .stronglyEmphasized
        var i = AttributedString("i")
        i.font = .system(.title, design: .serif)
        return AttributedString("Lex") + call + i
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.wordmark)
                .font(.title)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            // Groups the rows' glass icons so they sample the panel consistently.
            GlassEffectContainer(spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(AppSection.allCases) { section in
                        SideMenuRow(section: section, isSelected: section == selection) {
                            selection = section
                            isOpen = false
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
        // Rows use concentric corners, so they follow this radius minus their inset.
        .containerShape(.rect(cornerRadius: 28))
        .background {
            // The glass extends under the status bar and home indicator so its corners can follow the screen's.
            Color.clear
                .glassEffect(.regular, in: panelShape)
                .padding(.vertical, 8)
                .ignoresSafeArea(edges: .vertical)
        }
        .padding(.leading, 8)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.width < -60 { isOpen = false }
            }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { isOpen = false }
    }
}

private struct SideMenuRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    /// Grows with Dynamic Type so the circle keeps fitting its symbol.
    @ScaledMetric(relativeTo: .body) private var iconSize = 40.0

    private let shape = ConcentricRectangle(corners: .concentric(minimum: .fixed(12)), isUniform: true)

    var body: some View {
        Button(action: action) {
            Label {
                Text(section.title)
            } icon: {
                // Matches the round glass toolbar button that opens the menu.
                Image(systemName: section.systemImage)
                    .frame(width: iconSize, height: iconSize)
                    .glassEffect(.regular, in: .circle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
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
