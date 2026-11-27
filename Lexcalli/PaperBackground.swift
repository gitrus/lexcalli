import SwiftUI

extension View {
    /// Swaps a list's gray grouped background for the warm one its paper rows sit on.
    func paperGroupedBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.paperGroupedBackground)
    }
}
