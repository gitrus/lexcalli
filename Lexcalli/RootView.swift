import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Decks Yet",
                systemImage: "rectangle.stack",
                description: Text("Imported decks will appear here.")
            )
            .navigationTitle("Lexcalli")
        }
    }
}

#Preview {
    RootView()
}
