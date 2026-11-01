import Foundation

/// Raw values are stored; don't renumber.
public enum CardDirection: Int, CaseIterable, Hashable, Sendable, Codable {
    /// Term → meaning.
    case forward = 0
    /// Meaning → term.
    case reverse = 1
}

/// A note studied in one direction; scheduling and history belong to cards.
public struct Card: Identifiable, Hashable, Sendable {
    public struct ID: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
        public let noteID: Note.ID
        public let direction: CardDirection

        public init(noteID: Note.ID, direction: CardDirection) {
            self.noteID = noteID
            self.direction = direction
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.noteID != rhs.noteID { return lhs.noteID.uuidString < rhs.noteID.uuidString }
            return lhs.direction.rawValue < rhs.direction.rawValue
        }

        public var description: String { "\(noteID.uuidString)/\(direction)" }
    }

    public let id: ID

    public var noteID: Note.ID { id.noteID }
    public var direction: CardDirection { id.direction }

    public init(noteID: Note.ID, direction: CardDirection) {
        id = ID(noteID: noteID, direction: direction)
    }
}

extension Note {
    public var cards: [Card] {
        CardDirection.allCases.map { Card(noteID: id, direction: $0) }
    }
}
