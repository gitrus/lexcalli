import SwiftUI

struct PracticeView: View {
    var body: some View {
        ContentUnavailableView(
            "Nothing to Practice",
            systemImage: "brain.head.profile",
            description: Text("Cards due for review will appear here.")
        )
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack {
        PracticeView()
    }
}
