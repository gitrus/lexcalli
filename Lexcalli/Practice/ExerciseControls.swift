import SwiftUI

/// Only successful acknowledgement replaces confirmation with Continue.
struct ExerciseControls: View {
    let model: PracticeModel
    let canConfirm: Bool
    let confirm: () -> Void
    @Environment(\.practice) private var configuration

    var body: some View {
        Button {
            if model.feedback != nil {
                Task { await model.continueAfterFeedback() }
            } else {
                confirm()
            }
        } label: {
            Text(model.feedback != nil ? "Continue" : model.isSaving ? "Saving…" : "Check Answer")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(configuration.exerciseControlSize)
        .disabled(
            model.isSaving || model.failure != nil || model.phase != .studying
                || (model.feedback == nil && (!canConfirm || model.hasPendingAnswer)))
    }
}
