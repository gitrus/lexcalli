import SwiftUI

struct SettingsView: View {
    var body: some View {
        ContentUnavailableView("No Settings Yet", systemImage: "gearshape")
            .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
