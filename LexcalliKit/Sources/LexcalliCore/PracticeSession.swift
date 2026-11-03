import Foundation

/// Stored session modes; do not renumber.
public enum PracticeMode: Int, Codable, Hashable, Sendable {
    case flashcards = 0
    case mixed = 1
}

/// A practice period on a deck. One left open by a terminated app is ended before the next opens.
public struct PracticeSession: Identifiable, Hashable, Sendable {
    public enum Status: Int, Hashable, Sendable {
        case open = 0
        case ended = 1
    }

    public let id: UUID
    public let deckID: Deck.ID
    public let mode: PracticeMode
    public let openedAt: Date
    public var endedAt: Date?

    public var status: Status { endedAt == nil ? .open : .ended }

    public init(
        id: UUID = UUID(), deckID: Deck.ID, mode: PracticeMode = .flashcards, openedAt: Date, endedAt: Date? = nil
    ) {
        self.id = id
        self.deckID = deckID
        self.mode = mode
        self.openedAt = Date(milliseconds: openedAt.milliseconds)
        self.endedAt = endedAt.map { Date(milliseconds: $0.milliseconds) }
    }
}

public struct QueueCandidate: Hashable, Sendable {
    public let cardID: Card.ID
    public let due: Date

    public init(cardID: Card.ID, due: Date) {
        self.cardID = cardID
        self.due = due
    }
}

/// Built once per session; answers don't reorder it. No Again re-insertion, new-card limit, or undo yet.
public enum StudyQueue {
    /// Due cards, earliest first, one per note; the sibling waits for a later session.
    public static func build(from candidates: [QueueCandidate], now: Date) -> [Card.ID] {
        var notes = Set<Note.ID>()
        return
            candidates
            .filter { $0.due <= now }
            .sorted { ($0.due, $0.cardID) < ($1.due, $1.cardID) }
            .filter { notes.insert($0.cardID.noteID).inserted }
            .map(\.cardID)
    }
}
