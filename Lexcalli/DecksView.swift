import SwiftUI

struct DecksView: View {
    var body: some View {
        ContentUnavailableView(
            "No Decks Yet",
            systemImage: "rectangle.stack",
            description: Text("Imported decks will appear here.")
        )
        .navigationTitle("Decks")
    }
}

#Preview {
    NavigationStack {
        DecksView()
    }
}
