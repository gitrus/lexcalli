import SwiftUI

/// Loading and failure stay distinct from an empty value, so a failure never looks like an empty library.
enum Observed<Value: Equatable>: Equatable {
    case loading
    case value(Value)
    case failed(String)

    var value: Value? {
        if case .value(let value) = self { value } else { nil }
    }
}

extension View {
    /// Cancelled when the view disappears or `id` changes.
    func observe<Value: Equatable & Sendable, ID: Equatable>(
        _ values: @escaping () -> AsyncThrowingStream<Value, any Error>,
        id: ID,
        into state: Binding<Observed<Value>>
    ) -> some View {
        task(id: id) {
            state.wrappedValue = .loading
            do {
                for try await value in values() {
                    state.wrappedValue = .value(value)
                }
            } catch {
                guard !Task.isCancelled else { return }
                state.wrappedValue = .failed(error.localizedDescription)
            }
        }
    }
}

struct LoadFailureView: View {
    let title: LocalizedStringKey
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}
