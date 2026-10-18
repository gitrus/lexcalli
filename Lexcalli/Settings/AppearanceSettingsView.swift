import SwiftUI

/// Light or dark mode for the app, independent of the system setting.
struct AppearanceSettingsView: View {
    @AppStorage(PreferenceKey.appearance) private var appearance = Appearance.system

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
