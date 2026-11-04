import LexcalliCore
import SwiftUI

struct PracticeSessionView: View {
    let deckID: Deck.ID
    /// Shown until the deck loads.
    let name: String
    let mode: PracticeMode

    init(deckID: Deck.ID, name: String, mode: PracticeMode = .flashcards) {
        self.deckID = deckID
        self.name = name
        self.mode = mode
    }

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
        .navigationTitle(model?.deckName ?? name)
        .navigationBarTitleDisplayMode(.inline)
        // Leaving goes through Finish, which stays in the bar from the first frame.
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Leaves at once, unless the summary has repairs to offer; it's otherwise for sessions that run
                // out of cards.
                Button("Finish", systemImage: "xmark") {
                    Task {
                        if let model, model.phase == .studying {
                            await model.finish()
                            guard case .finished = model.phase, model.needsRepair.isEmpty, model.failure == nil
                            else { return }
                        }
                        dismiss()
                    }
                }
                .disabled(model?.isSaving == true || model?.phase == .finishing)
            }
        }
        .task {
            if model == nil {
                #if DEBUG
                    let engine = ExerciseUITestFixture.current?.engine
                #else
                    let engine: ExerciseEngine? = nil
                #endif
                model = PracticeModel(
                    library: library, deckID: deckID, deckName: name, mode: mode, exerciseEngine: engine)
            }
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
                    Text("\(model.currentPosition) of \(model.progress.total)")
                        .font(configuration.progressFont)
                        .foregroundStyle(.secondary)
                    // Input/reveal state belongs to this frozen prompt, never a redraw.
                    switch model.currentPrompt {
                    case .flashcard:
                        PracticeCardView(card: card, model: model).id(card.id)
                    case .writing(let prompt):
                        WritingExerciseView(prompt: prompt, model: model).id(prompt.cardID)
                    case .pickOne(let prompt):
                        PickOneExerciseView(prompt: prompt, model: model).id(prompt.cardID)
                    case nil:
                        ProgressView()
                    }
                }
                .padding()
            } else if model.phase == .finishing {
                ProgressView()
            } else {
                // Only after ending failed; the status bar offers Try Again.
                ContentUnavailableView(
                    "All Cards Answered", systemImage: "checkmark.circle",
                    description: Text("Your answers are saved."))
            }
        case .finished(let reviewed):
            ContentUnavailableView {
                if model.progress.total == 0 {
                    Label("Nothing Due", systemImage: "checkmark.circle")
                } else {
                    Label("Session Complete", systemImage: "checkmark.seal")
                }
            } description: {
                if model.progress.total == 0 {
                    Text("No cards in this deck are due now.")
                } else if mode == .mixed {
                    VStack {
                        Text("Exercises completed: \(model.exercisesCompleted)")
                        Text("Flashcards reviewed: \(reviewed)")
                        Text("Writing and Pick-one do not change scheduling yet. Some notes may still be due.")
                    }
                } else {
                    Text("^[\(reviewed) card](inflect: true) reviewed.")
                }
            } actions: {
                Button {
                    dismiss()
                } label: {
                    Text("Done").frame(minWidth: configuration.doneMinWidth)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
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
    @AppStorage(PreferenceKey.cardSpeaksMissingAudio) private var speaksMissingAudio = true

    var body: some View {
        let sides = card.note.sides(
            card.id.direction, termLanguage: card.termLanguage, meaningLanguage: card.meaningLanguage,
            media: library.media, showsTranscription: showsTranscription, speaksMissingAudio: speaksMissingAudio)
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
                .foregroundStyle(rating.accentShare > 0.5 ? Color.white : Color.accentColor)
        }
        // From white for Again to the accent for Easy.
        .buttonStyle(.glass(.regular.tint(Color.white.mix(with: .accentColor, by: rating.accentShare))))
        .accessibilityHint(rating.hint)
    }
}

extension Rating {
    /// 0 for Again through 1 for Easy.
    var accentShare: Double {
        Double(rawValue - Rating.again.rawValue) / Double(Rating.easy.rawValue - Rating.again.rawValue)
    }

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
        PracticeSessionView(deckID: SampleLibrary.previewDecks[0].id, name: SampleLibrary.previewDecks[0].name)
    }
    .environment(\.library, SampleLibrary.preview)
}
