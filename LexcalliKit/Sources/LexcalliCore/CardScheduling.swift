import Foundation

/// FSRS memory state and due date, projected from the baseline and review events.
public struct CardScheduling: Hashable, Sendable {
    public var state: CardState
    public var due: Date
    public var stability: Double
    public var difficulty: Double
    public var elapsedDays: Double
    public var scheduledDays: Double
    /// Index into the learning or relearning steps.
    public var learningSteps: Int
    public var reps: Int
    public var lapses: Int
    public var lastReview: Date?

    public init(
        state: CardState,
        due: Date,
        stability: Double = 0,
        difficulty: Double = 0,
        elapsedDays: Double = 0,
        scheduledDays: Double = 0,
        learningSteps: Int = 0,
        reps: Int = 0,
        lapses: Int = 0,
        lastReview: Date? = nil
    ) {
        self.state = state
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.learningSteps = learningSteps
        self.reps = reps
        self.lapses = lapses
        self.lastReview = lastReview
    }

    public static func new(due: Date) -> Self {
        CardScheduling(state: .new, due: due)
    }
}

/// The last applied (or baseline-covered) event and how many events precede it; a count mismatch reveals
/// an event that arrived out of order.
public struct ProjectionCheckpoint: Hashable, Sendable {
    public let position: ReviewPosition
    public let eventCount: Int

    public init(position: ReviewPosition, eventCount: Int) {
        self.position = position
        self.eventCount = eventCount
    }
}

/// A new card, or Anki's imported state with the imported events it already reflects.
public struct SchedulingBaseline: Hashable, Sendable {
    public let scheduling: CardScheduling
    /// `nil` when it covers no events.
    public let checkpoint: ProjectionCheckpoint?

    public init(scheduling: CardScheduling, checkpoint: ProjectionCheckpoint? = nil) {
        self.scheduling = scheduling
        self.checkpoint = checkpoint
    }

    public static func new(due: Date) -> Self {
        SchedulingBaseline(scheduling: .new(due: due))
    }
}

public struct CardProjection: Hashable, Sendable {
    public let cardID: Card.ID
    public let baseline: SchedulingBaseline
    public let scheduling: CardScheduling
    public let checkpoint: ProjectionCheckpoint?

    public init(
        cardID: Card.ID,
        baseline: SchedulingBaseline,
        scheduling: CardScheduling,
        checkpoint: ProjectionCheckpoint?
    ) {
        self.cardID = cardID
        self.baseline = baseline
        self.scheduling = scheduling
        self.checkpoint = checkpoint
    }

    public init(cardID: Card.ID, baseline: SchedulingBaseline) {
        self.init(cardID: cardID, baseline: baseline, scheduling: baseline.scheduling, checkpoint: baseline.checkpoint)
    }
}
