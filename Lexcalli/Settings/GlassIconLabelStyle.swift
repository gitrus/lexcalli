import SwiftUI

/// Draws a label's icon in a glass circle, like the side menu rows, for example on the rows of a settings list.
struct GlassIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            GlassIcon { configuration.icon }
        }
    }
}

extension LabelStyle where Self == GlassIconLabelStyle {
    static var glassIcon: Self { .init() }
}

private struct GlassIcon<Icon: View>: View {
    @ViewBuilder let icon: Icon

    @Environment(\.settingsList) private var configuration
    /// Dynamic Type factor, so the circle keeps fitting its symbol.
    @ScaledMetric(relativeTo: .body) private var scale = 1.0

    var body: some View {
        icon
            .imageScale(configuration.iconScale)
            .frame(width: configuration.iconSize * scale, height: configuration.iconSize * scale)
            .glassEffect(.regular, in: .circle)
            // Lists tint label icons with the accent color; plain glass with a primary symbol matches the side menu.
            .foregroundStyle(.primary)
    }
}
