import LexcalliCore
import SwiftUI

struct PracticeSessionView: View {
    let deckID: Deck.ID

    @Environment(\.library) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.practice) private var configuration
    @State private var model: PracticeModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        // Outside the card, so failures stay visible after the last card.
        .safeAreaInset(edge: .bottom) {
            if let model { PracticeStatus(model: model) }
        }
        .navigationTitle(model?.deckName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Leaving goes through Finish.
        .navigationBarBackButtonHidden(model?.phase == .studying || model?.phase == .finishing)
        .toolbar {
            if let model, model.phase == .studying || model.phase == .finishing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { Task { await model.finish() } }
                        .disabled(model.isSaving || model.phase == .finishing)
                }
            }
        }
        .task {
            if model == nil { model = PracticeModel(library: library, deckID: deckID) }
            await model?.open()
        }
    }

    @ViewBuilder
    private func content(_ model: PracticeModel) -> some View {
        switch model.phase {
        case .opening:
            ProgressView()
        case .openFailed(let message):
            ContentUnavailableView {
                Label("Couldn't Start Practice", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.open() } }
            }
        case .studying, .finishing:
            if let card = model.current {
                VStack(spacing: configuration.controlSpacing) {
                    Text("\(model.progress.answered + 1) of \(model.progress.total)")
                        .font(configuration.progressFont)
                        .foregroundStyle(.secondary)
                    // A new identity per card resets its reveal state.
                    PracticeCardView(card: card, model: model)
                        .id(card.id)
                }
                .padding()
            } else {
                ContentUnavailableView {
                    Label(
                        model.progress.total == 0 ? "Nothing Due" : "All Cards Answered",
                        systemImage: "checkmark.circle")
                } description: {
                    Text(
                        model.progress.total == 0
                            ? "No cards in this deck are due now." : "Finish to schedule your next reviews.")
                } actions: {
                    Button("Finish") { Task { await model.finish() } }
                        .buttonStyle(.glassProminent)
                        .disabled(model.isSaving || model.phase == .finishing)
                }
            }
        case .finished(let reviewed):
            ContentUnavailableView {
                Label("Session Complete", systemImage: "checkmark.seal")
            } description: {
                Text("^[\(reviewed) card](inflect: true) reviewed.")
            } actions: {
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

private struct PracticeStatus: View {
    let model: PracticeModel

    @Environment(\.practice) private var configuration

    var body: some View {
        VStack(spacing: configuration.controlSpacing) {
            if let failure = model.failure {
                Text(failure)
                Button("Try Again") { Task { await model.retry() } }
                    .disabled(model.isSaving)
            } else if !model.needsRepair.isEmpty {
                Text("^[\(model.needsRepair.count) card](inflect: true) couldn't be scheduled from its history.")
                Button("Recalculate") { Task { await model.recalculate() } }
                    .disabled(model.isSaving)
            }
        }
        .font(configuration.failureFont)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
}

private struct PracticeCardView: View {
    let card: PracticeModel.CurrentCard
    let model: PracticeModel

    @State private var isFlipped = false
    @State private var isRevealed = false
    @Environment(\.library) private var library
    @Environment(\.practice) private var configuration
    @AppStorage(PreferenceKey.cardSerifText) private var serifText = false
    @AppStorage(PreferenceKey.cardShowsTranscription) private var showsTranscription = true

    var body: some View {
        let sides = card.note.sides(
            card.id.direction, termLanguage: card.termLanguage, meaningLanguage: card.meaningLanguage,
            media: library.media, showsTranscription: showsTranscription)
        VStack(spacing: configuration.controlSpacing) {
            // Not rendered until revealed, so VoiceOver can't read it early.
            FlashCard(front: sides.front, back: isRevealed ? sides.back : CardSide(text: ""), isFlipped: $isFlipped)
                .fontDesign(serifText ? .serif : nil)

            if isRevealed {
                ratings
            } else {
                Button {
                    isRevealed = true
                    isFlipped = true
                } label: {
                    Text("Show Answer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .onChange(of: isFlipped) { _, isFlipped in
            guard isFlipped else { return }
            isRevealed = true
        }
        .onChange(of: isRevealed) {
            AccessibilityNotification.Announcement(sides.back.text).post()
        }
    }

    /// One row, or two when titles don't fit on one line; titles never wrap.
    private var ratings: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: configuration.controlSpacing) {
                ForEach(Rating.allCases, id: \.self, content: ratingButton)
            }
            Grid(horizontalSpacing: configuration.controlSpacing, verticalSpacing: configuration.controlSpacing) {
                GridRow {
                    ratingButton(.again)
                    ratingButton(.hard)
                }
                GridRow {
                    ratingButton(.good)
                    ratingButton(.easy)
                }
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        // A pending answer is resent through Try Again, never replaced.
        .disabled(model.isSaving || model.failure != nil || model.phase != .studying)
    }

    private func ratingButton(_ rating: Rating) -> some View {
        Button {
            Task { await model.answer(rating) }
        } label: {
            Text(rating.title)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity)
        }
        .accessibilityHint(rating.hint)
    }
}

extension Rating {
    var title: LocalizedStringKey {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    var hint: LocalizedStringKey {
        switch self {
        case .again: "You didn't remember it"
        case .hard: "You remembered it with difficulty"
        case .good: "You remembered it"
        case .easy: "You remembered it easily"
        }
    }
}

#Preview {
    NavigationStack {
        PracticeSessionView(deckID: SampleLibrary.previewDecks[0].id)
    }
    .environment(\.library, SampleLibrary.preview)
}
